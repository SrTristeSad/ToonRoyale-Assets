package.path="./?.lua;./?/init.lua;"..package.path
local P=require("src.mobile.performance")
assert(P.fps("playing",true)==30)
assert(P.fps("menu",true)==20)
assert(P.fps("death",true)==20)
assert(P.fps("playing",false)==10)
local now,delays=0,{}
local clock={
  getTime=function() return now end,
  sleep=function(seconds)
    assert(seconds>=0 and seconds<.11)
    delays[#delays+1]=seconds
    now=now+seconds
  end
}
local limiter=P.new(clock)
assert(limiter:pace("playing",true)==30 and #delays==0)
now=0.01
limiter:pace("playing",true)
assert(math.abs(now-1/30)<.00001,"active game should pace to 30 fps")
now=now+0.001
limiter:pace("menu",true)
assert(math.abs(now-(1/30+1/20))<.00001,"menu should pace to 20 fps")
limiter:reset()
now=50
limiter:pace("playing",false)
assert(#delays==2,"reset must never stall after app resumes")
now=49 -- a backwards clock must not introduce a huge delay
limiter:pace("playing",true)
assert(#delays==2)
assert(P.new(clock):pace("playing",true)==30)
print("ANDROID PERFORMANCE PACE PASS: 30/20/10 fps, resume and clock safety")
