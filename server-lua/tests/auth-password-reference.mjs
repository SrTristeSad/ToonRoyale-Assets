// Run the auth/password handler AS WRITTEN in LOCAL Node api/routes.js.
import fs from "node:fs";
const src=fs.readFileSync(new URL("../../server/src/api/routes.js",import.meta.url),"utf8");
const at=src.indexOf('router.post("/auth/password"');
const end=src.indexOf('router.post("/auth/refresh"',at);
if(at<0||end<0)throw Error("original LOCAL auth/password source changed");
const router={post(path,fn){if(path==="/auth/password")this.handler=fn}};
const account={id:"local",email:"login@example.com"};
const store={accountForEmail(email){return email==="login@example.com"?account:null},
  issueToken(){return "test-token"}};
new Function("router","store","securePasswords",
  src.slice(at,end))(router,store,false);
if(!router.handler)throw Error("original local auth/password handler missing");
const samples=[["empty",""],["false",false],["zero",0],["null",null],
  ["empty-array",[]],["nonempty","x"],["one",1],["true",true],
  ["object",{}],["empty-email","x"]];
for(const [label,password] of samples){
 const email=label==="empty-email"?"":account.email;
 const req={body:{email,password}};
 const res={code:200,status(n){this.code=n;return this},
  json(value){this.body=value;return this}};
 await router.handler(req,res);
 console.log(label+"|"+res.code+"|"+
  (res.body.type||res.body.email||"")+"|"+
  (res.body.token||""));
}
