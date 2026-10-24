// Execute ORIGINAL Node AccountStore.issueToken/verifyToken, not an emulation.
import fs from "node:fs";
import {createHmac,timingSafeEqual} from "node:crypto";
const src=fs.readFileSync(new URL("../../server/src/api/store.js",import.meta.url),"utf8");
const classPos=src.indexOf("export class AccountStore");
const helperStart=src.indexOf("const b64url =");
const helperEnd=src.indexOf("function emptyStats()",helperStart);
if(classPos<0||helperStart<0||helperEnd<0)throw Error("Node source drift");
const {b64url,fromB64url}=new Function("Buffer",
 src.slice(helperStart,helperEnd)+"return {b64url,fromB64url}")(Buffer);
const Store=new Function("b64url","fromB64url","createHmac","timingSafeEqual",
 "return ("+src.slice(classPos).replace(/^export /,"").trim()+")")(
 b64url,fromB64url,createHmac,timingSafeEqual);
const account={id:"0123456789abcdef01234567",email:"user@example.com"};
const store=Object.create(Store.prototype);
store.secret=Buffer.alloc(32,75);
store.passwordMode=false;
store.data={accounts:{[account.id]:account},legacyIds:{}};
const originalNow=Date.now;
try {
 Date.now=()=>1792864800000;
 const token=store.issueToken(account,{ttlSeconds:3600});
 console.log("JWT|"+token);
 console.log("ACCEPT|"+(store.verifyToken(token)===account));
 console.log("REJECT_TAMPER|"+(store.verifyToken(token.slice(0,-1)+"*")===null));
 store.passwordMode=true;
 console.log("REJECT_INSECURE|"+(store.verifyToken(token)===null));
 const secure=store.issueToken(account,{ttlSeconds:3600});
 console.log("SECURE_JWT|"+secure);
 console.log("ACCEPT_SECURE|"+(store.verifyToken(secure)===account));
 const badTtl=()=>{try{store.issueToken(account,{ttlSeconds:59});return false}catch{return true}};
 console.log("REJECT_TTL|"+badTtl());
 Date.now=()=>1792868400001;
 console.log("EXPIRED|"+(store.verifyToken(secure)===null));
} finally {Date.now=originalNow}
