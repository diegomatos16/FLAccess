// Exercise the actual COM callback/forwarding implementation using fake sessions.
// No session enumeration, mixer access, playback or capture in this executable.
#include "audio_master.cpp"
#include <cassert>
#include <iostream>
struct FakeSession final : IAudioSessionControl2, ISimpleAudioVolume {
    std::atomic<ULONG> refs{1};
    DWORD owner;
    std::wstring id;
    std::wstring stable_id;
    float level;
    BOOL mute=FALSE;
    AudioSessionState activity=AudioSessionStateActive;
    IAudioSessionEvents* events=nullptr;
    int volume_sets=0,mute_sets=0;
    FakeSession(DWORD pid,const wchar_t* name,float v):owner(pid),id(name),level(v) {}
    ~FakeSession() {assert(events==nullptr);}
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid,void** out) override {
        if(!out) return E_POINTER;
        *out=nullptr;
        if(iid==__uuidof(IUnknown) || iid==__uuidof(IAudioSessionControl) || iid==__uuidof(IAudioSessionControl2))
            *out=static_cast<IAudioSessionControl2*>(this);
        else if(iid==__uuidof(ISimpleAudioVolume)) *out=static_cast<ISimpleAudioVolume*>(this);
        else return E_NOINTERFACE;
        AddRef();return S_OK;
    }
    ULONG STDMETHODCALLTYPE AddRef() override {return ++refs;}
    ULONG STDMETHODCALLTYPE Release() override {const auto n=--refs;if(!n) delete this;return n;}
    HRESULT STDMETHODCALLTYPE GetState(AudioSessionState* out) override {*out=activity;return S_OK;}
    HRESULT STDMETHODCALLTYPE GetDisplayName(LPWSTR*) override {return E_NOTIMPL;}
    HRESULT STDMETHODCALLTYPE SetDisplayName(LPCWSTR,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE GetIconPath(LPWSTR*) override {return E_NOTIMPL;}
    HRESULT STDMETHODCALLTYPE SetIconPath(LPCWSTR,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE GetGroupingParam(GUID* out) override {*out=GUID_NULL;return S_OK;}
    HRESULT STDMETHODCALLTYPE SetGroupingParam(LPCGUID,LPCGUID) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE RegisterAudioSessionNotification(IAudioSessionEvents* e) override {events=e;e->AddRef();return S_OK;}
    HRESULT STDMETHODCALLTYPE UnregisterAudioSessionNotification(IAudioSessionEvents* e) override {
        assert(events==e);events=nullptr;e->Release();return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetSessionIdentifier(LPWSTR* out) override {
        if(stable_id.empty()) return GetSessionInstanceIdentifier(out);
        const auto size=(stable_id.size()+1)*sizeof(wchar_t);
        *out=static_cast<LPWSTR>(CoTaskMemAlloc(size));if(!*out) return E_OUTOFMEMORY;
        std::memcpy(*out,stable_id.c_str(),size);return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetSessionInstanceIdentifier(LPWSTR* out) override {
        const auto size=(id.size()+1)*sizeof(wchar_t);*out=static_cast<LPWSTR>(CoTaskMemAlloc(size));
        if(!*out) return E_OUTOFMEMORY;
        std::memcpy(*out,id.c_str(),size);return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetProcessId(DWORD* out) override {*out=owner;return S_OK;}
    HRESULT STDMETHODCALLTYPE IsSystemSoundsSession() override {return S_FALSE;}
    HRESULT STDMETHODCALLTYPE SetDuckingPreference(BOOL) override {return S_OK;}
    HRESULT STDMETHODCALLTYPE SetMasterVolume(float v,LPCGUID context) override {
        level=v;++volume_sets;if(events) events->OnSimpleVolumeChanged(level,mute,context);return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetMasterVolume(float* out) override {*out=level;return S_OK;}
    HRESULT STDMETHODCALLTYPE SetMute(BOOL v,LPCGUID context) override {
        mute=v;++mute_sets;if(events) events->OnSimpleVolumeChanged(level,mute,context);return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetMute(BOOL* out) override {*out=mute;return S_OK;}
};
int main() {
    Policy p;p.wake=CreateEventW(nullptr,FALSE,FALSE,nullptr);assert(p.wake);
    const auto pid=GetCurrentProcessId();
    ComPtr<FakeSession> game,effect,foreign,later;
    game.Attach(new FakeSession(pid,L"game",0.5f));
    effect.Attach(new FakeSession(0,L"default",1)); // Our target has no stream yet.
    foreign.Attach(new FakeSession(pid+1,L"other-app",0.8f));
    assert(p.add(game.Get(),true,false));
    assert(!p.add(foreign.Get(),true,false));
    p.target_identity=L"default";assert(p.add(effect.Get(),false,true));
    p.have_master=true;p.desired={0.5f,false};
    assert(SUCCEEDED(p.apply()));
    assert(effect->level==0.5f && game->level==0.5f && game->volume_sets==0);
    assert(!p.pending); // Own callback cannot start another change.
    p.publish(S_OK);assert(p.state.status==1 && p.state.native_sessions==1);
    game->SetMasterVolume(0.2f,nullptr);assert(p.pending);
    assert(SUCCEEDED(p.apply()));assert(effect->level==0.2f && game->level==0.2f && !p.pending);
    game->SetMute(TRUE,nullptr);assert(SUCCEEDED(p.apply()));assert(effect->mute==TRUE);
    game->SetMasterVolume(0,nullptr);assert(SUCCEEDED(p.apply()));assert(effect->level==0);
    effect->SetMasterVolume(0.7f,nullptr);effect->SetMute(FALSE,nullptr);
    assert(SUCCEEDED(p.apply()));assert(game->level==0.7f && !game->mute);
    later.Attach(new FakeSession(pid,L"future-effect",1));assert(p.add(later.Get(),false,false));
    assert(SUCCEEDED(p.apply()));assert(later->level==0.7f);
    assert(foreign->level==0.8f && foreign->volume_sets==0 && foreign->mute_sets==0);
    game->activity=AudioSessionStateExpired;
    p.prune();p.publish(S_OK);assert(p.state.status==0 && p.state.native_sessions==0);
    assert(!game->events && later->events); // A surviving mod stream is not native proof.
    ComPtr<FakeSession> replacement;
    replacement.Attach(new FakeSession(pid,L"game-recreated",0.9f));replacement->stable_id=game->id;
    auto* recovered=p.add(replacement.Get(),false,false);assert(recovered && recovered->native);
    p.publish(S_OK);assert(p.state.native_sessions==1 && p.state.status==1);
    assert(SUCCEEDED(p.apply()) && replacement->level==0.7f && !replacement->mute);
    replacement->activity=AudioSessionStateExpired;p.prune();
    p.publish(S_OK);assert(p.state.native_sessions==0 && p.state.status==0);
    // Surviving effects remain insufficient to prove game-audio readiness.
    p.sessions.clear();CloseHandle(p.wake);p.wake=nullptr;
    std::cout << "PASS native session integration: initial level, callbacks, mute, zero, restore, future streams, PID isolation, pruning; fake COM only\n";
}
