// SPDX-License-Identifier: AGPL-3.0-only
// Live original AntiCheat from Node. Date.now mocked only inside fixture.
import fs from "node:fs";
import {AntiCheat,ANTICHEAT_CONFIG} from "../../server/src/anticheat/index.js";
const operations=fs.readFileSync(new URL("./anticheat-scenarios.txt",import.meta.url),"utf8")
  .split(/\r?\n/).filter(line=>line&&!line.startsWith("#"));
const realNow=Date.now;
let now=100000,anti,events,player,scenario;
function fmt(x){return Number(x).toFixed(6)}
function output(label){
 const sum=anti.summary();
 const buckets=Object.keys(anti.buckets).sort()
   .map(key=>key+":"+fmt(anti.buckets[key].tokens)).join(",");
 const result=[
  "AC",scenario,label,anti.closed?1:0,anti.strikes,
  fmt(anti.global.tokens),buckets,anti.flags,anti.flagged?1:0,
  player.flagged?1:0,player.skinIndex,player.shameTimer||0,
  sum.flagNames.join(","),sum.untrustedEvents,sum.probes.sent,
  sum.probes.answered,sum.probes.lastAnswer,anti.pending?anti.pending.salt:"~",
  anti.joinedAt,anti.nextProbeAt,events.join(";")
 ];
 console.log(result.join("|"));
}
try{
 for(const row of operations){
  const [record,a,b,c,d,e,f,g,h]=row.split("|");
  if(record==="case"){
   scenario=a;now=100000;events=[];
   player={id:"player",name:"Hero",ip:"1.2.3.4",did:"device",
    account:{id:"account"},flagged:false,skinIndex:0};
   const store={
    lock(ident,seconds){
     events.push("LOCK:"+[ident.ip,ident.did,ident.accountId,seconds].join(","));
    },
    flag(id,signal){events.push("FLAG:"+id+":"+signal)}
   };
   anti=new AntiCheat({
     player,store,session:{
       sealMode:1,sealReport:"original",pinned:true,lastSeq:5,ledgerBefore:100
     },
     log:entry=>events.push("LOG:"+entry),
     kick:reason=>events.push("KICK:"+reason),
     close:code=>events.push("CLOSE:"+code),
   });
   continue;
  }
  if(record!=="step")throw Error("unknown test command: "+row);
  now=Number(a);
  const original=Date.now;
  Date.now=()=>now;
  let label=b;
  try{
   switch(b){
    case "burst":{
     let yes=0,no=0;
     for(let i=0;i<Number(d);i++){
       if(anti.allow(c))yes++;else no++;
     }
     label="burst:"+c+":"+yes+":"+no;
     break;
    }
    case "allow":
     label="allow:"+c+":"+(anti.allow(c)?1:0);break;
    case "strike":
     anti.strike(Number(c),d);label="strike:"+c;break;
    case "invalid":
     anti.invalid(c,d);label="invalid:"+c;break;
    case "apply":
     anti.apply(c,d);label="apply:"+c;break;
    case "transport":
     anti.onTransportError(c,d||null);label="transport:"+c;break;
    case "joined":anti.onGameStart();break;
    case "pending":
     anti.sendProbes=()=>events.push("PROBE");
     anti.pending={salt:Number(c),rules:[],sentAt:now};anti.rounds=1;break;
    case "rounds":anti.rounds=Number(c);break;
    case "telemetry":{
     const arg=[Number(c),Number(d),Number(e),f,Number(g),Number(h),
       Number(row.split("|")[9])];
     anti.onTelemetry(arg);label="telemetry:"+c+":"+d;break;
    }
    case "tick":anti.tick(now);break;
    default:throw Error("unsupported test command "+b);
   }
   output(label);
  }finally{Date.now=original}
 }
}finally{Date.now=realNow}
