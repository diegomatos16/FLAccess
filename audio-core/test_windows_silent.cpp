// Development-only: real Windows silent streams in THIS test process.
// Never opens the game's process, endpoint volume or another app's session.
#include "audio_master.cpp"
#include <audioclient.h>
#include <iostream>
#include <stdexcept>
static void check(HRESULT hr,const char* where) {
    if(FAILED(hr)) {std::cerr<<where<<" HRESULT="<<std::hex<<hr<<"\n";throw std::runtime_error(where);}
}
template<class Predicate> static void until(Predicate predicate,const char* where) {
    const auto deadline=GetTickCount64()+4000;
    do {if(predicate()) return;Sleep(10);} while(GetTickCount64()<deadline);
    throw std::runtime_error(where);
}
int wmain(int argc,wchar_t** argv) {
    if(argc!=2) return 2;
    try {
        check(CoInitializeEx(nullptr,COINIT_MULTITHREADED),"COM");
        ComPtr<IMMDeviceEnumerator> enumerator;
        check(CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_ALL,IID_PPV_ARGS(enumerator.GetAddressOf())),"enumerator");
        ComPtr<IMMDevice> device;check(enumerator->GetDefaultAudioEndpoint(eRender,eMultimedia,device.GetAddressOf()),"default endpoint");
        ComPtr<IAudioClient> client;
        check(device->Activate(__uuidof(IAudioClient),CLSCTX_ALL,nullptr,reinterpret_cast<void**>(client.GetAddressOf())),"audio client");
        WAVEFORMATEX* format=nullptr;check(client->GetMixFormat(&format),"format");
        const GUID native_guid={0x61fd3315,0x4111,0x4631,{0xa3,0x44,0x18,0x91,0xa1,0xb2,0xc3,0x42}};
        check(client->Initialize(AUDCLNT_SHAREMODE_SHARED,0,1000000,0,format,&native_guid),"silent native stream");
        CoTaskMemFree(format);
        ComPtr<ISimpleAudioVolume> native_volume;check(client->GetService(IID_PPV_ARGS(native_volume.GetAddressOf())),"native volume");
        check(native_volume->SetMute(TRUE,nullptr),"mute own synthetic native session");
        check(native_volume->SetMasterVolume(0.35f,nullptr),"initial synthetic native volume");
        ComPtr<IAudioRenderClient> render;check(client->GetService(IID_PPV_ARGS(render.GetAddressOf())),"render");
        UINT32 size=0;check(client->GetBufferSize(&size),"size");BYTE* bytes=nullptr;
        check(render->GetBuffer(size,&bytes),"silent buffer");
        check(render->ReleaseBuffer(size,AUDCLNT_BUFFERFLAGS_SILENT),"silence");check(client->Start(),"start silent native stream");
        if(!FLAccessAudio_Start()) throw std::runtime_error("master start");
        AudioMasterState state;
        until([&] {
            FLAccessAudio_GetState(&state);
            if(state.status<0) {
                std::cerr<<"master error="<<std::hex<<state.last_hresult<<" native="<<state.native_sessions<<" linked="<<state.linked_sessions<<"\n";
                throw std::runtime_error("master unavailable");
            }
            return state.status==1;
        },"master never linked");
        std::cout<<"LINKED native="<<state.native_sessions<<" sessions="<<state.linked_sessions<<" mute="<<state.muted<<" volume="<<state.volume<<"\n";
        ComPtr<IAudioSessionManager2> manager;
        check(device->Activate(__uuidof(IAudioSessionManager2),CLSCTX_ALL,nullptr,reinterpret_cast<void**>(manager.GetAddressOf())),"manager");
        ComPtr<ISimpleAudioVolume> target;check(manager->GetSimpleAudioVolume(nullptr,0,target.GetAddressOf()),"default target");
        const auto matches=[&](float expected,BOOL muted) {
            float v=0;BOOL m=FALSE;check(target->GetMasterVolume(&v),"read own target");check(target->GetMute(&m),"read own mute");
            return std::fabs(v-expected)<0.0001f && m==muted;
        };
        until([&] {return matches(0.35f,TRUE);},"target did not inherit before playback");
        SetEnvironmentVariableA("ALSOFT_DRIVERS","wasapi");
        HMODULE openal=LoadLibraryW(argv[1]);if(!openal) throw std::runtime_error("load OpenAL");
        auto open=reinterpret_cast<void*(__cdecl*)(const char*)>(GetProcAddress(openal,"alcOpenDevice"));
        auto create=reinterpret_cast<void*(__cdecl*)(void*,const int*)>(GetProcAddress(openal,"alcCreateContext"));
        auto destroy=reinterpret_cast<void(__cdecl*)(void*)>(GetProcAddress(openal,"alcDestroyContext"));
        auto close=reinterpret_cast<char(__cdecl*)(void*)>(GetProcAddress(openal,"alcCloseDevice"));
        if(!open || !create || !destroy || !close) throw std::runtime_error("OpenAL exports");
        const std::string name=std::string("OpenAL Soft on ")+state.device_name;
        void* output=open(name.c_str());if(!output) throw std::runtime_error("OpenAL game endpoint open");
        const int attributes[]={0x1992,1,0};
        void* context=create(output,attributes);if(!context) throw std::runtime_error("HRTF context");
        ComPtr<IAudioSessionControl> target_control;
        check(manager->GetAudioSessionControl(nullptr,0,target_control.GetAddressOf()),"default target control");
        until([&] {
            AudioSessionState activity=AudioSessionStateExpired;
            check(target_control->GetState(&activity),"default target activity");
            return activity==AudioSessionStateActive;
        },"OpenAL did not activate the prepared default session");
        until([&] {return matches(0.35f,TRUE);},"OpenAL changed target master");
        check(native_volume->SetMasterVolume(0.6f,nullptr),"lower own synthetic session");
        until([&] {return matches(0.6f,TRUE);},"volume event not forwarded");
        check(native_volume->SetMute(FALSE,nullptr),"unmute synthetic silent stream");
        until([&] {return matches(0.6f,FALSE);},"unmute event not forwarded");
        check(native_volume->SetMasterVolume(0,nullptr),"zero own synthetic session");
        until([&] {return matches(0,FALSE);},"zero event not forwarded");
        destroy(context);close(output);FreeLibrary(openal);
        FLAccessAudio_Stop();check(client->Stop(),"stop silent stream");
        std::cout<<"PASS real Windows WASAPI + installed OpenAL HRTF: prepared default session became active, initial master before playback, volume, mute/unmute, zero; all streams silent and owned by test PID\n";
        return 0;
    } catch(const std::exception& error) {
        std::cerr<<"FAIL "<<error.what()<<"\n";FLAccessAudio_Stop();return 1;
    }
}
