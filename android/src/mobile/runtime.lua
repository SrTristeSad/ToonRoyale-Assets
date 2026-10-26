-- Centralized platform guard: the Android client must never render or hit-test
-- the Windows/desktop HUD in addition to its dedicated touch HUD.
local Runtime={}
function Runtime.active()
  if os and os.getenv and os.getenv("MOO_IO_FORCE_ANDROID_E2E")=="1" then
    return true
  end
  if not (love and love.system and love.system.getOS) then return false end
  local ok,platform=pcall(love.system.getOS)
  return ok and platform=="Android"
end
return Runtime
