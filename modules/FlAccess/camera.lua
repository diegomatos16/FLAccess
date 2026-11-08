-- Field-aligned listener math plus legacy screen projection for unmapped views.
-- CAMERA/INFO contains a view-projection matrix, not an orthonormal listener pose.
local defaults = {}
defaults[0] = [=[; Native ID 0; UI name not yet verified. Data only.
native_id=0
name=camera_00
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[1] = [=[; Native ID 1; UI name not yet verified. Data only.
native_id=1
name=camera_01
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[2] = [=[; Native ID 2; family verified against FL2026 native consumer. Data only.
native_id=2
name=fan_view
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[3] = [=[; Native ID 3; family verified against FL2026 native consumer. Data only.
native_id=3
name=broadcast
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[4] = [=[; Native ID 4; UI name not yet verified. Data only.
native_id=4
name=camera_04
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[5] = [=[; Native ID 5; family verified against FL2026 native consumer. Data only.
native_id=5
name=dynamic_wide
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[6] = [=[; Native ID 6; family verified against FL2026 native consumer. Data only.
native_id=6
name=stadium
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[7] = [=[; Native ID 7; UI name not yet verified. Data only.
native_id=7
name=camera_07
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[8] = [=[; Native ID 8; UI name not yet verified. Data only.
native_id=8
name=camera_08
pan_sign=1
depth_sign=1
depth_scale=1
]=]
defaults[9] = [=[; Native ID 9; UI name not yet verified. Data only.
native_id=9
name=camera_09
pan_sign=1
depth_sign=1
depth_scale=1
]=]
local m={version="0.2.0",profiles={}}
local sample=ffi.new("float[1]")
local function finite(x) return type(x)=="number" and x==x and x>-math.huge and x<math.huge end
local function vector(v)
    return type(v)=="table" and finite(v[1]) and finite(v[2]) and finite(v[3])
end
local function length(x,y,z) return math.sqrt(x*x+y*y+z*z) end
-- Profiles are data, never executable Lua: broken text affects only its ID.
function m.parse_profile(text,id)
    if type(text)~="string" or #text>4096 then return nil end
    -- Accept UTF-8 BOM from Windows editors without treating it as a key.
    if text:sub(1,3)=="\239\187\191" then text=text:sub(4) end
    local p={};local allowed={native_id=true,name=true,pan_sign=true,depth_sign=true,depth_scale=true}
    for line in text:gmatch("[^\r\n]+") do
        if not line:match("^%s*[;#]") and not line:match("^%s*$") then
            local key,value=line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
            if not key or not allowed[key] or p[key]~=nil then return nil end
            if key=="name" then p[key]=value else p[key]=tonumber(value);if not p[key] then return nil end end
        end
    end
    if p.native_id~=id then return nil end
    return p
end
function m.checked_profile(origin,id)
    if not vector(origin) then return nil,"camera-origin-invalid" end
    if not finite(id) or id%1~=0 then return nil,"camera-id-unavailable" end
    local profile=m.profiles[id]
    if type(profile)~="table" or profile.native_id~=id
        or (profile.pan_sign~=1 and profile.pan_sign~=-1)
        or (profile.depth_sign~=1 and profile.depth_sign~=-1)
        or not finite(profile.depth_scale) or profile.depth_scale<0.05 or profile.depth_scale>20 then
        return nil,"camera-profile-invalid-" .. tostring(id)
    end
    return profile
end
function m.frame(raw,origin,id)
    local profile,why=m.checked_profile(origin,id)
    if not profile then return nil,why end
    if type(raw)~="string" or #raw<0x4c then return nil,"camera-matrix-unavailable" end
    local matrix={}
    for i=0,15 do
        local offset=0x0c+i*4
        ffi.copy(sample,raw:sub(offset+1,offset+4),4)
        local value=tonumber(sample[0])
        if not finite(value) or math.abs(value)>1e12 then return nil,"camera-matrix-invalid" end
        matrix[i+1]=value
    end
    local x,y,z=origin[1],origin[2],origin[3]
    local cx=x*matrix[1]+y*matrix[5]+z*matrix[9]+matrix[13]
    local cy=x*matrix[2]+y*matrix[6]+z*matrix[10]+matrix[14]
    local cw=x*matrix[4]+y*matrix[8]+z*matrix[12]+matrix[16]
    if not finite(cw) or cw<=0.00001 then return nil,"camera-origin-behind-view" end
    local horizontal=length(matrix[1],matrix[5],matrix[9])
    local vertical=length(matrix[2],matrix[6],matrix[10])
    if horizontal<1e-8 or vertical<1e-8 then return nil,"camera-projection-degenerate" end
    -- Undo NDC aspect compression to compare directions in screen pixels.
    local aspect=vertical/horizontal
    if aspect<0.1 or aspect>10 then return nil,"camera-aspect-invalid" end
    local gx={(matrix[1]*cw-cx*matrix[4])*aspect,0,(matrix[9]*cw-cx*matrix[12])*aspect}
    local gy={matrix[2]*cw-cy*matrix[4],0,matrix[10]*cw-cy*matrix[12]}
    local nx,nz=length(gx[1],0,gx[3]),length(gy[1],0,gy[3])
    if nx<1e-8 or nz<1e-8 or math.abs(gx[1]*gy[3]-gx[3]*gy[1])<nx*nz*1e-6 then
        return nil,"camera-ground-projection-degenerate"
    end
    return {id=id,name=profile.name,profile_source=profile.source,origin={x,y,z},gx=gx,gy=gy,aspect=aspect,w=cw,
        pan_sign=profile.pan_sign,depth_sign=profile.depth_sign,depth_scale=profile.depth_scale,
        right={gx[1]/nx,0,gx[3]/nx},up={0,1,0},forward={gy[1]/nz,0,gy[3]/nz}}
end
-- Portable camera/body listener from CAMERA-AUDIO. FL uses XZ ground and
-- Y height; OpenAL remains X right, Y up, negative Z forward. Camera matrix
-- columns carry view-projection scale, so normalize the horizontal axes and
-- remove perspective/player-position distortion instead of projecting targets.
function m.listener_frame(raw,origin,id,body_forward)
    local frame,why
    if body_forward~=nil then
        local profile;profile,why=m.checked_profile(origin,id)
        if profile then
            frame={id=id,name=profile.name,profile_source=profile.source,
                origin={origin[1],origin[2],origin[3]},pan_sign=profile.pan_sign,
                depth_sign=profile.depth_sign,depth_scale=profile.depth_scale}
        end
    else frame,why=m.frame(raw,origin,id) end
    if not frame then return nil,why end
    local forward,right
    if body_forward~=nil then
        if not vector(body_forward) then return nil,"body-forward-invalid" end
        local n=length(body_forward[1],0,body_forward[3])
        if n<1e-8 then return nil,"body-forward-degenerate" end
        forward={body_forward[1]/n,0,body_forward[3]/n}
        right={forward[3],0,-forward[1]}
        frame.orientation="body"
    else
        local function cell(index)
            ffi.copy(sample,raw:sub(13+(index-1)*4,16+(index-1)*4),4)
            return tonumber(sample[0])
        end
        local rx,rz=cell(1),cell(9)
        local n=length(rx,0,rz)
        if n<1e-8 then return nil,"camera-horizontal-axis-unavailable" end
        right={rx/n,0,rz/n}
        forward={-right[3],0,right[1]}
        -- Clip W increases toward the actual view direction for perspective
        -- cameras. Orthographic views use screen-up's ground direction.
        local fx,fz=cell(4),cell(12)
        if length(fx,0,fz)<1e-8 then fx,fz=cell(2),cell(10) end
        local alignment=forward[1]*fx+forward[3]*fz
        if math.abs(alignment)<1e-8 then return nil,"camera-horizontal-forward-unavailable" end
        if alignment<0 then forward={-forward[1],0,-forward[3]} end
        frame.orientation="camera"
    end
    frame.right,frame.up,frame.forward=right,{0,1,0},forward
    frame.listener=true
    return frame
end
function m.field_frame(raw,origin,id,attack_sign)
    if id==7 or id==8 or id==9 then
        if attack_sign~=1 and attack_sign~=-1 then return nil,"camera-attack-direction-unavailable" end
        local frame,why=m.listener_frame(nil,origin,id,{attack_sign,0,0})
        if frame then frame.orientation="field-attack" end
        return frame,why
    end
    if id and id>=1 and id<=6 then
        local frame,why=m.listener_frame(raw,origin,id)
        if not frame then return nil,why end
        -- Screen axes tell us which side of the pitch this view faces.
        -- Snap to pitch axes so camera tracking cannot rotate the bearings.
        if math.abs(frame.right[1])<0.5 or math.abs(frame.forward[3])<0.5 then
            return nil,"camera-lateral-axis-unavailable"
        end
        frame.right={frame.right[1]>0 and 1 or -1,0,0}
        frame.forward={0,0,frame.forward[3]>0 and 1 or -1}
        frame.orientation="field-lateral"
        return frame
    end
    return m.frame(raw,origin,id)
end
function m.project(frame,target)
    if type(frame)~="table" or not vector(target) then return nil end
    local dx,dy,dz=target[1]-frame.origin[1],target[2]-frame.origin[2],target[3]-frame.origin[3]
    if frame.listener then
        return {(dx*frame.right[1]+dz*frame.right[3])*frame.pan_sign,dy,
            -(dx*frame.forward[1]+dz*frame.forward[3])*frame.depth_sign*frame.depth_scale}
    end
    local distance=math.sqrt(dx*dx+dz*dz)
    if distance<1e-7 then return {0,dy,dy==0 and -0.01 or 0} end
    -- Homogeneous difference is exact for screen direction when both points are
    -- visible, and stays continuous if a target crosses behind the camera.
    -- Ground position guides movement; actual height is kept as OpenAL elevation.
    local sx=(frame.gx[1]*dx+frame.gx[3]*dz)*frame.pan_sign
    local sy=(frame.gy[1]*dx+frame.gy[3]*dz)*frame.depth_sign*frame.depth_scale
    local n=math.sqrt(sx*sx+sy*sy)
    if not finite(n) or n<1e-10 then return nil end
    return {distance*sx/n,dy,-distance*sy/n}
end
-- Optional reader is injected in pure tests. Production only reads our own INIs.
function m.init(ctx,profiles,read_profile)
    profiles = profiles or defaults
    m.profiles={}
    if not read_profile and type(ctx.sider_dir)=="string" and io and type(io.open)=="function" then
        read_profile=function(id)
            local path=ctx.sider_dir .. "content\\FlAccess\\cameras\\camera_" .. string.format("%02d",id) .. ".ini"
            local f=io.open(path,"rb")
            if not f then return nil end
            local text=f:read(4097);f:close()
            return text or ""
        end
    end
    for id=0,9 do
        local text=type(profiles)=="table" and profiles[id] or nil
        local source="embedded"
        if read_profile then
            local installed=read_profile(id)
            if installed~=nil then text=installed;source="installed" end
        end
        local profile=m.parse_profile(text,id)
        if profile then profile.source=source end
        m.profiles[id]=profile
        if log then log("[FlAccessGameplay] camera profile id=" .. id .. " source=" .. source .. " parsed=" .. tostring(profile~=nil)) end
    end
    ctx.flaccess_camera_radars=m
end
return m
