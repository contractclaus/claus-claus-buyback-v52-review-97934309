// Run from repository root: node build/verify-hashes.mjs
// Verifies content-addressed snapshot/artifact IDs. Compile the supplied
// standard inputs with solc0.8.26 separately to verify the runtime bytecodes.
import fs from 'node:fs';import assert from 'node:assert/strict';import {createHash} from 'node:crypto';
const canon=x=>Array.isArray(x)?'['+x.map(canon).join(',')+']':x!==null&&typeof x==='object'?'{'+Object.keys(x).sort().map(k=>JSON.stringify(k)+':'+canon(x[k])).join(',')+'}':JSON.stringify(x);
const digest=x=>'sha256:'+createHash('sha256').update(canon(x)).digest('hex');
const manifest=JSON.parse(fs.readFileSync('build/manifest.json','utf8'));
let snapshot;
for(const c of manifest.contracts){const artifact=JSON.parse(fs.readFileSync(c.artifact,'utf8')),input=JSON.parse(fs.readFileSync(c.standardInput,'utf8'));assert.equal(digest(artifact),c.artifactHash);assert.deepEqual(artifact.standardInput,input);const files=Object.entries(input.sources).map(([path,v])=>{assert.equal(fs.readFileSync(path,'utf8'),v.content);return {path,hash:digest({path,content:v.content})};}).sort((a,b)=>a.path.localeCompare(b.path,'en'));assert.equal(digest(files),manifest.sourceHash);if(snapshot)assert.deepEqual(files,snapshot);snapshot=files;}
console.log(JSON.stringify({verified:true,sourceHash:manifest.sourceHash,artifactHashes:manifest.contracts.map(c=>c.artifactHash)}));
