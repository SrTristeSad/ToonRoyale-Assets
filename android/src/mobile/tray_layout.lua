-- All server-unlocked mobile actions stay visible simultaneously.
-- Adaptive centered rows respect the editable bar anchor and system safe area.
-- This module is pure geometry: no canvases or allocations during cached draws.
local T={}
local min,max,ceil,floor=math.min,math.max,math.ceil,math.floor

function T.layout(total,view,safe,u)
 total=max(0,floor(tonumber(total) or 0))
 local width=max(1,view.clipW)
 local availableHeight=max(42*u,min(safe.height*.43,
   view.y-safe.top-65*u))
 local bestRows,bestColumns,bestStep=1,max(1,total),0
 -- Choose the biggest comfortable touch target; fewer rows win ties.
 local maxRows=min(max(1,total),8)
 for rows=1,maxRows do
   local columns=max(1,ceil(total/rows))
   local step=min(83*u,(width-12*u)/columns,availableHeight/rows)
   if step>bestStep+0.01 then
     bestRows,bestColumns,bestStep=rows,columns,step
   end
 end
 local step=max(1,bestStep)
 local radius=step*.41
 local topY=view.y-(bestRows-1)*step
 local slots={}
 local minX=math.huge;local maxX=-math.huge
 for i=1,total do
   local row=floor((i-1)/bestColumns)
   local col=(i-1)%bestColumns
   local count=min(bestColumns,total-row*bestColumns)
   local x=view.clipX+width*.5+(col-(count-1)*.5)*step
   local y=topY+row*step
   slots[i]={x=x,y=y,r=radius,index=i}
   minX=min(minX,x-radius);maxX=max(maxX,x+radius)
 end
 local top=max(safe.top,topY-radius-8*u)
 local bottom=min(safe.bottom,view.y+radius*1.22+6*u)
 return slots,{
   clipX=view.clipX,clipW=width,top=top,bottom=bottom,
   rowU=step/90,rows=bestRows,columns=bestColumns,
   step=step,radius=radius,maxScroll=0,scroll=0,
   minX=minX,maxX=maxX,
 }
end
return T
