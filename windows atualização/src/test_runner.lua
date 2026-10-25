-- Self-contained LÖVE/LuaJIT client checks that exist in this Windows copy.
-- The former tests/*.lua suite is absent from this repository copy; never
-- report successful runs of missing tests or call a test loader as its result.
local Runner={}
Runner.cases={
  {"src.test_mooio_menu","Menu Lua sem botoes V2"},
  {"src.test_missing_asset_ui","HUD e assets do mundo"},
  {"src.test_sprite_render","Renderizacao de sprites"}
}
function Runner.run()
  local results={passed=0,failed=0,rows={}}
  for _,case in ipairs(Runner.cases) do
    local name,label=case[1],case[2]
    local ok,err=pcall(function()
      local perform=require(name)
      assert(type(perform)=="function","test module must return a function")
      perform()
    end)
    if ok then results.passed=results.passed+1
    else results.failed=results.failed+1 end
    results.rows[#results.rows+1]={path=name,pass=ok,
      error=ok and nil or tostring(err)}
    print((ok and "[PASS] " or "[FAIL] ")..label..
      (ok and "" or ": "..tostring(err)))
  end
  local summary=("Moo IO LÖVE client: %d passed; %d failed"):format(
    results.passed,results.failed)
  print(summary)
  local lines={summary}
  for _,row in ipairs(results.rows) do
    lines[#lines+1]=(row.pass and "PASS " or "FAIL ")..row.path..
      (row.error and ("\n"..row.error) or "")
  end
  local ok,why=love.filesystem.write("test-results.txt",
    table.concat(lines,"\n").."\n")
  if ok then results.reportPath=love.filesystem.getSaveDirectory().."/test-results.txt"
  else results.reportError=why end
  return results
end
return Runner
