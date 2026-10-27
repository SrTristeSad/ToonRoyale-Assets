package.path="./?.lua;./?/init.lua;"..package.path
local Mobile=require("src.mobile.controls")
local function near(a,b) return math.abs(a-b)<0.01 end
local w,h=1280,720
local m=Mobile.new()
local original=m:layout(w,h)
local seven=m:hotbar(7,w,h)
assert(#seven==7,"Never cap inventory at five")
local sixteen,bar=m:hotbar(16,w,h)
assert(#sixteen==16 and bar.maxScroll==0 and bar.rows>=2,
  "All unlocked items must be visible in the same adaptive tray")
assert(m.barCount==16)
sixteen,bar=m:hotbar(16,w,h)
local last=sixteen[16]
assert(last.x>bar.clipX and last.x<bar.clipX+bar.clipW)
assert(m:pressed(51,last.x,last.y,w,h,14400,16)=="bar_hold")
assert(m:moved(51,last.x+11,last.y,w,h)=="bar_hold",
  "Small touch wobble must not scroll or cancel an item tap")
local action,index=m:released(51)
assert(action=="slot" and index==16,
  "A finger tap must choose the actual unlocked slot index")
-- Real main.lua must forward BOTH values returned by released().
local fd=assert(io.open("main.lua","rb"))
local main=fd:read("*a");fd:close()
assert(main:find("local action,payload=mobile:released(id)",1,true)
  and main:find("mobileAction(action,payload)",1,true),
  "The main event loop must forward selected item index, not drop payload")
assert(m:pressed(52,last.x,last.y,w,h,14400,16)=="bar_hold")
local changed=m:moved(52,last.x+300,last.y,w,h)
assert(changed=="bar_hold","Long drags must not scroll or select anything")
assert(m:released(52)=="bar_release",
  "Dragging must never accidentally equip an item")
local unedited=m:layout(w,h)
m:startEditing()
local action2,selected=m:editorPressed(77,unedited.auto.x,unedited.auto.y,w,h)
assert(action2=="editor_drag" and selected=="auto")
assert(m:editorMoved(77,1000,420,w,h))
m:editorReleased(77)
local moved=m:layout(w,h)
assert(near(moved.auto.x,1000) and near(moved.auto.y,420),
  "Editor position must apply to real touch and render geometry")
m:finishEditing(true)
local saved=m:serializeEditor()
assert(saved:find("auto ",1,true),"Saved coordinates must include moved button")
local fresh=Mobile.new()
fresh:loadEditor(saved)
local persisted=fresh:layout(w,h)
assert(near(persisted.auto.x,1000) and near(persisted.auto.y,420),
  "Saved touch positions must survive an app restart")
fresh:startEditing()
fresh:editorPressed(78,persisted.auto.x,persisted.auto.y,w,h)
fresh:editorMoved(78,1100,500,w,h)
fresh:editorReleased(78)
fresh:finishEditing(false)
assert(near(fresh:layout(w,h).auto.x,1000),
  "Cancel must restore positions before editing")
fresh:startEditing()
fresh:resetEditor()
assert(near(fresh:layout(w,h).auto.x,original.auto.x))
fresh:finishEditing(true)
assert(fresh:serializeEditor()=="")
-- Editing relocates the adaptive tray without hiding any items.
fresh:startEditing()
local l=fresh:layout(w,h)
local e,group=fresh:editorPressed(90,l.hotbar.x,l.hotbar.y,w,h)
assert(e=="editor_drag" and group=="hotbar")
assert(fresh:editorMoved(90,w*.57,h*.78,w,h))
fresh:editorReleased(90)
fresh:finishEditing(true)
local newL=fresh:layout(w,h)
assert(near(newL.hotbar.x,w*.57),"Hotbar layout center must be editable")
local resized=fresh:layout(1600,900)
assert(near(resized.hotbar.x,1600*.57),
  "Normalized layout must work on different display sizes")
assert(#(fresh:hotbar(25,1600,900))==25,
  "Customization must preserve all 25 unlocked options")
print("ANDROID TOUCH EDITOR PASS: 25 visible icons, drag/save/cancel")
