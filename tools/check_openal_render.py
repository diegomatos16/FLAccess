"""Render the actual ball WAV through OpenAL HRTF off-device; do not play audio."""
import array
import ctypes as C
import math
import wave
from pathlib import Path

root=Path(__file__).resolve().parents[2]/'SiderAddons'/'modules'/'FlAccessGameplay'/'bin'
assets=Path(__file__).resolve().parents[2]/'SiderAddons'/'livecpk'/'FlAccessGameplay'/'sounds'
al=C.CDLL(str(root/'soft_oal.dll'))
def bind(name,result,args):
    function=getattr(al,name);function.restype=result;function.argtypes=args;return function
vp=C.c_void_p;I=C.c_int;U=C.c_uint;F=C.c_float
open_loop=bind('alcLoopbackOpenDeviceSOFT',vp,[C.c_char_p])
create=bind('alcCreateContext',vp,[vp,C.POINTER(I)])
current=bind('alcMakeContextCurrent',C.c_char,[vp])
render=bind('alcRenderSamplesSOFT',None,[vp,vp,I])
destroy=bind('alcDestroyContext',None,[vp]);close=bind('alcCloseDevice',C.c_char,[vp])
gen_buffers=bind('alGenBuffers',None,[I,C.POINTER(U)])
buffer_data=bind('alBufferData',None,[U,I,vp,I,I])
gen_sources=bind('alGenSources',None,[I,C.POINTER(U)])
source_i=bind('alSourcei',None,[U,I,I]);source_f=bind('alSourcef',None,[U,I,F])
source_xyz=bind('alSource3f',None,[U,I,F,F,F]);play=bind('alSourcePlay',None,[U])
distance=bind('alDistanceModel',None,[I]);error=bind('alGetError',I,[])
get_int=bind('alcGetIntegerv',None,[vp,I,I,C.POINTER(I)])
listener=bind('alListenerfv',None,[I,C.POINTER(F)])
device=open_loop(None)
if not device: raise RuntimeError('loopback device unavailable')
context=None
try:
    attrs=(I*11)(0x1990,0x1501,0x1991,0x1402,0x1007,48000,0x1992,1,0,0,0)
    context=create(device,attrs)
    if not context: raise RuntimeError('loopback context unavailable')
    current(context)
    enabled=I();get_int(device,0x1992,1,C.byref(enabled));assert enabled.value==1
    buffer,source=U(),U();gen_buffers(1,C.byref(buffer));gen_sources(1,C.byref(source))
    with wave.open(str(assets/'ball.wav'),'rb') as wav:
        assert wav.getnchannels()==1 and wav.getsampwidth()==2
        pcm=wav.readframes(wav.getnframes());rate=wav.getframerate()
    data=C.create_string_buffer(pcm);buffer_data(buffer,0x1101,data,len(pcm),rate)
    source_i(source,0x1009,buffer.value);source_i(source,0x1007,1)
    source_f(source,0x100a,0.2);distance(0)
    source_xyz(source,0x1004,12,0.1,-8)
    listener(0x100f,(F*6)(0,0,-1,0,1,0))
    play(source);assert error()==0
    output=(C.c_int16*(48000*2))();render(device,output,48000);assert error()==0
    values=array.array('h',bytes(output))
    rms=math.sqrt(sum(v*v for v in values)/len(values))/32768
    peak=max(abs(v) for v in values)/32768
    assert rms>0.0001,'OpenAL output is silent'
    print(f'HRTF actual ball WAV, real-game-like position, gain 0.2: RMS={rms:.6f} peak={peak:.6f}; generated PCM is nonzero; this does not verify Windows playback')
finally:
    current(None)
    if context: destroy(context)
    close(device)
