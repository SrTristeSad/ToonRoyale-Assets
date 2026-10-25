// Exact packet R behavior using handlePacket from the copied original Node server.
import fs from "node:fs";
const path=new URL("../../server/src/network/packets.js",import.meta.url);
const source=fs.readFileSync(path,"utf8");
const first=source.indexOf("export function handlePacket(");
const last=source.indexOf("function handleAdmin(",first);
if(first<0||last<0) throw Error("Node packets.js markers changed");
const original=source.slice(first,last).trim().replace(/^export /,"");
const handle=new Function("isInt","REPORT_REASONS","return ("+original+")")(
 Number.isInteger,["Bot","Hack","Autoheal","Abuse"]);
const events=[];
const reporter={sid:1,role:null,reported:new Map(),
 anticheat:{invalid(name,why){events.push("invalid:"+name+":"+why)}}};
const nilTarget={sid:2,name:"Two",reports:0,ip:"127.0.0.1"};
const storedTarget={sid:3,name:"Three",reports:0,ip:"127.0.0.2",
 kick(reason){events.push("kick:"+reason)}};
let returnEntry=false;
const ctx={game:{players:[reporter,nilTarget,storedTarget]},
 moderation:{
   report(data){events.push("report:"+data.target.sid+":"+data.sessionReports);
     return returnEntry?{reason:null}:undefined},
   reportReason(data){events.push("reason:"+data.reason);
     data.entry.reason=data.reason},
   ban(data,by){events.push("ban:"+data.name);if(by!==reporter)throw Error("wrong reporter")}
 }};
function send(...args){handle(ctx,reporter,"R",args)}
send(2);send(2);send(2,0,1);
console.log("NIL_REPORT|"+nilTarget.reports+"|"+events.join(","));
events.length=0;returnEntry=true;
send(3);send(3);send(3,0,2);send(3,0,3);
console.log("STORED_REPORT|"+storedTarget.reports+"|"+events.join(","));
events.length=0;
send(3,2);
console.log("NO_ROLE|"+events.join(","));
events.length=0;reporter.role="mod";
send(3,2);
console.log("LOCAL_BAN|"+events.join(","));
events.length=0;
send(3,1);
console.log("LOCAL_SHADOW|"+storedTarget.shadowed+"|"+events.join(","));
