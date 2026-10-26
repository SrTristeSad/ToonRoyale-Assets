-- Android rendering budget: bound GPU work without modifying game physics.
-- The default LÖVE event loop and authoritative Node networking stay intact.
local P={}
P.__index=P
function P.fps(phase,focused)
  if focused==false then return 10 end
  if phase=="playing" then return 30 end
  return 20 -- Menus, loading screens and death overlays can be slower.
end
function P.new(timer)
  timer=timer or (love and love.timer)
  assert(timer and type(timer.getTime)=="function" and
    type(timer.sleep)=="function","LÖVE timer required")
  return setmetatable({clock=timer,lastFrame=nil},P)
end
function P:reset()
  self.lastFrame=nil
end
function P:pace(phase,focused)
  local fps=P.fps(phase,focused)
  local now=self.clock.getTime()
  if self.lastFrame then
    local elapsed=now-self.lastFrame
    if elapsed>=0 and elapsed<1 then
      local delay=1/fps-elapsed
      if delay>0.001 and delay<0.11 then
        self.clock.sleep(delay)
        now=self.clock.getTime()
      end
    end
  end
  self.lastFrame=now
  return fps
end
return P
