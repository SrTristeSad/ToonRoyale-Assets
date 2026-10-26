-- Safe, data-driven visual vocabulary for any JSON map or map mod.
-- Draw-only: collision and passage decisions are always server authoritative.
local Materials={}
local themes={
 wood={floor={0.54,0.40,0.27},wall={0.40,0.27,0.16},trim={0.74,0.55,0.34}},
 rock={floor={0.33,0.30,0.22},wall={0.32,0.30,0.26},trim={0.56,0.51,0.40}},
 metal={floor={0.16,0.255,0.31},wall={0.28,0.39,0.46},trim={0.55,0.67,0.72}},
 stone={floor={0.48,0.48,0.43},wall={0.36,0.38,0.36},trim={0.67,0.68,0.60}},
 sand={floor={0.65,0.55,0.37},wall={0.54,0.45,0.30},trim={0.81,0.72,0.49}},
 earth={floor={0.41,0.31,0.23},wall={0.34,0.26,0.19},trim={0.59,0.44,0.30}},
 grass={floor={0.34,0.50,0.27},wall={0.27,0.39,0.24},trim={0.58,0.69,0.40}},
 ice={floor={0.60,0.74,0.78},wall={0.37,0.58,0.68},trim={0.80,0.89,0.92}},
 brick={floor={0.52,0.33,0.29},wall={0.42,0.24,0.23},trim={0.70,0.47,0.40}}
}
Materials.themes=themes
function Materials.visual(area)
 local visual=area and area.visual or {}
 local default=area and area.type=="underground" and "rock" or "wood"
 return {floor=themes[visual.floor] and visual.floor or default,
  wall=themes[visual.wall] and visual.wall or
    (themes[visual.floor] and visual.floor or default),
  tileSize=type(visual.tileSize)=="number"
     and math.max(32,math.min(256,visual.tileSize)) or 128,
  name=type(visual.name)=="string" and visual.name or nil}
end
function Materials.portalStyle(area,portal)
 local style=portal and portal.style
 if style=="bunker" or style=="hatch" then return "hatch" end
 if style=="cave" or style=="tunnel" then return "tunnel" end
 if style=="stairs" then return "stairs" end
 if style=="arch" then return "arch" end
 if style=="house" or style=="door" then return "door" end
 local visual=Materials.visual(area)
 return visual.floor=="metal" and "hatch"
   or (visual.floor=="rock" and "tunnel" or "door")
end
return Materials
