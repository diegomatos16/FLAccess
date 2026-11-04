"""One-time migration of assets and source paths; never installs into the game."""
from pathlib import Path
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / 'modules/FlAccess'
READER = ['bootstrap', 'memory_prism', 'text_intents', 'speech_queue', 'semantics',
          'review', 'native_tree', 'native_windows', 'presentation', 'players',
          'controls', 'observations', 'resolver', 'focus', 'frame', 'lifecycle']
GAMEPLAY = ['state', 'rules', 'memory', 'audio', 'match', 'diagnostics', 'render', 'lifecycle']

def prepare():
    if (TARGET / 'components.json').exists():
        raise RuntimeError('Migration already performed; edit modules/FlAccess directly')
    shutil.copytree(ROOT / 'livecpk/FlAccessReader/text', ROOT / 'content/FlAccess/text', dirs_exist_ok=True)
    shutil.copytree(ROOT / 'livecpk/FlAccessGameplay/sounds', ROOT / 'content/FlAccess/sounds', dirs_exist_ok=True)
    shutil.copytree(ROOT / 'modules/FlAccessGameplay/engine/cameraRadars', ROOT / 'content/FlAccess/cameras', dirs_exist_ok=True)
    for name in ('soft_oal.dll', 'flaccess_audio_master.dll'):
        (TARGET / 'bin').mkdir(exist_ok=True)
        shutil.copy2(ROOT / 'modules/FlAccessGameplay/bin' / name, TARGET / 'bin' / name)
    (TARGET / 'state').mkdir(exist_ok=True)
    shutil.copy2(ROOT / 'modules/FlAccessGameplay/state/live-layout.txt', TARGET / 'state/live-layout.txt')
    shutil.copy2(ROOT / 'modules/FlAccessGameplay/COPYING.OpenAL', TARGET / 'COPYING.OpenAL')
    # These services already have isolated state and public module interfaces.
    for source, dest in [('audio','audio_policy'), ('registry','match_registry'), ('cameraRadars','camera')]:
        text = (ROOT / 'modules/FlAccessGameplay/engine' / (source+'.lua')).read_text(encoding='utf-8')
        if source == 'cameraRadars':
            text = text.replace('function m.init(ctx,profiles,read_profile)', '''function m.init(ctx,profiles,read_profile)
    profiles = profiles or {}''')
        (TARGET / (dest+'.lua')).write_text(text, encoding='utf-8')
    replacements = {
        'modules\\\\FlAccessReader\\\\bin\\\\': 'modules\\\\FlAccess\\\\bin\\\\',
        'modules\\\\FlAccessGameplay\\\\bin\\\\': 'modules\\\\FlAccess\\\\bin\\\\',
        'modules\\\\FlAccessGameplay\\\\state\\\\': 'modules\\\\FlAccess\\\\state\\\\',
        'modules\\\\FlAccessReader\\\\FlAccessReader.ini': 'modules\\\\FlAccess\\\\FlAccess.ini',
        'modules\\\\FlAccessGameplay\\\\FlAccessGameplay.ini': 'modules\\\\FlAccess\\\\FlAccess.ini',
        'modules\\\\FlAccessReader\\\\FlAccessReader.lua': 'modules\\\\FlAccess\\\\reader_lifecycle.lua',
        'modules\\\\FlAccessGameplay\\\\engine\\\\cameraRadars\\\\': 'content\\\\FlAccess\\\\cameras\\\\',
        'livecpk\\\\FlAccessReader\\\\text\\\\': 'content\\\\FlAccess\\\\text\\\\',
        'livecpk\\\\FlAccessGameplay\\\\sounds\\\\': 'content\\\\FlAccess\\\\sounds\\\\',
    }
    for file in TARGET.glob('*.lua'):
        text = file.read_text(encoding='utf-8')
        for old, new in replacements.items(): text=text.replace(old,new)
        text=text.replace('FlAccessReader %s', 'FLAccess %s').replace('FlAccessReader versão %s', 'FLAccess versão %s').replace('FlAccessReader version %s', 'FLAccess version %s')
        if file.name=='reader_bootstrap.lua':
            text=text.replace('shared.VERSION = "0.1.9"','shared.VERSION = "0.2.0"').replace('name = "FlAccessReader"','name = "FLAccess"').replace('build = 42,','build = 43,')
        if file.name=='reader_text_intents.lua':
            start=text.index('function shared.a11y.save_config()')
            end=text.index('\nfunction ',start+10)
            text=text[:start]+'''function shared.a11y.save_config()
    shared.save_config_values(shared.a11y)
end
''' + text[end:]
        if file.name=='gameplay_state.lua': text=text.replace('0.1.0 experiment 16','0.2.0 experimental16 preserved')
        file.write_text(text,encoding='utf-8')
    order=['core']+['reader_'+n for n in READER]+['audio_policy','match_registry','camera']+['gameplay_'+n for n in GAMEPLAY]
    manifest={'version':'0.2.0','modules':['FlAccess/'+n+'.lua' for n in order],
              'reader':['FlAccess/reader_'+n+'.lua' for n in READER],
              'gameplay':['FlAccess/gameplay_'+n+'.lua' for n in GAMEPLAY]}
    (TARGET / 'components.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    snippet='; FLAccess 0.2.0. Load in this order. Base reader is mandatory.\n'
    snippet+='lua.enabled = 1\nluajit.ext.enabled = 1\nmatch-stats.enabled = 1\n'
    snippet+=''.join('lua.module = "'+n.replace('/','\\')+'"\n' for n in manifest['modules'])
    (ROOT/'packaging/sider.ini.snippet').write_text(snippet,encoding='utf-8')
    print('FLACCESS020_PREPARED',len(order),'native modules')

if __name__=='__main__': prepare()
