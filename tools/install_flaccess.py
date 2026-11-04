"""Install FLAccess native components; preserve Sider core, other mods and preferences."""
from pathlib import Path
import argparse
import datetime
import hashlib
import json
import re
import shutil

ROOT=Path(__file__).resolve().parents[1]

def merge_settings(base, override):
    lines=base.splitlines()
    for line in override.splitlines():
        match=re.match(r'\s*([\w_]+)\s*=',line)
        if not match: continue
        key=match[1]
        hits=[i for i,old in enumerate(lines) if re.match(r'\s*'+re.escape(key)+r'\s*=',old)]
        if hits:
            for i in hits: lines[i]=line
        else: lines.append(line)
    return '\n'.join(lines)+'\n'

def migrate_ini(text, entries):
    old_modules={'flaccessreader\\flaccessreader.lua','flaccessgameplay\\flaccessgameplay.lua',
                 'flaccess.lua','flaccess_gameplay.lua'}
    lines=text.splitlines(keepends=True);result=[];inserted=False
    newline='\r\n' if '\r\n' in text else '\n'
    block=''.join('lua.module = "'+p.replace('/','\\')+'"'+newline for p in entries)
    for line in lines:
        match=re.match(r'\s*lua\.module\s*=\s*"([^"]+)"',line,re.I)
        active=match and (match[1].lower() in old_modules or match[1].lower().startswith('flaccess\\'))
        if active:
            if not inserted: result.append(block);inserted=True
            continue
        match=re.match(r'\s*cpk\.root\s*=\s*"([^"]+)"',line,re.I)
        if match and match[1].replace('/','\\').lower().rstrip('\\') in (
            '.\\livecpk\\flaccessreader','.\\livecpk\\flaccessgameplay'): continue
        result.append(line)
    if not inserted: raise ValueError('No active FLAccess entry found; choose installation position explicitly')
    return ''.join(result)

def install(root, sider):
    root,sider=Path(root).resolve(),Path(sider).resolve()
    if not (sider/'sider.ini').is_file() or not (sider/'sider.dll').is_file():
        raise ValueError('Expected existing Sider installation')
    # Fail before writes if package/dependency manifest is incomplete.
    components=json.loads((root/'modules/FlAccess/components.json').read_text())
    for entry in components['modules']:
        if not (root/'modules'/entry).is_file(): raise ValueError('Missing component '+entry)
    before=(sider/'sider.ini').read_bytes()
    rewritten=migrate_ini(before.decode('utf-8-sig'),components['modules']).encode('utf-8')
    core_hash=hashlib.sha256((sider/'sider.dll').read_bytes()).hexdigest()
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    backup=root/'local-backups'/('flaccess020-install-'+stamp)
    backup.mkdir(parents=True)
    (backup/'sider.ini').write_bytes(before)
    if (sider/'modules/FlAccess').exists(): shutil.copytree(sider/'modules/FlAccess',backup/'modules/FlAccess')
    if (sider/'content/FlAccess').exists(): shutil.copytree(sider/'content/FlAccess',backup/'content/FlAccess')
    target=sider/'modules/FlAccess'
    first=not (target/'FlAccess.ini').exists()
    defaults=(root/'modules/FlAccess/FlAccess.ini').read_text(encoding='utf-8')
    if first:
        for legacy in ('modules/FlAccessReader/FlAccessReader.ini','modules/FlAccessGameplay/FlAccessGameplay.ini'):
            path=sider/legacy
            if path.exists():
                saved=backup/legacy;saved.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(path,saved)
                defaults=merge_settings(defaults,path.read_text(encoding='utf-8-sig'))
    for source in (root/'modules/FlAccess').rglob('*'):
        if not source.is_file() or '__pycache__' in source.parts: continue
        relative=source.relative_to(root/'modules/FlAccess');destination=target/relative
        if relative.as_posix()=='FlAccess.ini': continue
        if relative.parts[0]=='state' and source.name!='live-layout.txt': continue
        if relative.as_posix()=='state/live-layout.txt' and destination.exists(): continue
        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,destination)
    if first: (target/'FlAccess.ini').write_text(defaults,encoding='utf-8')
    migrated={}
    for source in (root/'content/FlAccess').rglob('*'):
        if not source.is_file(): continue
        relative=source.relative_to(root/'content/FlAccess');destination=sider/'content/FlAccess'/relative
        if destination.exists(): continue  # preserve edited resources on later installs
        legacy={'sounds':'livecpk/FlAccessGameplay/sounds','text':'livecpk/FlAccessReader/text',
                'cameras':'modules/FlAccessGameplay/engine/cameraRadars'}[relative.parts[0]]
        previous=sider/legacy/Path(*relative.parts[1:])
        selected=previous if previous.is_file() else source
        destination.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(selected,destination)
        migrated[relative.as_posix()]=hashlib.sha256(destination.read_bytes()).hexdigest()
    legacy_layout=sider/'modules/FlAccessGameplay/state/live-layout.txt'
    if first and legacy_layout.exists(): shutil.copy2(legacy_layout,target/'state/live-layout.txt')
    (sider/'sider.ini').write_bytes(rewritten)
    assert hashlib.sha256((sider/'sider.dll').read_bytes()).hexdigest()==core_hash
    installed={}
    for entry in components['modules']:
        source=root/'modules'/entry;destination=sider/'modules'/entry
        assert source.read_bytes()==destination.read_bytes()
        installed[entry]=hashlib.sha256(destination.read_bytes()).hexdigest()
    report={'version':'0.2.0','sider':str(sider),'backup':str(backup),'modules':installed,
            'sider_dll_unchanged':core_hash,'resources_migrated':migrated,
            'prism':json.loads((target/'PRISM-SOURCE.json').read_text())}
    (backup/'INSTALL.json').write_text(json.dumps(report,indent=2)+'\n')
    return report

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sider',type=Path,required=True)
    parser.add_argument('--root',type=Path,default=ROOT)
    args=parser.parse_args()
    report=install(args.root,args.sider)
    print(json.dumps(report,indent=2))
