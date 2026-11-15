"""Synthetic runtime regressions; no game, captures, DLLs or hooks required.

Run with a Python environment containing lupa (LuaJIT 2.1).
Executable contracts are separate in test_native_contracts.py.
"""
from pathlib import Path
import re
import struct
import unittest
import zlib

try:
    from lupa.luajit21 import LuaRuntime
except ImportError:
    LuaRuntime = None


def run_scenario():
    src=(Path(__file__).resolve().parents[1] / 'modules/FlAccessOpeningTrace.lua').read_bytes()
    base,world,rep,roster,window,impl=0x140000000,0x100000,0x110000,0x200000,0x300000,0x310000
    mem={}
    def p(fmt,*v): return struct.pack('<'+fmt,*v)
    def q(v): return p('Q',v)
    def unpack(fmt, buf, at):
        if buf and 0 <= at <= len(buf)-struct.calcsize('<'+fmt): return struct.unpack_from('<'+fmt,buf,at)[0]
    def read(addr, n):
        for start,data in mem.items():
            if start<=addr and addr+n<=start+len(data):return data[addr-start:addr-start+n]
    # Synthetic executable bytes permit initialization only. The independent
    # NativeContracts test checks these signatures against FLACCESS_TEST_EXE.
    for rva, literal in re.findall(rb'\{(0x[0-9a-f]+), "((?:\\x[0-9a-f]{2})+)"\}',src):
        mem[base+int(rva,16)] = bytes.fromhex(literal.replace(b'\\x', b'').decode())
    mem[base+0x36f3dc8]=q(world)
    mem[world+0x388]=q(rep)
    home_items,away_items=0x320000,0x330000
    rgb=[p('IfffI',i,*colors,0) for i,colors in enumerate(((0.6,0.1,0.1),(.99,.99,.99),(.6,.6,.6)))]
    mem[home_items]=b''.join(rgb)
    mem[away_items]=b''.join(rgb)
    for side,(team,name) in enumerate(((103,b'Liverpool FC'),(101,b'Arsenal FC'))):
        mem[roster+0x35960+0x138+side*0x690]=(p('I',team*0x4000)+name).ljust(0x4a,b'\0')
        table=bytearray(40*0x188)
        struct.pack_into('<I',table,0x30,9000+side)
        label=b'Alisson Becker' if side==0 else b'David Raya'
        table[0x38:0x38+len(label)]=label
        mem[roster+0x35960+0x1308+side*40*0x188]=bytes(table)
    def select(side,home,away,active=1):
        data=bytearray(0xd0)
        struct.pack_into('<Q',data,0,base+0x266c030)
        struct.pack_into('<QII',data,0x88,impl,0,0)
        struct.pack_into('<II',data,0x98,home,away)
        for i,ptr in enumerate((home_items,away_items)):
            struct.pack_into('<QQ',data,0xa0+i*0x18,ptr,ptr+60)
        mem[window]=bytes(data)
        state=bytearray(0xdc);state[9]=active
        struct.pack_into('<I',state,0xd8,side)
        mem[impl]=bytes(state)
        mem[roster+0x35960+0x120]=p('II',103*0x4000+home,101*0x4000+away)
    def focus_widget(side):
        state=bytearray(mem[impl])
        struct.pack_into('<QIQQ',state,0x98,0x400000,6,0,0) # replaced vector below
        struct.pack_into('<QQ',state,0xa8,0x410000,0x410018)
        mem[impl]=bytes(state)
        mem[0x410000]=p('I',6).ljust(24,b'\0')
        mem[0x400170]=p('QQ',0x420000,0x420008)
        mem[0x420000]=q(0x430000)
        mem[0x430110]=q(0x440000)
        mem[0x440000]=q(0x450000)
        links=bytearray(0x48)
        struct.pack_into('<QQQ',links,0,0x440000,0x440000,0x440000)
        struct.pack_into('<Q',links,0x40,0x460000)
        mem[0x450000]=bytes(links)
        data=bytearray(0xc0)
        struct.pack_into('<I',data,0x88,16)
        struct.pack_into('<I',data,0xbc,side)
        mem[0x460000]=bytes(data)
    def replay(kind,frame,speed,shown=1,actor=0,clip=0,last=300,requests=0):
        b=bytearray(0x28);b[0]=kind;b[7]=shown;b[0xc]=clip;b[4]=requests;b[5]=requests
        struct.pack_into('<fIII',b,0x10,speed,frame,last,actor)
        struct.pack_into('<I',b,0x24,9000+int(actor>11) if actor else 0)
        mem[rep]=bytes(b)
    def geometry(frame,x,y,z,visible=True):
        owner,controller,recording,first=0x700000,0x710000,0x720000,0x800000
        mem[base+0x36f0260]=q(owner)
        mem[owner]=q(base+0x2bba650)
        mem[owner+0x138]=q(controller)
        state=bytearray(0x438)
        struct.pack_into('<Q',state,0,base+0x2bd3e50)
        struct.pack_into('<HHHH',state,0x288,frame,660,0,0)
        struct.pack_into('<Q',state,0x430,rep)
        mem[controller]=bytes(state)
        mem[base+0x36f5114]=p('I',0)
        mem[world+0x6a8]=q(recording)
        mem[recording+0x40]=q(first)
        mem[first+frame*0x1fb0+0x24c]=p('hhh',round(x*256),round(y*256),round(z*256))
        camera=bytearray(0x5c)
        struct.pack_into('<f',camera,0xc,0.01)
        struct.pack_into('<f',camera,0xc+20,0.01)
        struct.pack_into('<f',camera,0xc+60,1)
        if not visible: struct.pack_into('<f',camera,0xc+48,2)
        mem[0x900000]=bytes(camera)
        mem[0x910000]=p('fff',0,52.5,34)

    def asset(name, altered):
        data=texture_fixture
        if altered: data=data[:-1]+bytes([data[-1]^1])
        mem[0x600000]=data
        return len(data)
    lua=LuaRuntime(encoding=None)
    m=lua.execute(src)
    # A generated multi-chunk texture tests recognition and invalidation without
    # distributing game assets. Only this test instance receives its hash.
    texture_fixture=b'\0'*(0x20000+17)+b'synthetic shirt'
    m.uniform_textures[b'u0103p1'][1]=len(texture_fixture)
    m.uniform_textures[b'u0103p1'][2]=zlib.adler32(texture_fixture)
    lua.execute(br"""
    function test(m, read, ptr, uint, float, select_kit, focus_widget, replay, asset, geometry, base, window, impl)
        ffi = require("ffi")
        local lines, said, stops, now, busy, paused, callbacks = {}, {}, 0, 0, false, false, {}
        log=function(text) lines[#lines+1]=text end
        local a = {ui_language="pt", prism_backend=1,native_speech_first=1,native_speech_last=0,
          native_pause_context=function() return paused or nil end,
          prism_proc=function() return function(_,out) out[0]=busy; return 0 end end,
          to_c_string=function(v) return v end}
        a.prism_functions = {backend_features=function() return 0xf5 end,
          backend_speak=function(_,v,interrupt) assert(not busy and interrupt==false); said[#said+1]=v; busy=true; return 0 end,
          backend_stop=function() stops=stops+1; busy=false; return 0 end}
        local reader={a11y=a, speech_sequence=1, game_is_foreground=function() return true end}
        local gp={base=base,ptr=ptr,uint=uint,float=float,match_names_supported=true,match_roster_data=function() return 0x200000 end,
          kernel={GetTickCount64=function() return now end}}
        gp.blob=function(at,n) gp.read_failure="instrumented"; return read(at,n) end
        local ctx={home_team=103,away_team=101,flaccess={reader=reader,gameplay=gp},register=function(k,v) callbacks[k]=v end}
        ctx.kits={get=function(team,id)
            assert(team==103 or team==101)
            if team==103 and id==0 then
                return {KitFile="u0103p1",ShirtColor1="#b52c3c",ShirtColor2="#b52c3c",ShortsColor="#b52c3c",SocksColor="#b52c3c"}
            end
            if team==101 and id==2 then
                return {KitFile="u0101p3",ShirtColor1="#c5ab70",ShirtColor2="#192948",ShortsColor="#192948",SocksColor="#192948"}
            end
            return {KitFile="other",ShirtColor1="#f2f2f2",ShirtColor2="#173eab",ShortsColor="#161616",SocksColor="#f2f2f2",
              ChestNumbersFile="valid_chest",ChestNumberSize=7}
        end}
        m.init(ctx)
        assert(m.uniform_supported and m.replay_supported and m.formation_supported and m.actors_supported)
        for name,fn in pairs(callbacks) do assert(debug.getupvalue(fn,1)==nil,name) end
        local function step(dt)
            now=now+(dt or 16); gp.read_failure="saved"
            callbacks.display_frame(ctx)
            assert(gp.read_failure=="saved",gp.read_failure)
        end
        local path="Asset\\model\\character\\uniform\\texture\\#windx11\\u0103p1.ftex"
        local size=asset("u0103p1",false)
        callbacks.livecpk_data_ready(ctx,path,0x600000,size,size,0)
        assert(m.verified_textures.u0103p1)
        a.native_windows={windows={{enabled=true,vtable=base+0x266c030,address=window,impl=impl}}}
        select_kit(0,0,2)
        step(); step()
        assert(#said==1 and said[1]:find("Liverpool FC. Uniforme 1.",1,true) and said[1]:find("Listras brancas nos ombros.",1,true),said[1])
        step()
        select_kit(0,1,2)
        step(); step()
        assert(stops==1 and #said==2 and said[2]:find("Uniforme 2.",1,true) and said[2]:find("no peito",1,true))
        focus_widget(1)
        step(); step()
        assert(stops==2 and #said==3 and said[3]:find("Arsenal FC. Uniforme 3.",1,true) and not said[3]:find("Listras",1,true))
        a.native_windows.windows={}
        step(); assert(stops==3)
        size=asset("u0103p1",true)
        callbacks.livecpk_data_ready(ctx,path,0x600000,size,size,0)
        assert(not m.verified_textures.u0103p1)
        a.native_windows.windows={{enabled=true,vtable=base+0x266c030,address=window,impl=impl}}
        select_kit(0,0,2)
        step(); step()
        assert(#said==4 and not said[4]:find("Listras",1,true))
        a.native_windows.windows={}
        step()
        assert(m.replays_enabled==false,"release keeps replay research disabled")
        a.ad_replays=true -- an obsolete preference cannot enable it
        replay(1,10,1);step();replay(1,12,1);step()
        assert(#said==4 and not m.replay,"automatic replays must stay silent in the release")
        m.replays_enabled=true -- exercise preserved research only inside this test
        replay(2,20,1)
        step(); replay(2,22,1); step()
        assert(#said==4 and stops==4,"manual replay stays quiet")
        replay(1,20,0.5)
        step(); step()
        assert(#said==4,"stationary start stays quiet")
        replay(1,22,0.5)
        step(); assert(said[5]=="Replay em c\195\162mera lenta.",said[5])
        step()
        replay(1,22,0)
        step(); assert(stops==5 and #said==5,"zero speed stops in same callback")
        replay(1,23,.5)
        step(); assert(#said==6)
        step(181); assert(stops==6 and #said==6,"stalled clock stops the voice")
        replay(1,24,.5,1,12)
        step(); assert(said[7]=="Em destaque, David Raya.",said[7])
        paused=true
        step(); assert(stops==7)
        paused=false
        replay(1,25,.5,1,12)
        step(); assert(said[8]=="Em destaque, David Raya.")
        replay(1,0,.5,0,0)
        step(); assert(stops==8 and not m.replay,"skip closes and stops")
        replay(1,298,1,1,0)
        step(); replay(1,299,1,1,0); step()
        assert(#said==8,"too late for a fresh phrase")
        replay(0,0,0,0)
        step()
        callbacks.after_set_conditions(ctx)
        step(); assert(m.active and #said==8)
        ctx.flaccess.match_playing=true
        step(); assert(not m.active and lines[#lines]:find("kickoff",1,true))
        gp.camera_source_supported=true
        gp.reference_data=function(kind,n) return read(kind=="camera" and 0x900000 or 0x910000,n) end
        geometry(10,45,3,0); replay(1,10,.5); step()
        geometry(11,45,3,0); replay(1,11,.5); step()
        assert(#said==9 and said[9]:find("Bola pelo alto, na grande",1,true),said[9])
        local before_stop=stops
        replay(1,11,.5,1,0,0,300,1)
        step(); assert(stops==before_stop,"duplicate playback frame must not interrupt")
        m.replays_enabled=false
        step(); assert(stops==before_stop+1 and not m.replay,"replay switch stops immediately")
        geometry(12,45,3,0); replay(1,12,.5); step(); assert(#said==9)
        m.replays_enabled=true
        step(); geometry(13,45,3,0); replay(1,13,.5); step(); assert(#said==10)
        a.ad_enabled=false; step(); assert(not busy and #said==10)
        geometry(14,45,3,0); replay(1,14,.5); step(); assert(#said==10)
        a.ad_enabled=true; step()
        geometry(15,45,3,0); replay(1,15,.5); step(); assert(#said==11)
        local sample=m.replay
        assert(m.replay_ball(m,ctx,sample).position[1]==45)
        geometry(16,45,3,0)
        assert(not m.replay_ball(m,ctx,sample),"mismatched recorded frame must be rejected")
        geometry(15,120,3,0)
        assert(not m.replay_ball(m,ctx,sample),"off-pitch coordinates must be rejected")
        geometry(15,45,3,0)
        geometry(15,45,3,0,false)
        assert(not m.replay_ball(m,ctx,sample),"ball outside current view must not be described")
        geometry(15,45,3,0)
        gp.camera_source_supported=false
        assert(not m.replay_ball(m,ctx,sample),"unverified projection must stay quiet")
        replay(0,0,0,0);step()
        a.ad_enabled=false
        a.ad_uniforms=false -- obsolete saved preference must have no effect
        a.native_windows.windows={{enabled=true,vtable=base+0x266c030,address=window,impl=impl}}
        select_kit(0,0,2); step(); step()
        assert(#said==12 and said[12]:find("Uniforme 1.",1,true),"kit focus is always read even with cinematic AD off")
        a.native_windows.windows={};step()
        assert(not busy,"leaving kit selection stops its voice")
        a.ad_enabled=true
        a.ad_lineups=false
        m.lineups={{groups={{"stale"}},labels={"stale"},sector=1}}
        step(); assert(#m.lineups==0)
        m.reset(ctx)
        a.native_windows.windows={}
        m.replays_enabled=false; a.ad_opening=false; a.ad_lineups=true
        ctx.flaccess.match_playing=false
        m.active=true
        local frame=0
        m.read_cut=function() frame=frame+1;return {key="opening",index=1,role="stadium",frame=frame,limit=3000} end
        m.details=function() return {"Visible opening scene."} end
        m.visual_details=function() return nil end
        local count=#said
        step();step();assert(#said==count,"disabled opening must stay quiet")
        a.ad_opening=true;step();assert(#said==count+1 and said[#said]=="Visible opening scene.")
        a.ad_opening=false;step();assert(not busy,"opening switch must stop its current voice")
        m.lineups={{groups={{"Goalkeeper"}},labels={"Lineup"},sector=1,cut={index=1,role="formation",frame=1}}}
        step();assert(#said==count+2 and m.speech.lineup,"lineup switch is independent of opening")
        a.ad_lineups=false;step();assert(#m.lineups==0 and not busy,"lineup switch cancels its remaining sectors")
    end
    """)
    lua.globals().test(m,read,lambda d,o:unpack('Q',d,o),lambda d,o:unpack('I',d,o),
        lambda d,o:unpack('f',d,o),select,focus_widget,replay,asset,geometry,base,window,impl)

@unittest.skipIf(LuaRuntime is None, "lupa LuaJIT runtime unavailable")
class AudioDescriptionRuntime(unittest.TestCase):
    def test_scene_gates_uniforms_and_automatic_replay_lifecycle(self):
        run_scenario()


if __name__ == "__main__":
    unittest.main()
