// In-process Windows app master policy. Opens no playback or capture stream.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <process.h>
#include <mmdeviceapi.h>
#include <audiopolicy.h>
#include <functiondiscoverykeys_devpkey.h>
#include <wrl/client.h>
#include <atomic>
#include <mutex>
#include <string>
#include <vector>
#include <set>
#include <memory>
#include <cstring>
#include "master_policy.h"

using Microsoft::WRL::ComPtr;
static const GUID EVENT_CONTEXT={0x3ea2193f,0x916b,0x4394,{0x89,0x8c,0xa1,0x90,0xc2,0x4e,0x1c,0x73}};
struct AudioMasterState {
    std::uint32_t size=sizeof(AudioMasterState);
    std::int32_t status=0; // 0: waiting, 1: linked, -1: unavailable
    std::uint32_t process_id=0,native_sessions=0,linked_sessions=0;
    float volume=0;
    std::int32_t muted=1,last_hresult=0;
    char device_name[256]={};
};
static_assert(sizeof(AudioMasterState)==288,"Lua ABI");

struct Policy;
struct Events final : IAudioSessionEvents {
    std::atomic<ULONG> refs{1};
    Policy* policy;
    DWORD owner;
    Events(Policy* p,DWORD id):policy(p),owner(id) {}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void** out) override {
        if (!out) return E_POINTER;
        *out=nullptr;
        if (iid==__uuidof(IUnknown) || iid==__uuidof(IAudioSessionEvents)) {
            *out=static_cast<IAudioSessionEvents*>(this);AddRef();return S_OK;
        }
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { const ULONG n=--refs;if(!n) delete this;return n; }
    HRESULT STDMETHODCALLTYPE OnDisplayNameChanged(LPCWSTR,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE OnIconPathChanged(LPCWSTR,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE OnSimpleVolumeChanged(float,BOOL,LPCGUID) override;
    HRESULT STDMETHODCALLTYPE OnChannelVolumeChanged(DWORD,float[],DWORD,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE OnGroupingParamChanged(LPCGUID,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE OnStateChanged(AudioSessionState) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE OnSessionDisconnected(AudioSessionDisconnectReason) override {return S_OK;}
};
struct Session {
    std::wstring identity;
    ComPtr<IAudioSessionControl2> control;
    ComPtr<ISimpleAudioVolume> volume;
    ComPtr<Events> events;
    bool native=false,target=false;
    ~Session() { if(control && events) control->UnregisterAudioSessionNotification(events.Get()); }
};
struct Policy {
    std::mutex lock;
    AudioMasterState state;
    std::atomic<bool> running{false};
    HANDLE wake=nullptr,thread=nullptr;
    bool pending=false,have_master=false;
    flaccess::MasterLevel desired;
    std::vector<std::unique_ptr<Session>> sessions;
    std::wstring target_identity;
    std::set<std::wstring> native_session_classes;
    ComPtr<IMMDevice> selected_device;
    ComPtr<IAudioSessionManager2> selected_manager;
    GUID grouping=GUID_NULL;

    void prune() {
        sessions.erase(std::remove_if(sessions.begin(),sessions.end(),[](const auto& s) {
            AudioSessionState current=AudioSessionStateExpired;
            return FAILED(s->control->GetState(&current)) || current==AudioSessionStateExpired;
        }),sessions.end());
    }

    void publish(HRESULT hr) {
        std::lock_guard<std::mutex> guard(lock);
        state.last_hresult=static_cast<std::int32_t>(hr);
        state.process_id=GetCurrentProcessId();
        state.native_sessions=0;state.linked_sessions=static_cast<std::uint32_t>(sessions.size());
        for(auto& s:sessions) if(s->native) ++state.native_sessions;
        bool target_present=false;
        for(auto& s:sessions) if(s->target) target_present=true;
        state.status=FAILED(hr)?-1:(have_master && state.native_sessions>0 && target_present?1:0);
        state.volume=have_master?desired.volume:0;state.muted=!have_master || desired.muted;
    }
    void changed(DWORD owner,float value,BOOL mute,LPCGUID context) {
        const bool own=context && IsEqualGUID(*context,EVENT_CONTEXT);
        if(!flaccess::should_forward(owner,GetCurrentProcessId(),own,value)) return;
        { std::lock_guard<std::mutex> guard(lock);desired={value,mute!=FALSE};pending=true; }
        SetEvent(wake); // Do not call session setters or block inside an audio callback.
    }
    static std::wstring identity(IAudioSessionControl2* control) {
        LPWSTR value=nullptr;
        if(FAILED(control->GetSessionInstanceIdentifier(&value)) || !value) return {};
        std::wstring result(value);CoTaskMemFree(value);return result;
    }
    Session* add(IAudioSessionControl2* control,bool native,bool target) {
        const auto id=identity(control);
        if(id.empty()) return nullptr;
        for(auto& s:sessions) if(s->identity==id) {
            s->target=s->target||target;
            // A target newly made by us must not become an independent native authority.
            if(id!=target_identity) s->native=s->native||native;
            return s.get();
        }
        DWORD owner=0;
        if(FAILED(control->GetProcessId(&owner))) return nullptr;
        // A private default session created here can have no stream/PID yet.
        if(target && owner==0) owner=GetCurrentProcessId();
        if(!flaccess::belongs_to_game(owner,GetCurrentProcessId())) return nullptr;
        auto s=std::make_unique<Session>();s->identity=id;s->control=control;
        if(FAILED(control->QueryInterface(IID_PPV_ARGS(s->volume.GetAddressOf())))) return nullptr;
        auto event=new Events(this,owner);s->events.Attach(event);
        if(FAILED(control->RegisterAudioSessionNotification(event))) return nullptr;
        // A recreated instance is native only if its stable session class was
        // proven before effects started. A new mod stream is not such proof.
        LPWSTR stable=nullptr;
        std::wstring stable_id;
        if(SUCCEEDED(control->GetSessionIdentifier(&stable)) && stable) {
            stable_id=stable;CoTaskMemFree(stable);
        }
        if(native && !stable_id.empty()) native_session_classes.insert(stable_id);
        const bool recovered=!target && !stable_id.empty() && native_session_classes.count(stable_id)!=0;
        s->native=native||recovered;s->target=target;
        auto* result=s.get();sessions.push_back(std::move(s));return result;
    }
    void device_name(IMMDevice* device) {
        ComPtr<IPropertyStore> store;
        if(FAILED(device->OpenPropertyStore(STGM_READ,store.GetAddressOf()))) return;
        PROPVARIANT value;PropVariantInit(&value);
        if(SUCCEEDED(store->GetValue(PKEY_Device_FriendlyName,&value)) && value.vt==VT_LPWSTR && value.pwszVal) {
            char utf8[256]={};
            WideCharToMultiByte(CP_UTF8,0,value.pwszVal,-1,utf8,sizeof(utf8),nullptr,nullptr);
            std::lock_guard<std::mutex> guard(lock);std::memcpy(state.device_name,utf8,sizeof(utf8));
        }
        PropVariantClear(&value);
    }
    HRESULT discover(IMMDeviceEnumerator* enumerator) {
        prune();
        ComPtr<IMMDeviceCollection> devices;
        HRESULT hr=enumerator->EnumAudioEndpoints(eRender,DEVICE_STATE_ACTIVE,devices.GetAddressOf());
        if(FAILED(hr)) return hr;
        UINT count=0;devices->GetCount(&count);
        flaccess::MasterLevel baseline;bool first=true;
        for(UINT i=0;i<count;++i) {
            ComPtr<IMMDevice> device;devices->Item(i,device.GetAddressOf());if(!device) continue;
            ComPtr<IAudioSessionManager2> manager;
            if(FAILED(device->Activate(__uuidof(IAudioSessionManager2),CLSCTX_ALL,nullptr,reinterpret_cast<void**>(manager.GetAddressOf())))) continue;
            ComPtr<IAudioSessionEnumerator> list;
            if(FAILED(manager->GetSessionEnumerator(list.GetAddressOf()))) continue;
            int n=0;list->GetCount(&n);
            for(int j=0;j<n;++j) {
                ComPtr<IAudioSessionControl> control;list->GetSession(j,control.GetAddressOf());if(!control) continue;
                ComPtr<IAudioSessionControl2> control2;
                if(FAILED(control.As(&control2))) continue;
                DWORD owner=0;control2->GetProcessId(&owner);
                if(!flaccess::belongs_to_game(owner,GetCurrentProcessId())) continue;
                AudioSessionState active=AudioSessionStateExpired;control->GetState(&active);
                if(active==AudioSessionStateExpired) continue;
                const auto id=identity(control2.Get());
                // Only the pre-effect baseline can prove native game authority.
                // A future mod session must not keep readiness alive on its own.
                auto* entry=add(control2.Get(),!have_master && id!=target_identity,false);
                if(!entry) continue;
                if(!have_master && entry->native && active==AudioSessionStateActive) {
                    float v=0;BOOL mute=TRUE;
                    if(SUCCEEDED(entry->volume->GetMasterVolume(&v)) && flaccess::valid_level(v) && SUCCEEDED(entry->volume->GetMute(&mute))) {
                        baseline=flaccess::inherit_level(baseline,{v,mute!=FALSE},first);first=false;
                        if(!selected_device) {
                            selected_device=device;selected_manager=manager;
                            control->GetGroupingParam(&grouping);device_name(device.Get());
                        }
                    }
                }
            }
        }
        if(!have_master && !first && selected_manager) {
            ComPtr<IAudioSessionControl> target;
            hr=selected_manager->GetAudioSessionControl(nullptr,0,target.GetAddressOf());
            if(FAILED(hr)) return hr;
            ComPtr<IAudioSessionControl2> target2;
            if(FAILED(hr=target.As(&target2))) return hr;
            target_identity=identity(target2.Get());
            if(target_identity.empty()) return E_FAIL;
            auto* entry=add(target2.Get(),false,true);if(!entry) return E_FAIL;
            // Keep the Windows app grouping of the game's existing session.
            target->SetGroupingParam(&grouping,&EVENT_CONTEXT);
            { std::lock_guard<std::mutex> guard(lock);if(!pending) desired=baseline; }
            have_master=true;
        }
        if(have_master && selected_manager) {
            bool target_present=false,native_present=false;
            for(auto& session:sessions) {
                target_present=target_present||session->target;
                native_present=native_present||session->native;
            }
            if(!target_present && native_present) {
                ComPtr<IAudioSessionControl> target;
                hr=selected_manager->GetAudioSessionControl(nullptr,0,target.GetAddressOf());
                if(FAILED(hr)) return hr;
                ComPtr<IAudioSessionControl2> target2;
                if(FAILED(hr=target.As(&target2))) return hr;
                target_identity=identity(target2.Get());
                if(target_identity.empty() || !add(target2.Get(),false,true)) return E_FAIL;
                target->SetGroupingParam(&grouping,&EVENT_CONTEXT);
            }
        }
        return S_OK;
    }
    HRESULT apply() {
        if(!have_master) return S_FALSE;
        flaccess::MasterLevel level;
        { std::lock_guard<std::mutex> guard(lock);level=desired;pending=false; }
        HRESULT result=S_OK;
        for(auto& s:sessions) {
            AudioSessionState session_state=AudioSessionStateExpired;
            if(FAILED(s->control->GetState(&session_state)) || session_state==AudioSessionStateExpired) continue;
            float value=0;BOOL muted=TRUE;
            HRESULT hr=s->volume->GetMasterVolume(&value);if(FAILED(hr)) {result=hr;continue;}
            hr=s->volume->GetMute(&muted);if(FAILED(hr)) {result=hr;continue;}
            if(std::fabs(value-level.volume)>0.00001f) {
                hr=s->volume->SetMasterVolume(level.volume,&EVENT_CONTEXT);if(FAILED(hr)) result=hr;
            }
            if((muted!=FALSE)!=level.muted) {
                hr=s->volume->SetMute(level.muted,&EVENT_CONTEXT);if(FAILED(hr)) result=hr;
            }
        }
        return result;
    }
    void run() {
        HRESULT hr=CoInitializeEx(nullptr,COINIT_MULTITHREADED);
        if(FAILED(hr)) {publish(hr);return;}
        ComPtr<IMMDeviceEnumerator> enumerator;
        hr=CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_ALL,IID_PPV_ARGS(enumerator.GetAddressOf()));
        ULONGLONG next=0;
        while(running && SUCCEEDED(hr)) {
            const auto now=GetTickCount64();
            if(now>=next) {hr=discover(enumerator.Get());next=now+500;}
            if(SUCCEEDED(hr)) hr=apply();
            publish(hr);
            // Events wake the worker immediately; periodic discovery includes future streams.
            WaitForSingleObject(wake,50);
            if(hr==S_FALSE) hr=S_OK;
        }
        if(FAILED(hr)) publish(hr);
        sessions.clear();selected_manager.Reset();selected_device.Reset();enumerator.Reset();
        CoUninitialize();
    }
};
// Process-owned singleton: never release COM objects under DLL loader-lock teardown.
// Explicit Stop unregisters notifications on the worker while COM is still alive.
static Policy& policy=*new Policy;
static std::mutex lifecycle;
HRESULT STDMETHODCALLTYPE Events::OnSimpleVolumeChanged(float volume,BOOL mute,LPCGUID context) {
    policy->changed(owner,volume,mute,context);return S_OK;
}
extern "C" __declspec(dllexport) int __cdecl FLAccessAudio_Start() {
    std::lock_guard<std::mutex> guard(lifecycle);
    if(policy.thread) return 1;
    HMODULE module=nullptr;
    // Worker and registered COM callbacks must never outlive their code on Lua reload.
    if(!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_PIN,
        reinterpret_cast<LPCWSTR>(&FLAccessAudio_Start),&module)) return 0;
    policy.wake=CreateEventW(nullptr,FALSE,FALSE,nullptr);if(!policy.wake) return 0;
    policy.running=true;
    policy.thread=reinterpret_cast<HANDLE>(_beginthreadex(nullptr,0,[](void*)->unsigned {policy.run();return 0;},nullptr,0,nullptr));
    if(!policy.thread) {policy.running=false;CloseHandle(policy.wake);policy.wake=nullptr;return 0;}
    return 1;
}
extern "C" __declspec(dllexport) int __cdecl FLAccessAudio_GetState(AudioMasterState* out) {
    if(!out || out->size!=sizeof(AudioMasterState)) return 0;
    std::lock_guard<std::mutex> guard(policy.lock);*out=policy.state;return 1;
}
extern "C" __declspec(dllexport) void __cdecl FLAccessAudio_Stop() {
    std::lock_guard<std::mutex> guard(lifecycle);
    if(!policy.thread) return;
    policy.running=false;SetEvent(policy.wake);
    WaitForSingleObject(policy.thread,INFINITE);
    CloseHandle(policy.thread);CloseHandle(policy.wake);policy.thread=nullptr;policy.wake=nullptr;
    std::lock_guard<std::mutex> state_guard(policy.lock);
    policy.have_master=false;policy.pending=false;policy.target_identity.clear();
    policy.desired={};policy.state=AudioMasterState{};
}
