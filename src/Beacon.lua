local pos = vec3(construct.getWorldPosition())
local fwd = vec3(construct.getWorldOrientationForward())
local rgt = vec3(construct.getWorldOrientationRight())
local uup = vec3(construct.getWorldOrientationUp())
local function getWorld(localOffset)
    return vec3(pos + rgt * localOffset.x + fwd * localOffset.y + uup * localOffset.z)
end
local vOLS1 = getWorld(vec3(OLS1.getPosition()))
local vOLS2 = getWorld(vec3(OLS2.getPosition()))
local vOLS3 = getWorld(vec3(OLS3.getPosition()))
local json = string.format([[{"OLS1":[%f,%f,%f], "OLS2":[%f,%f,%f], "OLS3":[%f,%f,%f]}]],
  vOLS1.x,vOLS1.y,vOLS1.z,
  vOLS2.x,vOLS2.y,vOLS2.z,
  vOLS3.x,vOLS3.y,vOLS3.z
)
antenna.send(22554892,json)
unit.exit()