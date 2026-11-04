/* One-time, scope-aware migration from lexical bundles to native Sider modules.
 * Never replaces identifiers inside strings, comments, keys or shadowed locals.
 * Maintained output is ordinary Lua: no runtime loader or generated interpreter.
 */
const fs = require('fs'), path = require('path');
const root = path.resolve(__dirname, '..');
const lua = require(path.join(root, 'reference/luaparse/luaparse.js'));
const output = path.join(root, 'modules/FlAccess');
if (fs.existsSync(path.join(output,'reader_bootstrap.lua'))) {
  throw Error('Migration already performed. Edit maintained modules/FlAccess sources; do not regenerate over them.');
}
fs.mkdirSync(output, {recursive:true});
function transform(source) {
  const ast = lua.parse(source, {ranges:true, luaVersion:'5.1', encodingMode:'none'});
  const edits=[], bindings={}, names=new Map();
  const scope = (parent) => ({parent, values:new Map()});
  const outer=scope(null);
  function bind(s,n,shared=false) {
    let key=null;
    if(shared) { const count=names.get(n.name)||0; names.set(n.name,count+1); key=n.name+(count?'_'+count:''); bindings[key]=true; }
    s.values.set(n.name,key); return key;
  }
  function lookup(s,name) { for(;s;s=s.parent) if(s.values.has(name)) return s.values.get(name); return null; }
  function replace(n,s) {const key=lookup(s,n.name); if(key) edits.push([n.range[0],n.range[1],'shared.'+key]);}
  function body(nodes,s) { for(const n of nodes) visit(n,s); }
  function visit(n,s) {
    if(!n) return;
    switch(n.type) {
      case 'Identifier': replace(n,s); return;
      case 'LocalStatement': {
        n.init.forEach(x=>visit(x,s));
        const promoted=s===outer;
        if(promoted) {
          edits.push([n.range[0],n.variables[0].range[0],'']);
          if(!n.init.length) edits.push([n.range[1],n.range[1],' = '+n.variables.map(()=>'nil').join(',')]);
        }
        for(const v of n.variables) { bind(s,v,promoted); if(promoted) replace(v,s); }
        return;
      }
      case 'FunctionDeclaration': {
        if(n.isLocal) {
          bind(s,n.identifier,s===outer);
          if(s===outer) edits.push([n.range[0],n.identifier.range[0],'function ']);
          if(s===outer) replace(n.identifier,s);
        } else visit(n.identifier,s);
        const child=scope(s);
        if(n.identifier && n.identifier.type==='MemberExpression' && n.identifier.indexer===':') child.values.set('self',null);
        n.parameters.forEach(v=>{if(v.type==='Identifier')bind(child,v)});
        body(n.body,child); return;
      }
      case 'MemberExpression': visit(n.base,s); return;
      case 'TableKeyString': visit(n.value,s); return;
      case 'ForNumericStatement': {
        visit(n.start,s);visit(n.end,s);visit(n.step,s);
        const child=scope(s);bind(child,n.variable);body(n.body,child);return;
      }
      case 'ForGenericStatement': {
        n.iterators.forEach(x=>visit(x,s));const child=scope(s);
        n.variables.forEach(x=>bind(child,x));body(n.body,child);return;
      }
      case 'RepeatStatement': {const child=scope(s);body(n.body,child);visit(n.condition,child);return;}
      case 'WhileStatement': visit(n.condition,s);body(n.body,scope(s));return;
      case 'DoStatement': body(n.body,scope(s));return;
      case 'IfStatement': n.clauses.forEach(c=>{visit(c.condition,s);body(c.body,scope(s))});return;
      case 'ReturnStatement':
        if(s===outer) {edits.push([n.range[0],n.range[1],'']);return;}
        break;
      case 'LabelStatement': case 'GotoStatement': return;
    }
    for(const [key,value] of Object.entries(n)) {
      if(['range','loc','comments','globals'].includes(key))continue;
      if(Array.isArray(value)) value.forEach(x=>{if(x&&x.type)visit(x,s)});
      else if(value&&value.type) visit(value,s);
    }
  }
  body(ast.body,outer);
  edits.sort((a,b)=>b[0]-a[0]||b[1]-a[1]);
  for(const [start,end,text] of edits)source=source.slice(0,start)+text+source.slice(end);
  return {source,bindings:Object.keys(bindings)};
}
const readerNames=['bootstrap','memory_prism','text_intents','speech_queue','semantics','review','native_tree','native_windows','presentation','players','controls','observations','resolver','focus','frame','lifecycle'];
const marker='-- FLACCESS_COMPONENT_BOUNDARY\n';
function wrap(name,domain,index,source,finish='') {
  return `-- FLAccess 0.2.0. Native Sider component; maintained source.\nlocal component = {}\nfunction component.install(ctx)\n    assert(ctx.flaccess, "FLAccess core must load first")\n    local shared = ctx.flaccess.${domain}\n    assert(shared.stage == ${index}, "FLAccess ${domain}: missing or reordered component ${name}")\n${source}\n    shared.stage = ${index+1}\nend\nfunction component.init(ctx)\n    component.install(ctx)\n${finish}\nend\nreturn component\n`;
}
let reader=readerNames.map(name=>fs.readFileSync(path.join(root,'modules/FlAccessReader/engine',name+'.lua'),'utf8')).join(marker);
const converted=transform(reader);
const pieces=converted.source.split(marker);
if(pieces.length!==readerNames.length)throw Error('Reader component boundaries changed');
readerNames.forEach((name,i)=>fs.writeFileSync(path.join(output,'reader_'+name+'.lua'),wrap(name,'reader',i,pieces[i],i===15?'    ctx.flaccess.reader.m.init(ctx)':'')));
const radar=fs.readFileSync(path.join(root,'modules/FlAccessGameplay/engine/radar.lua'),'utf8');
const boundaries=[['state','function m.project'],['rules','local function blob'],['memory','local function mute'],['audio','local function reset_discovery'],['match','local function diagnostics'],['diagnostics','local function play_pose'],['render','function m.context_reset'],['lifecycle',null]];
let previous=0;
const radarPieces=boundaries.map(([name,next])=>{const at=next?radar.indexOf(next):radar.length;if(at<previous)throw Error('Gameplay boundary missing');const part=radar.slice(previous,at);previous=at;return part;});
const radarConverted=transform(radarPieces.join(marker));
radarConverted.source.split(marker).forEach((source,i)=>fs.writeFileSync(path.join(output,'gameplay_'+boundaries[i][0]+'.lua'),wrap(boundaries[i][0],'gameplay',i,source,i===7?'    ctx.flaccess.gameplay.m.init(ctx)':'')));
fs.writeFileSync(path.join(output,'migration-symbols.json'),JSON.stringify({reader:converted.bindings,gameplay:radarConverted.bindings},null,2)+'\n');
console.log('SPLIT_OK',readerNames.length,boundaries.length);
