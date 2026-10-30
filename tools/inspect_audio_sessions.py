"""Read-only Windows Core Audio endpoint/session levels. Never changes volume."""
import ctypes as C
import json
import uuid
from pathlib import Path

class GUID(C.Structure):
    _fields_=[('data',C.c_ubyte*16)]
    def __init__(self,text):
        super().__init__();C.memmove(C.byref(self),uuid.UUID(text).bytes_le,16)
class PROPERTYKEY(C.Structure):
    _fields_=[('fmtid',GUID),('pid',C.c_uint32)]

ole=C.OleDLL('ole32')
ole.CoInitializeEx.argtypes=[C.c_void_p,C.c_uint32]
ole.CoCreateInstance.argtypes=[C.POINTER(GUID),C.c_void_p,C.c_uint32,C.POINTER(GUID),C.POINTER(C.c_void_p)]
ole.CoTaskMemFree.argtypes=[C.c_void_p]
ole.PropVariantClear.argtypes=[C.c_void_p]
def call(obj,index,types,*args):
    table=C.cast(obj,C.POINTER(C.POINTER(C.c_void_p))).contents
    result=C.WINFUNCTYPE(C.c_long,C.c_void_p,*types)(table[index])(obj,*args)
    if result<0: raise OSError(f'CoreAudio HRESULT 0x{result & 0xffffffff:08x}, method {index}')
    return result
def release(obj):
    if obj:
        table=C.cast(obj,C.POINTER(C.POINTER(C.c_void_p))).contents
        C.WINFUNCTYPE(C.c_ulong,C.c_void_p)(table[2])(obj)
def query(obj,iid):
    result=C.c_void_p();key=GUID(iid)
    call(obj,0,[C.POINTER(GUID),C.POINTER(C.c_void_p)],C.byref(key),C.byref(result));return result
def activate(device,iid):
    result=C.c_void_p();key=GUID(iid)
    call(device,3,[C.POINTER(GUID),C.c_uint32,C.c_void_p,C.POINTER(C.c_void_p)],C.byref(key),23,None,C.byref(result));return result
def device_id(device):
    value=C.c_void_p();call(device,5,[C.POINTER(C.c_void_p)],C.byref(value))
    text=C.wstring_at(value);ole.CoTaskMemFree(value);return text
def friendly_name(device):
    store=C.c_void_p();call(device,4,[C.c_uint32,C.POINTER(C.c_void_p)],0,C.byref(store))
    key=PROPERTYKEY(GUID('a45c254e-df1c-4efd-8020-67d146a850e0'),14)
    variant=C.create_string_buffer(32)
    try:
        call(store,5,[C.POINTER(PROPERTYKEY),C.c_void_p],C.byref(key),variant)
        if C.c_ushort.from_buffer(variant).value==31:
            return C.wstring_at(C.c_void_p.from_buffer(variant,8).value)
        return 'unknown'
    finally: ole.PropVariantClear(variant);release(store)
def process_name(pid):
    if not pid: return 'system'
    k=C.WinDLL('kernel32',use_last_error=True)
    k.OpenProcess.argtypes=[C.c_uint32,C.c_int,C.c_uint32];k.OpenProcess.restype=C.c_void_p
    k.QueryFullProcessImageNameW.argtypes=[C.c_void_p,C.c_uint32,C.c_wchar_p,C.POINTER(C.c_uint32)]
    k.CloseHandle.argtypes=[C.c_void_p]
    handle=k.OpenProcess(0x1000,False,pid)
    if not handle: return 'unavailable'
    try:
        text=C.create_unicode_buffer(32768);size=C.c_uint32(len(text))
        if k.QueryFullProcessImageNameW(handle,0,text,C.byref(size)): return Path(text.value).name
        return 'unavailable'
    finally: k.CloseHandle(handle)
def inspect():
    ole.CoInitializeEx(None,0)
    enumerator=C.c_void_p();collection=C.c_void_p()
    clsid=GUID('bcde0395-e52f-467c-8e3d-c4579291692e');iid=GUID('a95664d2-9614-4f35-a746-de8db63617e6')
    ole.CoCreateInstance(C.byref(clsid),None,23,C.byref(iid),C.byref(enumerator))
    try:
        defaults={}
        for role in range(3):
            endpoint=C.c_void_p()
            call(enumerator,4,[C.c_int,C.c_int,C.POINTER(C.c_void_p)],0,role,C.byref(endpoint))
            defaults[role]=device_id(endpoint);release(endpoint)
        call(enumerator,3,[C.c_int,C.c_uint32,C.POINTER(C.c_void_p)],0,1,C.byref(collection))
        count=C.c_uint();call(collection,3,[C.POINTER(C.c_uint)],C.byref(count))
        result=[]
        for i in range(count.value):
            device=C.c_void_p();call(collection,4,[C.c_uint,C.POINTER(C.c_void_p)],i,C.byref(device))
            endpoint_id=device_id(device)
            row=dict(device=friendly_name(device),default_roles=[r for r,v in defaults.items() if v==endpoint_id],sessions=[])
            volume=activate(device,'5cdf2c82-841e-4546-9722-0cf74078229a')
            level=C.c_float();mute=C.c_int()
            call(volume,9,[C.POINTER(C.c_float)],C.byref(level));call(volume,15,[C.POINTER(C.c_int)],C.byref(mute))
            row.update(endpoint_volume=round(level.value,4),endpoint_mute=bool(mute.value));release(volume)
            manager=activate(device,'77aa99a0-1bd6-484f-8bc7-2c654c9a9b6f')
            sessions=C.c_void_p();call(manager,5,[C.POINTER(C.c_void_p)],C.byref(sessions))
            session_count=C.c_int();call(sessions,3,[C.POINTER(C.c_int)],C.byref(session_count))
            for j in range(session_count.value):
                control=C.c_void_p();call(sessions,4,[C.c_int,C.POINTER(C.c_void_p)],j,C.byref(control))
                control2=query(control,'bfb7ff88-7239-4fc9-8fa2-07c950be9c6d')
                pid=C.c_uint();state=C.c_int()
                call(control2,14,[C.POINTER(C.c_uint)],C.byref(pid));call(control,3,[C.POINTER(C.c_int)],C.byref(state))
                simple=query(control,'87ce5498-68d6-44e5-9215-6da47ef883d8')
                call(simple,4,[C.POINTER(C.c_float)],C.byref(level));call(simple,6,[C.POINTER(C.c_int)],C.byref(mute))
                row['sessions'].append(dict(pid=pid.value,process=process_name(pid.value),state=state.value,volume=round(level.value,4),mute=bool(mute.value)))
                release(simple);release(control2);release(control)
            release(sessions);release(manager);release(device);result.append(row)
        return result
    finally: release(collection);release(enumerator);ole.CoUninitialize()

if __name__=='__main__': print(json.dumps(inspect(),ensure_ascii=False,indent=2))
