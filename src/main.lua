require('AR_Library:src/ARImport')

-- Pre-initialize inputs to avoid nil ops
pitchInput = 0
rollInput = 0
yawInput = 0
brakeInput = 0
local stallScaled = 0
local headingScaled = 0
local climbScaled = 0
local speedScaled = 0
local altScaled = 0
local throttleScaled = 0
local distKm = 0
local constructVelocity = {0,0,0}
local velocity = 0
local altM = 0
local atmo_eco = 0
local atmo_mass = 0
local atmo_s_remain = 0
local space_eco = 0
local space_mass = 0
local space_s_remain = 0
local tele_sysId, tele_bodyId, tele_lat, tele_lon, tele_alt = 0, nil, 0, 0, 0
local tele_name, tele_posStr = "",""
local enviro = true
local change_enviro = true
-- Fuel sampling state
local __prevFuelSampleT = nil
local __prevAtmoKg = nil
local __prevSpaceKg = nil
local __fuelAccumDt = 0
local __fuelAccumAtmoUsed = 0
local __fuelAccumSpaceUsed = 0
-- Realtime fuel display helpers
local __lastAtmoUseT = nil
local __lastSpaceUseT = nil
local __lastAtmoEcoKgMin = 0
local __lastSpaceEcoKgMin = 0
-- Fuel smoothing and zero display controls
local FUEL_SMOOTH_WINDOW_S = 2   -- seconds to average realtime rate
local FUEL_ZERO_DELAY_S    = 20  -- seconds idle before showing zero
local k = 0.5522847498307936
local sustenationSpeed = 474 --export The sustentation speed (in km/h) of the construct as stated in build mode.
local bingoFuel = 500 --export The mass of fuel (in kg) that would be deemed sufficient to return to base with.

Nav = Navigator.new(system, core, unit)
Nav.axisCommandManager:setupCustomTargetSpeedRanges(axisCommandId.longitudinal, {1000, 5000, 10000, 20000, 30000})

system.clearWaypoint(false)
if switch then switch.activate() end
unit.switchOnHeadlights()

-- Widgets and panels intentionally disabled
unit.hideWidget()
system.showHelper(false)
system.showScreen(true)
construct.setDockingMode(1)

-- Destination state (world position)
local atlas = require('atlas')
local __destPos = nil -- vec3 world

projector = Projector()
local objG1 = ObjectGroup()
projector.addObjectGroup(objG1)
local objectBuilder = ObjectBuilderLinear()
UIHud = objectBuilder
    .setPositionType(positionTypes.localP)
    .setOrientationType(orientationTypes.localO)
    .build()
UIMfdL = objectBuilder
    .setPositionType(positionTypes.localP)
    .setOrientationType(orientationTypes.localO)
    .build()
UIMfdR = objectBuilder
    .setPositionType(positionTypes.localP)
    .setOrientationType(orientationTypes.localO)
    .build()

local function rotateAroundAxis(v, axis, deg)
    local a = axis:normalize()
    local t = math.rad(deg)
    local c, s = math.cos(t), math.sin(t)
    return v * c + a:cross(v) * s + a * (a:dot(v)) * (1 - c)
end

local pos = vec3(unit.getPosition())
local fwd = vec3(construct.getOrientationForward()):normalize()
local uup = vec3(construct.getOrientationUp()):normalize()
local rgt = vec3(construct.getOrientationRight()):normalize()
--system.print(string.format("fwd: %.1f %.1f %.1f",fwd.x,fwd.y,fwd.z))
--system.print(string.format("up: %.1f %.1f %.1f",uup.x,uup.y,uup.z))
--system.print(string.format("right: %.1f %.1f %.1f",rgt.x,rgt.y,rgt.z))
local newRgt
local newFwd
local newUp
local inverse = -1
local zoom = 0
local offset = 0
local hudPos
local mfdLPos
local mfdRPos
if string.match(unit.getName(),"seat") then
    if string.match(unit.getName(),"command") then
        offset = -0.06
    end
    inverse = 1
    zoom = 0.65
    hudPos = pos + fwd * (0.3 + zoom) + uup * (0.57) + rgt * (offset)
    mfdLPos = pos + rgt * (-0.3+offset) + fwd * (zoom) + uup * (0.125)
    mfdRPos = pos + rgt * (0.3+offset) + fwd * (zoom) + uup * (0.125)
else
    hudPos = pos + fwd * (0.3 + zoom) + uup * (0.5) + rgt * (offset)
    mfdLPos = pos + rgt * (-0.3+offset) + fwd * (zoom) + uup * (0.125)
    mfdRPos = pos + rgt * (0.3+offset) + fwd * (zoom) + uup * (0.125)
    -- Roll the panels around forward axis instead of yaw
    --newUp = rotateAroundAxis(uup, fwd, -30)
    --newRgt = (fwd:cross(newUp)):normalize()
    --UIMfdL.rotateXYZ({newRgt.x,newRgt.y,newRgt.z}, {fwd.x,fwd.y,fwd.z}, {newUp.x,newUp.y,newUp.z})
    --UIMfdR.setPosition(mfdRPos.x, mfdRPos.y, mfdRPos.z)
    --newUp = rotateAroundAxis(uup, fwd, 30)
    --newRgt = (fwd:cross(newUp)):normalize()
    --UIMfdR.rotateXYZ({newRgt.x,newRgt.y,newRgt.z}, {fwd.x,fwd.y,fwd.z}, {newUp.x,newUp.y,newUp.z})
end
newFwd = rotateAroundAxis(fwd, uup, -30)
newRgt = (newFwd:cross(uup)):normalize()
UIMfdL.rotateXYZ({newRgt.x,newRgt.y,newRgt.z}, {newFwd.x,newFwd.y,newFwd.z}, {uup.x,uup.y,uup.z})
newFwd = rotateAroundAxis(fwd, uup, 30)
newRgt = (newFwd:cross(uup)):normalize()
UIMfdR.rotateXYZ({newRgt.x,newRgt.y,newRgt.z}, {newFwd.x,newFwd.y,newFwd.z}, {uup.x,uup.y,uup.z})

UIMfdL.setPosition(mfdLPos.x, mfdLPos.y, mfdLPos.z)
UIMfdR.setPosition(mfdRPos.x, mfdRPos.y, mfdRPos.z)

--local HudPosX, HudPosY, HudPosZ = pos.x, pos.y+(fwd*0.5), pos.z+(uup*(-0.3))
--local MfdLPosX, MfdLPosY, MfdLPosZ = pos.x+(rgt*(-0.3)), pos.y+(fwd*0.15), pos.z
--local MfdRPosX, MfdRPosY, MfdRPosZ = pos.x+(rgt*0.3), pos.y+(fwd*0.15), pos.z
UIHud.setPosition(hudPos.x, hudPos.y, hudPos.z)
UIHud.rotateXYZ({rgt.x,rgt.y,rgt.z}, {fwd.x * inverse,fwd.y * inverse,fwd.z * inverse}, {uup.x * inverse,uup.y * inverse,-uup.z * inverse})
--UIHud.rotateX(270)

--UIMfdL.rotateX(270)
--UIMfdL.rotateZ(30)

--UIMfdR.rotateX(270)
--UIMfdR.rotateZ(-30)

objG1.addObject(UIHud)
objG1.addObject(UIMfdL)
objG1.addObject(UIMfdR)
pHud = UIHud.setUIElements()
pMfdL = UIMfdL.setUIElements()
pMfdR = UIMfdR.setUIElements()

local cx, cy, w, h, x, y

cx, cy, w, h = 0, 0, 420, 240
x, y = cx - w/2, cy - h/2

--.setStroke('green', false)
--.setStrokeWidth(2, false)

local HudScreen = PathBuilder()
    .setFill('black', false)
    .setFillOpacity(0, false)
    .moveTo(x,y)
    .lineTo(x + w, y)
    .lineTo(x + w, y + h)
    .lineTo(x, y + h)
    .closePath()

cx, cy, w, h = 0, 0, 200, 100
x, y = cx - w/2, cy - h/2

local MfdLScreen = PathBuilder()
    .setFill('black', false)
    .setStroke('green', false)
    .setStrokeWidth(2, false)
    .setFillOpacity(1.0, false)
    .moveTo(x,y)
    .lineTo(x + w, y)
    .lineTo(x + w, y + h)
    .lineTo(x, y + h)
    .closePath()

local MfdRScreen = PathBuilder()
    .setFill('black', false)
    .setStroke('green', false)
    .setStrokeWidth(2, false)
    .setFillOpacity(1.0, false)
    .moveTo(x,y)
    .lineTo(x + w, y)
    .lineTo(x + w, y + h)
    .lineTo(x, y + h)
    .closePath()

local r = 60
StallOrbPath = PathBuilder()
    .setStroke('green', false)
    .setStrokeWidth(3, false)
    .setFillOpacity(.0, false)
    .moveTo(cx + r, cy)
    .cubicCurve(cx + r, cy + k*r, cx + k*r, cy + r, cx, cy + r)
    .cubicCurve(cx - k*r, cy + r, cx - r, cy + k*r, cx - r, cy)
    .cubicCurve(cx - r, cy - k*r, cx - k*r, cy - r, cx, cy - r)
    .cubicCurve(cx + k*r, cy - r, cx + r, cy - k*r, cx + r, cy)
    .closePath()

CenterObjPath = PathBuilder()
    .setStroke('green', false)
    .setStrokeWidth(3, false)
    .moveTo( 7, 7)
    .lineTo(-7,-7)
    .moveTo(-7, 7)
    .lineTo( 7,-7)

DestSpaceMarkerPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( 5, 5)
    .lineTo( 5,-5)
    .lineTo(-5,-5)
    .lineTo(-5, 5)
    .closePath()

AzimIndicatorPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( 0, 75)
    .lineTo(-5, 70)
    .lineTo( 5, 70)
    .closePath()


VeloIndicatorPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo(155,-60)
    .lineTo(150,-65)
    .lineTo(150,-55)
    .closePath()


AltIndicatorPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo(-155,-60)
    .lineTo(-150,-65)
    .lineTo(-150,-55)
    .closePath()

LadderLObjPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo(-160, 50)
    .lineTo(-160,-60)
    .lineTo(-170,-60)
    .closePath()

LadderRObjPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( 160, 50)
    .lineTo( 160,-60)
    .lineTo( 170,-60)
    .closePath()

ThrottleBarPath = PathBuilder()
    .setStroke('green', false)
    .setStrokeWidth(10, false)
    .moveTo( 175,-60)
    .lineTo( 175, 50)

TickerObjPath = PathBuilder()
    .setStroke('green', false)
    .setStrokeWidth(5, false)
    .moveTo(-130, 80)
    .lineTo( 130, 80)

CaptureBoxPath = PathBuilder()
    .setStroke('green', false)
    .setStrokeWidth(5, false)
    .setFillOpacity(0, false)
    .moveTo(-160, 80)
    .lineTo( 160, 80)
    .lineTo( 160, -70)
    .lineTo(-160, -70)
    .closePath()


hudMaster = pHud.createCustomDraw(0,0,0)
hudMaster.usePathBuilder(HudScreen)
hudMaster.setScale(1/600)
hudMaster.build()

MfdLMaster = pMfdL.createCustomDraw(0,0,0)
MfdLMaster.usePathBuilder(MfdLScreen)
MfdLMaster.setScale(1/600)
MfdLMaster.build()

MfdRMaster = pMfdR.createCustomDraw(0,0,0)
MfdRMaster.usePathBuilder(MfdRScreen)
MfdRMaster.setScale(1/600)
MfdRMaster.build()

StallOrb = pHud.createCustomDraw(0,0,0.0001)
StallOrb.usePathBuilder(StallOrbPath)
StallOrb.setPositionIsRelative(true)
StallOrb.setScale(1/600)
StallOrb.build()

CaptureBoxObj = pHud.createCustomDraw(0,0,0.0011)
CaptureBoxObj.usePathBuilder(CaptureBoxPath)
CaptureBoxObj.setPositionIsRelative(true)
CaptureBoxObj.setScale(1/600)
CaptureBoxObj.build()

DestSpaceMarkerObj = pHud.createCustomDraw(0,0,0.000132)
DestSpaceMarkerObj.usePathBuilder(DestSpaceMarkerPath)
DestSpaceMarkerObj.setPositionIsRelative(true)
DestSpaceMarkerObj.setScale(1/600)
DestSpaceMarkerObj.build()

DistIndicator = pHud.createText(0,0,0.000222)
DistIndicator.setPositionIsRelative(true)
DistIndicator.setFontColor('green')
DistIndicator.setFontSize(12)
DistIndicator.move(0, 95)
DistIndicator.setAlignmentX('middle')
DistIndicator.setAlignmentY('middle')
DistIndicator.setText('555')
DistIndicator.setWeight(0.002)
DistIndicator.setScale(1/600)

VeloLabel = pHud.createText(0,0,0.0003)
VeloLabel.setPositionIsRelative(true)
VeloLabel.setFontColor('green')
VeloLabel.setFontSize(6)
VeloLabel.move(160, -70)
VeloLabel.setAlignmentX('middle')
VeloLabel.setAlignmentY('middle')
VeloLabel.setText('Speed')
VeloLabel.setWeight(0.002)
VeloLabel.setScale(1/600)

AltLabel = pHud.createText(0,0,0.0004)
AltLabel.setPositionIsRelative(true)
AltLabel.setFontColor('green')
AltLabel.setFontSize(6)
AltLabel.move(-160, -70)
AltLabel.setAlignmentX('middle')
AltLabel.setAlignmentY('middle')
AltLabel.setText('Altitude')
AltLabel.setWeight(0.002)
AltLabel.setScale(1/600)

CenterObj = pHud.createCustomDraw(0,0,0.0005)
CenterObj.usePathBuilder(CenterObjPath)
CenterObj.setPositionIsRelative(true)
CenterObj.setScale(1/600)
CenterObj.build()

AltIndicator = pHud.createCustomDraw(0,0,0.0006)
AltIndicator.usePathBuilder(AltIndicatorPath)
AltIndicator.setPositionIsRelative(true)
AltIndicator.setScale(1/600)
AltIndicator.build()

VeloIndicator = pHud.createCustomDraw(0,0,0.0007)
VeloIndicator.usePathBuilder(VeloIndicatorPath)
VeloIndicator.setPositionIsRelative(true)
VeloIndicator.setScale(1/600)
VeloIndicator.build()

AzimIndicator = pHud.createCustomDraw(0,0,0.0008)
AzimIndicator.usePathBuilder(AzimIndicatorPath)
AzimIndicator.setPositionIsRelative(true)
AzimIndicator.setScale(1/600)
AzimIndicator.build()

LadderLObj = pHud.createCustomDraw(0,0,0.0009)
LadderLObj.usePathBuilder(LadderLObjPath)
LadderLObj.setPositionIsRelative(true)
LadderLObj.setScale(1/600)
LadderLObj.build()

LadderRObj = pHud.createCustomDraw(0,0,0.001)
LadderRObj.usePathBuilder(LadderRObjPath)
LadderRObj.setPositionIsRelative(true)
LadderRObj.setScale(1/600)
LadderRObj.build()

TickerObj = pHud.createCustomDraw(0,0,0.00011)
TickerObj.usePathBuilder(TickerObjPath)
TickerObj.setPositionIsRelative(true)
TickerObj.setScale(1/600)
TickerObj.build()

ThrottleBar = pHud.createCustomDraw(0,0,0.00012)
ThrottleBar.usePathBuilder(ThrottleBarPath)
ThrottleBar.setPositionIsRelative(true)
ThrottleBar.setScale(1/600)
ThrottleBar.build()

AnnounceFuelAtmoPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( -98, 48)
    .lineTo( -2,48)
    .lineTo( -2,33)
    .lineTo( -98,33)
    .closePath()

AnnounceFuelSpacePath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( 2, 48)
    .lineTo( 98,48)
    .lineTo( 98,33)
    .lineTo( 2,33)
    .closePath()

FuelGaugeObj = pMfdR.createText(0,0,0.0001)
FuelGaugeObj.setPositionIsRelative(true)
FuelGaugeObj.setFontColor('green')
FuelGaugeObj.setFontSize(6)
FuelGaugeObj.move(-90, 25)
FuelGaugeObj.setAlignmentX('start')
FuelGaugeObj.setAlignmentY('middle')
FuelGaugeObj.setText('Atmo Fuel')
FuelGaugeObj.setWeight(0.002)
FuelGaugeObj.setScale(1/600)

DestArrivalTeleObj = pMfdR.createText(0,0,0.00021)
DestArrivalTeleObj.setPositionIsRelative(true)
DestArrivalTeleObj.setFontColor('green')
DestArrivalTeleObj.setFontSize(6)
DestArrivalTeleObj.move(-90, 5)
DestArrivalTeleObj.setAlignmentX('start')
DestArrivalTeleObj.setAlignmentY('middle')
DestArrivalTeleObj.setText('Space Fuel')
DestArrivalTeleObj.setWeight(0.002)
DestArrivalTeleObj.setScale(1/600)

AnnounceFuelAtmoObj = pMfdR.createCustomDraw(0,0,0.0003)
AnnounceFuelAtmoObj.usePathBuilder(AnnounceFuelAtmoPath)
AnnounceFuelAtmoObj.setPositionIsRelative(true)
AnnounceFuelAtmoObj.setScale(1/600)
AnnounceFuelAtmoObj.build()

AnnounceFuelSpaceObj = pMfdR.createCustomDraw(0,0,0.0004)
AnnounceFuelSpaceObj.usePathBuilder(AnnounceFuelSpacePath)
AnnounceFuelSpaceObj.setPositionIsRelative(true)
AnnounceFuelSpaceObj.setScale(1/600)
AnnounceFuelSpaceObj.build()

AnnounceFuelAtmoText = pMfdR.createText(0,0,0.0005)
AnnounceFuelAtmoText.setPositionIsRelative(true)
AnnounceFuelAtmoText.setFontColor('black')
AnnounceFuelAtmoText.setFontSize(6)
AnnounceFuelAtmoText.move(-50, 40)
AnnounceFuelAtmoText.setAlignmentX('middle')
AnnounceFuelAtmoText.setAlignmentY('middle')
AnnounceFuelAtmoText.setText('Atmo Fuel')
AnnounceFuelAtmoText.setWeight(0.002)
AnnounceFuelAtmoText.setScale(1/600)

AnnounceFuelSpaceText = pMfdR.createText(0,0,0.0006)
AnnounceFuelSpaceText.setPositionIsRelative(true)
AnnounceFuelSpaceText.setFontColor('black')
AnnounceFuelSpaceText.setFontSize(6)
AnnounceFuelSpaceText.move(50, 40)
AnnounceFuelSpaceText.setAlignmentX('middle')
AnnounceFuelSpaceText.setAlignmentY('middle')
AnnounceFuelSpaceText.setText('Space Fuel')
AnnounceFuelSpaceText.setWeight(0.002)
AnnounceFuelSpaceText.setScale(1/600)


AnnounceLoAltiPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( -98, 48)
    .lineTo( -2,48)
    .lineTo( -2,33)
    .lineTo( -98,33)
    .closePath()

AnnounceLoSpeedPath = PathBuilder()
    .setFill('green', false)
    .setFillOpacity(1, false)
    .moveTo( 2, 48)
    .lineTo( 98,48)
    .lineTo( 98,33)
    .lineTo( 2,33)
    .closePath()

TelemetryDestNameObj = pMfdL.createText(0,0,0.0001)
TelemetryDestNameObj.setPositionIsRelative(true)
TelemetryDestNameObj.setFontColor('green')
TelemetryDestNameObj.setFontSize(6)
TelemetryDestNameObj.move(-90, 25)
TelemetryDestNameObj.setAlignmentX('start')
TelemetryDestNameObj.setAlignmentY('middle')
TelemetryDestNameObj.setText('Dest Name')
TelemetryDestNameObj.setWeight(0.002)
TelemetryDestNameObj.setScale(1/600)

TelemetryDestInfoObj = pMfdL.createText(0,0,0.00022)
TelemetryDestInfoObj.setPositionIsRelative(true)
TelemetryDestInfoObj.setFontColor('green')
TelemetryDestInfoObj.setFontSize(6)
TelemetryDestInfoObj.move(-90, 15)
TelemetryDestInfoObj.setAlignmentX('start')
TelemetryDestInfoObj.setAlignmentY('middle')
TelemetryDestInfoObj.setText('Dest Info')
TelemetryDestInfoObj.setWeight(0.002)
TelemetryDestInfoObj.setScale(1/600)

TelemetryBrakeDistObj = pMfdL.createText(0,0,0.00025)
TelemetryBrakeDistObj.setPositionIsRelative(true)
TelemetryBrakeDistObj.setFontColor('green')
TelemetryBrakeDistObj.setFontSize(6)
TelemetryBrakeDistObj.move(-90, -5)
TelemetryBrakeDistObj.setAlignmentX('start')
TelemetryBrakeDistObj.setAlignmentY('middle')
TelemetryBrakeDistObj.setText('Brake Info')
TelemetryBrakeDistObj.setWeight(0.002)
TelemetryBrakeDistObj.setScale(1/600)

AnnounceLoAltiObj = pMfdL.createCustomDraw(0,0,0.0003)
AnnounceLoAltiObj.usePathBuilder(AnnounceLoAltiPath)
AnnounceLoAltiObj.setPositionIsRelative(true)
AnnounceLoAltiObj.setScale(1/600)
AnnounceLoAltiObj.build()

AnnounceLoSpeedObj = pMfdL.createCustomDraw(0,0,0.0004)
AnnounceLoSpeedObj.usePathBuilder(AnnounceLoSpeedPath)
AnnounceLoSpeedObj.setPositionIsRelative(true)
AnnounceLoSpeedObj.setScale(1/600)
AnnounceLoSpeedObj.build()

AnnounceLoSpeedText = pMfdL.createText(0,0,0.0005)
AnnounceLoSpeedText.setPositionIsRelative(true)
AnnounceLoSpeedText.setFontColor('black')
AnnounceLoSpeedText.setFontSize(6)
AnnounceLoSpeedText.move(50, 40)
AnnounceLoSpeedText.setAlignmentX('middle')
AnnounceLoSpeedText.setAlignmentY('middle')
AnnounceLoSpeedText.setText('Speed')
AnnounceLoSpeedText.setWeight(0.002)
AnnounceLoSpeedText.setScale(1/600)

AnnounceLoAltiText = pMfdL.createText(0,0,0.0006)
AnnounceLoAltiText.setPositionIsRelative(true)
AnnounceLoAltiText.setFontColor('black')
AnnounceLoAltiText.setFontSize(6)
AnnounceLoAltiText.move(-50, 40)
AnnounceLoAltiText.setAlignmentX('middle')
AnnounceLoAltiText.setAlignmentY('middle')
AnnounceLoAltiText.setText('Altitude')
AnnounceLoAltiText.setWeight(0.002)
AnnounceLoAltiText.setScale(1/600)



local function applyPath(el, pb)
    local drawStr, data, flat = pb.getResult()
    local px, py = {}, {}
    for i=1, #flat, 2 do px[#px+1]=flat[i]; py[#py+1]=flat[i+1] end
    el.setPoints(px, py) -- replace, not append
    el.setDrawData(data)
    el.setDefaultDraw(drawStr) -- triggers redraw
end


local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

-- Returns total fuel mass (kg) in atmospheric and space tanks without links
local function getFuelMassTotals()
    local atmoKg, spaceKg = 0, 0
    local ids = core.getElementIdList() or {}
    for _, id in ipairs(ids) do
        local element = core.getElementItemIdById(id)
        local item = system.getItem(element)
        if item.name:find("FuelTank", 1, true) then
            local dry = tonumber(item.unitMass) or 0 -- kg (dry mass of element)
            local cur = tonumber(core.getElementMassById(id)) or 0 -- kg (current mass incl. fuel)
            local fuel = math.max(0, cur - dry)
            if item.name:find("Atmo", 1, true) then
                atmoKg = atmoKg + fuel
            elseif item.name:find("Space", 1, true) then
                spaceKg = spaceKg + fuel
            end
        end
    end
    return atmoKg, spaceKg
end

local function latLonAltToWorld(center, radius, latDeg, lonDeg, altM)
    local lat = math.rad(latDeg or 0)
    local lon = math.rad(lonDeg or 0)
    local rad = (radius or 0) + (altM or 0)
    local x = rad * math.cos(lat) * math.cos(lon)
    local y = rad * math.cos(lat) * math.sin(lon)
    local z = rad * math.sin(lat)
    return vec3((center[1] or 0) + x, (center[2] or 0) + y, (center[3] or 0) + z)
end

local function getBodyCenter(systemId, bodyId)
    local sys = atlas[systemId]
    if not sys then return nil end

    -- Treat bodyId 0 as a valid "space" position around the system barycenter.
    -- Use world origin with zero radius so lat/lon/alt compute to a point in space.
    if bodyId == 0 then
        return {0, 0, 0}, 0
    end

    local body = sys[bodyId]
    if not body then return nil end
    local c = body.center
    local r = body.radius or 0
    return c, r
end

-- Convert a ::pos triple to world coordinates.
-- For bodyId == 0, interpret the triple as world X/Y/Z (space coords).
-- For other bodies, interpret as lat/lon/alt on the given body.
local function posToWorld(systemId, bodyId, a, b, c)
    if bodyId == 0 then
        return vec3(a or 0, b or 0, c or 0)
    end
    local center, radius = getBodyCenter(systemId, bodyId)
    if center and radius then
        return latLonAltToWorld(center, radius, a, b, c)
    end
    return nil
end

local function v3sub(a, b)
    return vec3((a.x or a[1] or 0) - (b.x or b[1] or 0), (a.y or a[2] or 0) - (b.y or b[2] or 0), (a.z or a[3] or 0) - (b.z or b[3] or 0))
end

-- Find the nearest body's display name within a system to a world position
local function getNearestBodyName(systemId, worldPos)
    local sys = atlas[systemId]
    if not sys or not worldPos then return nil end
    local bestName, bestD2 = nil, nil
    for id, body in pairs(sys) do
        local c = body and body.center
        local n = body and body.name and body.name[1]
        if c and n then
            local d = v3sub(worldPos, c)
            local d2 = d:dot(d)
            if not bestD2 or d2 < bestD2 then
                bestD2 = d2
                bestName = n
            end
        end
    end
    return bestName
end


local function updateHud()
    local prev_enviro = enviro 
    enviro = ((unit.getAtmosphereDensity() or 0) > 0)
    if prev_enviro ~= enviro then change_enviro = true end
    if distKm == 0 then DistIndicator.setText('555')
    elseif distKm > 200 then DistIndicator.setText(string.format("%.0f su",math.ceil(distKm / 200)))
    else DistIndicator.setText(string.format("%.0f",distKm)) end
    AzimIndicator.move(headingScaled, 0, nil, true)
    VeloIndicator.move(0, speedScaled, nil, true)
    if __destPos and not enviro then
        local eye    = vec3(construct.getWorldPosition())
        local toDest = v3sub(__destPos, eye)

        local forward = vec3(construct.getWorldForward())
        local right   = vec3(construct.getWorldRight())
        local up      = vec3(construct.getWorldUp())

        -- Component of destination along forward (used as atan2 x)
        local fx = toDest:dot(forward)
        if fx <= 0 then
            DestSpaceMarkerObj.hideDraw()   -- destination is behind the camera
        else
            -- Compute the marker capture window from the actual HUD box geometry.
            -- CaptureBoxPath spans x:-160..160 and y:-70..80, scaled by 1/600 on pHud.
            local scale = 1/600
            local halfWidthM      = 160 * scale
            local halfHeightUpM   =  80 * scale
            local halfHeightDownM =  70 * scale

            -- Panel distance is the forward offset used when building hudPos: (0.3 + zoom)
            -- Using that constant avoids drift from world-movement since hudPos is initialized once.
            -- Empirical factor: visual angular size of the HUD box is about
            -- half of the naive tan(width/distance) using the forward offset only,
            -- so use a 2x distance factor to match on‑screen box.
            local dPanel = 4.0 * (0.3 + (zoom or 0))
            if dPanel < 1e-3 or dPanel ~= dPanel then dPanel = 1.0 end -- guard against degenerate/NaN

            -- Angular errors using atan2-style
            local yawErrDeg   = math.deg(math.atan(math.abs(toDest:dot(right)),  fx))
            local pitchDeg    = math.deg(math.atan(        toDest:dot(up),      fx)) -- signed up(+)/down(-)

            -- Max allowed angles subtended by the box at the HUD distance
            local maxYawDeg        = math.deg(math.atan(halfWidthM,      dPanel))
            local maxPitchUpDeg    = math.deg(math.atan(halfHeightUpM,   dPanel))
            local maxPitchDownDeg  = math.deg(math.atan(halfHeightDownM, dPanel))
            
            --DistIndicator.setText(string.format("%.0f : %.0f : %.0f : %.0f : %.0f",yawErrDeg,maxYawDeg,pitchDeg,maxPitchUpDeg,maxPitchDownDeg))
            if (yawErrDeg <= maxYawDeg) and (pitchDeg <= maxPitchUpDeg) and (pitchDeg >= -maxPitchDownDeg) then
                -- Project destination onto HUD plane at distance dPanel and map to HUD units
                local t = dPanel / fx
                local mx = (toDest:dot(right) * t) / scale
                local my = (toDest:dot(up)    * t) / scale
                -- Clamp to the capture box extents
                if mx >  160 then mx =  160 end
                if mx < -160 then mx = -160 end
                if my >   80 then my =   80 end
                if my <  -70 then my =  -70 end
                DestSpaceMarkerObj.move(mx, my, nil, true)
                DestSpaceMarkerObj.showDraw()
            else
                DestSpaceMarkerObj.hideDraw()
            end
        end
    else
        DestSpaceMarkerObj.hideDraw()
    end



    if enviro then AltIndicator.move(0, altScaled, nil, true) else AltIndicator.move(0, climbScaled, nil, true) end

    -- Update fuel eco (kg/min) in realtime; only display zero after 20s with no consumption
    local now = system.getArkTime()
    local atmoKg, spaceKg = getFuelMassTotals()
    -- Always show current mass
    atmo_mass = math.floor((atmoKg or 0) + 0.5)
    space_mass = math.floor((spaceKg or 0) + 0.5)

    if not __prevFuelSampleT then
        __prevFuelSampleT = now
        __prevAtmoKg = atmoKg
        __prevSpaceKg = spaceKg
        __lastAtmoUseT = now
        __lastSpaceUseT = now
    else
        local dt = now - __prevFuelSampleT
        if dt > 0 then
            local usedAtmo = math.max(0, (__prevAtmoKg or atmoKg) - (atmoKg or 0))
            local usedSpace = math.max(0, (__prevSpaceKg or spaceKg) - (spaceKg or 0))

            if usedAtmo > 0 then __lastAtmoUseT = now end
            if usedSpace > 0 then __lastSpaceUseT = now end

            __fuelAccumAtmoUsed = __fuelAccumAtmoUsed + usedAtmo
            __fuelAccumSpaceUsed = __fuelAccumSpaceUsed + usedSpace
            __fuelAccumDt = __fuelAccumDt + dt

            -- Update outputs only when a full smoothing window has elapsed
            if __fuelAccumDt >= FUEL_SMOOTH_WINDOW_S then
                local atmoKgPerMin = (__fuelAccumDt > 0) and ((__fuelAccumAtmoUsed / __fuelAccumDt) * 60) or 0
                local spaceKgPerMin = (__fuelAccumDt > 0) and ((__fuelAccumSpaceUsed / __fuelAccumDt) * 60) or 0

                if atmoKgPerMin > 0 then __lastAtmoEcoKgMin = atmoKgPerMin end
                if spaceKgPerMin > 0 then __lastSpaceEcoKgMin = spaceKgPerMin end

                -- Only show zero if no fuel consumed for >= FUEL_ZERO_DELAY_S
                if __lastAtmoUseT and (now - __lastAtmoUseT) >= FUEL_ZERO_DELAY_S then
                    atmo_eco = 0
                    atmo_s_remain = 0
                else
                    local effAtmoKgPerMin = (atmoKgPerMin > 0) and atmoKgPerMin or __lastAtmoEcoKgMin
                    if effAtmoKgPerMin > 0 then
                        atmo_eco = math.floor(effAtmoKgPerMin + 0.5)
                        local atmoKgPerSec = effAtmoKgPerMin / 60
                        atmo_s_remain = math.floor((atmoKg or 0) / atmoKgPerSec + 0.5)
                    else
                        atmo_eco = 0
                        atmo_s_remain = 0
                    end
                end

                if __lastSpaceUseT and (now - __lastSpaceUseT) >= FUEL_ZERO_DELAY_S then
                    space_eco = 0
                    space_s_remain = 0
                else
                    local effSpaceKgPerMin = (spaceKgPerMin > 0) and spaceKgPerMin or __lastSpaceEcoKgMin
                    if effSpaceKgPerMin > 0 then
                        space_eco = math.floor(effSpaceKgPerMin + 0.5)
                        local spaceKgPerSec = effSpaceKgPerMin / 60
                        space_s_remain = math.floor((spaceKg or 0) / spaceKgPerSec + 0.5)
                    else
                        space_eco = 0
                        space_s_remain = 0
                    end
                end

                -- Reset accumulation for the next window
                __fuelAccumAtmoUsed = 0
                __fuelAccumSpaceUsed = 0
                __fuelAccumDt = 0
            end

            __prevAtmoKg = atmoKg
            __prevSpaceKg = spaceKg
            __prevFuelSampleT = now
        end
    end

    local atmo_hours = math.floor(atmo_s_remain / 3600  + 0.5)
    local atmo_minutes = math.floor((atmo_s_remain % 3600) / 60  + 0.5)
    local atmo_seconds = math.floor(atmo_s_remain % 60 + 0.5)
    
    local space_hours = math.floor(space_s_remain / 3600  + 0.5)
    local space_minutes = math.floor((space_s_remain % 3600) / 60  + 0.5)
    local space_seconds = math.floor(space_s_remain % 60 + 0.5)

    if enviro then
        if atmo_hours > 0 then
            FuelGaugeObj.setText(string.format("Fuel: %01d h - %01d kg - %01d kg/min",atmo_hours,atmo_mass,atmo_eco))
        elseif atmo_minutes > 0 then
            FuelGaugeObj.setText(string.format("Fuel: %01d m - %01d kg - %01d kg/min",atmo_minutes,atmo_mass,atmo_eco))
        else
            FuelGaugeObj.setText(string.format("Fuel: %01d s - %01d kg - %01d kg/min",atmo_seconds,atmo_mass,atmo_eco))
        end
    else
        if space_hours > 0 then
            FuelGaugeObj.setText(string.format("Fuel: %01d h - %01d kg - %01d kg/min",space_hours,space_mass,space_eco))
        elseif space_minutes > 0 then
            FuelGaugeObj.setText(string.format("Fuel: %01d m - %01d kg - %01d kg/min",space_minutes,space_mass,space_eco))
        else
            FuelGaugeObj.setText(string.format("Fuel: %01d s - %01d kg - %01d kg/min",space_seconds,space_mass,space_eco))
        end
    end

    
    if atmo_mass > bingoFuel then AnnounceFuelAtmoPath.setFill('green', false) else AnnounceFuelAtmoPath.setFill('red', false) end
    if space_mass > bingoFuel then AnnounceFuelSpacePath.setFill('green', false) else AnnounceFuelSpacePath.setFill('red', false) end


    applyPath(AnnounceFuelAtmoObj, AnnounceFuelAtmoPath)
    applyPath(AnnounceFuelSpaceObj, AnnounceFuelSpacePath)


    if tele_name and tele_name ~= "" then
        TelemetryDestNameObj.setText(tostring(tele_name))
    else
        TelemetryDestNameObj.setText("No Destination")
    end
    
    local timetotarget = math.floor((distKm*1000) / velocity  + 0.5)
    local bodyTbl = (atlas[tele_sysId] or {})[tele_bodyId]
    if tele_bodyId == 0 and atlas[tele_sysId] then
        local nearest = getNearestBodyName(tele_sysId, __destPos)
        if nearest then
            TelemetryDestInfoObj.setText(string.format("Space - %s AOI", nearest))
        else
            TelemetryDestInfoObj.setText("Space")
        end
    elseif bodyTbl and bodyTbl.name and bodyTbl.name[1]
        and type(tele_lat) == 'number' and type(tele_lon) == 'number' and type(tele_alt) == 'number' then
        TelemetryDestInfoObj.setText(string.format("%s - %.02f/%.02f - %.0f alt", bodyTbl.name[1], tele_lat, tele_lon, tele_alt))
    else
        TelemetryDestInfoObj.setText("--------")
        DestArrivalTeleObj.setText("--------")
    end
    
    if timetotarget > 3600 then
        DestArrivalTeleObj.setText(string.format("Time to Target: %.0f h",math.floor(timetotarget / 3600  + 0.5)))
    elseif timetotarget > 60 then
        DestArrivalTeleObj.setText(string.format("Time to Target: %.0f m",math.floor(timetotarget / 60  + 0.5)))
    else
        DestArrivalTeleObj.setText(string.format("Time to Target: %.0f s",timetotarget))
    end
    
    if altM > 500 then AnnounceLoAltiPath.setFill('green', false) else AnnounceLoAltiPath.setFill('red', false) end
    if ((velocity > sustenationSpeed/2) and enviro) or ((unit.getAtmosphereDensity() or 0) <= 0) then AnnounceLoSpeedPath.setFill('green', false) else AnnounceLoSpeedPath.setFill('red', false) end

    applyPath(AnnounceLoAltiObj, AnnounceLoAltiPath)
    applyPath(AnnounceLoSpeedObj, AnnounceLoSpeedPath)


    local function nz(x) return (x ~= nil) and x or 0 end
    local function finite(x) return x == x and x ~= math.huge and x ~= -math.huge end

    local force = construct.getCurrentBrake()
    if force == nil or force <= 0 then force = construct.getMaxBrake() or 0 end

    local vx, vy, vz = nz(constructVelocity and constructVelocity.x),
                    nz(constructVelocity and constructVelocity.y),
                    nz(constructVelocity and constructVelocity.z)

    local s2 = vx*vx + vy*vy + vz*vz
    local speed = (s2 >= 0 and finite(s2)) and math.sqrt(s2) or 0

    local mass = construct.getTotalMass() or 0

    if not (force > 0 and mass > 0 and finite(speed)) then
        TelemetryBrakeDistObj.setText("Brake in: __ s / __ m")
    else
        if speed < 1e-3 then
            TelemetryBrakeDistObj.setText("Brake in: 0 s / 0 m")
        else
            local brakedist = math.floor(mass * speed * speed) / (2 * force)
            local braketime = math.floor(((mass * speed) / force) + 0.5)
            if brakedist < 999 then
                TelemetryBrakeDistObj.setText(string.format("Brake in: %.0f s / %.0f m", math.min(braketime,999), math.min(brakedist,999)))
            elseif brakedist < 199999 then
                brakedist = brakedist / 1000
                TelemetryBrakeDistObj.setText(string.format("Brake in: %.0f s / %.0f km", math.min(braketime,999), math.min(brakedist,999)))
            else
                brakedist = brakedist / 200000
                TelemetryBrakeDistObj.setText(string.format("Brake in: %.0f s / %.0f su", math.min(braketime,999), math.min(brakedist,999)))
            end
        end
    end





    local r = stallScaled
    StallOrbPath = PathBuilder()
        .setStroke('green', false)
        .setStrokeWidth(3, false)
        .setFillOpacity(.0, false)
        .moveTo(cx + r, cy)
        .cubicCurve(cx + r, cy + k*r, cx + k*r, cy + r, cx, cy + r)
        .cubicCurve(cx - k*r, cy + r, cx - r, cy + k*r, cx - r, cy)
        .cubicCurve(cx - r, cy - k*r, cx - k*r, cy - r, cx, cy - r)
        .cubicCurve(cx + k*r, cy - r, cx + r, cy - k*r, cx + r, cy)
        .closePath()

    throttleScaled = -55 + (clamp(unit.getThrottle(),0,100) / 100) * 100
    
    ThrottleBarPath = PathBuilder()
        .setStroke('green', false)
        .setStrokeWidth(10, false)
        .moveTo( 175,-60)
        .lineTo( 175, throttleScaled)
    
    applyPath(StallOrb, StallOrbPath)
    applyPath(ThrottleBar, ThrottleBarPath)

    if change_enviro then
        if enviro then
            CaptureBoxObj.hideDraw()
            DistIndicator.showDraw()
            VeloLabel.showDraw()
            AltLabel.showDraw()
            CenterObj.showDraw()
            AltIndicator.showDraw()
            VeloIndicator.showDraw()
            AzimIndicator.showDraw()
            LadderLObj.showDraw()
            LadderRObj.showDraw()
            TickerObj.showDraw()
            ThrottleBar.showDraw()
            StallOrb.showDraw()
        else
            CaptureBoxObj.showDraw()
            DistIndicator.showDraw()
            VeloLabel.hideDraw()
            AltLabel.hideDraw()
            CenterObj.showDraw()
            AltIndicator.showDraw()
            VeloIndicator.hideDraw()
            AzimIndicator.showDraw()
            LadderLObj.hideDraw()
            LadderRObj.hideDraw()
            TickerObj.hideDraw()
            ThrottleBar.showDraw()
            StallOrb.showDraw()
        end
    end
            
    change_enviro = false
end

-- Parse ::pos{system, body, latDeg, lonDeg, altM}
local function parsePosString(s)
    if type(s) ~= 'string' then return nil end
    local a,b,lat,lon,alt = s:match('::pos{%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*,%s*([%-%d%.]+)%s*}')
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(lat), tonumber(lon), tonumber(alt)
end

-- Handle chat input to set destination
system:onEvent('onInputText', function(self, text)
    if type(text) ~= 'string' then return end

    -- 0) List saved valid waypoints
    do
        local trimmed = text:match('^%s*(.-)%s*$')
        if trimmed and trimmed:lower() == 'list' then
            if not disk then
                system.print('No databank |disk| linked: cannot list')
                return
            end

            -- collect keys from databank using any available API
            local keys = {}
            if disk.getKeyList then
                local kl = disk.getKeyList()
                if type(kl) == 'table' then
                    for _, k in ipairs(kl) do table.insert(keys, tostring(k)) end
                end
            end
            if #keys == 0 and disk.getNbKeys and disk.getKey then
                local n = tonumber(disk.getNbKeys()) or 0
                -- try 0-based then 1-based just in case
                for i = 0, math.max(n - 1, 0) do
                    local k = disk.getKey(i)
                    if k then table.insert(keys, tostring(k)) end
                end
                if #keys == 0 then
                    for i = 1, n do
                        local k = disk.getKey(i)
                        if k then table.insert(keys, tostring(k)) end
                    end
                end
            end

            if #keys == 0 then
                system.print('No keys found in databank')
                return
            end

            local listed = 0
            for _, key in ipairs(keys) do
                local val = disk.getStringValue and disk.getStringValue(key) or nil
                if type(val) == 'string' and val:find('^::pos%{') then
                    local sid, bid, lat, lon, alt = parsePosString(val)
                    if sid then
                        local center, radius = getBodyCenter(sid, bid)
                        if center and radius then
                            system.print(key)
                            listed = listed + 1
                        end
                    end
                end
            end

            if listed == 0 then
                system.print('No valid waypoint entries found')
            else
                system.print(string.format('Listed %d valid waypoint entries', listed))
            end
            return
        end
    end

    -- 1) Named save: 'name ::pos{...}'
    local name, posStr = text:match('^%s*([^:][%w%._%-%s]*)%s+(::pos%b{})%s*$')
    if name and posStr then
        name = name:match('^%s*(.-)%s*$') -- trim
        tele_name, tele_posStr = name, posStr
        if disk and disk.setStringValue then
            disk.setStringValue(tele_name, tele_posStr)
            system.print(string.format('Saved %s -> %s', tele_name, tele_posStr))
        else
            system.print('No databank |disk| linked: cannot save')
        end
        -- Also set as current destination
        tele_sysId, tele_bodyId, tele_lat, tele_lon, tele_alt = parsePosString(tele_posStr)
        if tele_sysId then
            local world = posToWorld(tele_sysId, tele_bodyId, tele_lat, tele_lon, tele_alt)
            if world then
                __destPos = world
                system.print(string.format('Destination set to %s', tele_name))
            end
        end
        return
    end

    -- 2) Raw ::pos string
    do
        local sysId, bodyId, lat, lon, alt = parsePosString(text)
        if sysId then
            tele_sysId, tele_bodyId, tele_lat, tele_lon, tele_alt = sysId, bodyId, lat, lon, alt
            tele_name = "Unknown"
            tele_posStr = text
            local world = posToWorld(sysId, bodyId, lat, lon, alt)
            if world then
                __destPos = world
                if bodyId == 0 then
                    system.print(string.format('Destination set to space (x %.1f, y %.1f, z %.1f)', lat, lon, alt))
                else
                    system.print(string.format('Destination set to system %d body %d (lat %.4f, lon %.4f, alt %.1f)', sysId, bodyId, lat, lon, alt))
                end
                return
            else
                system.print('Invalid ::pos body/system for atlas')
                return
            end
        end
    end

    -- 3) Recall by name: look up in databank
    if disk and disk.getStringValue then
        local key = text:match('^%s*(.-)%s*$')
        local saved = disk.getStringValue(key)
        if saved and saved:find('^::pos%{') then
            tele_name, tele_posStr = key, saved
            local sysId, bodyId, lat, lon, alt = parsePosString(saved)
            if sysId then
                tele_sysId, tele_bodyId, tele_lat, tele_lon, tele_alt = sysId, bodyId, lat, lon, alt
                local world = posToWorld(sysId, bodyId, lat, lon, alt)
                if world then
                    __destPos = world
                    system.print(string.format('Destination recalled: %s -> %s', key, saved))
                    return
                else
                    system.print('Saved ::pos not valid for current atlas')
                    return
                end
            end
        end
    end

    system.print('Unrecognized input. Use |name ::pos{...}| to save, |::pos{...}| to set, or a saved name to recall.')
end)

-- landing gear: only deploy if speed < 10 m/s
local v = vec3(construct.getWorldVelocity())
local speed = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
if speed <= 10 then
    unit.deployLandingGears()
    gearExtended = true
    Nav.axisCommandManager:setTargetGroundAltitude(0)
else
    gearExtended = false
    Nav.axisCommandManager:setTargetGroundAltitude(200)
end

unit:onEvent('onStop', function (self)
    system.setWaypoint(system.getWaypointFromPlayerPos(),false)
    -- Widgets and panels intentionally disabled
    if switch then switch.deactivate() end
    unit.switchOffHeadlights()
end )

system:onEvent('onFlush', function (self)

    local pitchSpeedFactor = 0.8 --export: This factor will increase/decrease the player input along the pitch axis<br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01
    local yawSpeedFactor =  1 --export: This factor will increase/decrease the player input along the yaw axis<br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01
    local rollSpeedFactor = 1.5 --export: This factor will increase/decrease the player input along the roll axis<br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01

    local brakeSpeedFactor = 3 --export: When braking, this factor will increase the brake force by brakeSpeedFactor * velocity<br>Valid values: Superior or equal to 0.01
    local brakeFlatFactor = 1 --export: When braking, this factor will increase the brake force by a flat brakeFlatFactor * velocity direction><br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01

    local autoRoll = true --export: [Only in atmosphere]<br>When the pilot stops rolling,  flight model will try to get back to horizontal (no roll)
    local autoRollFactor = 2 --export: [Only in atmosphere]<br>When autoRoll is engaged, this factor will increase to strength of the roll back to 0<br>Valid values: Superior or equal to 0.01

    local turnAssist = true --export: [Only in atmosphere]<br>When the pilot is rolling, the flight model will try to add yaw and pitch to make the construct turn better<br>The flight model will start by adding more yaw the more horizontal the construct is and more pitch the more vertical it is
    local turnAssistFactor = 2 --export: [Only in atmosphere]<br>This factor will increase/decrease the turnAssist effect<br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01

    local torqueFactor = 2 -- Force factor applied to reach rotationSpeed<br>(higher value may be unstable)<br>Valid values: Superior or equal to 0.01

    -- validate params
    pitchSpeedFactor = math.max(pitchSpeedFactor, 0.01)
    yawSpeedFactor = math.max(yawSpeedFactor, 0.01)
    rollSpeedFactor = math.max(rollSpeedFactor, 0.01)
    torqueFactor = math.max(torqueFactor, 0.01)
    brakeSpeedFactor = math.max(brakeSpeedFactor, 0.01)
    brakeFlatFactor = math.max(brakeFlatFactor, 0.01)
    autoRollFactor = math.max(autoRollFactor, 0.01)
    turnAssistFactor = math.max(turnAssistFactor, 0.01)

    -- final inputs
    local finalPitchInput = pitchInput + system.getControlDeviceForwardInput()
    local finalRollInput = rollInput + system.getControlDeviceYawInput()
    local finalYawInput = yawInput - system.getControlDeviceLeftRightInput()
    local finalBrakeInput = brakeInput

    -- Axis
    local worldVertical = vec3(core.getWorldVertical()) -- along gravity
    local constructUp = vec3(construct.getWorldOrientationUp())
    local constructForward = vec3(construct.getWorldOrientationForward())
    local constructRight = vec3(construct.getWorldOrientationRight())
    constructVelocity = vec3(construct.getWorldVelocity())
    local constructVelocityDir = vec3(construct.getWorldVelocity()):normalize()
    local currentRollDeg = getRoll(worldVertical, constructForward, constructRight)
    local currentRollDegAbs = math.abs(currentRollDeg)
    local currentRollDegSign = utils.sign(currentRollDeg)

    -- Compute HUD values
    do
        local vdir = constructVelocityDir
        local fwd = vec3(construct.getWorldOrientationForward())
        local dotv = clamp(vdir:dot(fwd), -1, 1)
        local aoa = math.deg(math.acos(dotv)) -- 0..180
        aoa = math.min(aoa, 45)
        stallScaled = math.floor((aoa / 45) * 60 + 0.5)
    end

    do
        if __destPos then
            local pos = vec3(construct.getWorldPosition())
            local toDest = v3sub(__destPos, pos)
            local up = vec3(construct.getWorldOrientationUp())
            local right = vec3(construct.getWorldOrientationRight())
            -- Project destination vector onto horizontal plane (azimuth only)
            local toFlat = toDest - up * toDest:dot(up)
            local toStraight = toDest - right * toDest:dot(right)
            local len = toFlat:len()
            local narrow = toStraight:len()
            if len > 1e-6 then
                toFlat = toFlat / len
                local fwd = vec3(construct.getWorldOrientationForward())
                local right = vec3(construct.getWorldOrientationRight())
                local x = toFlat:dot(fwd)
                local y = toFlat:dot(right)
                local yawDeg = math.deg(math.atan(y, x)) -- signed, -180..180
                -- Clamp to +/-90 for scale window
                local dev = math.max(-90, math.min(90, yawDeg))
                headingScaled = math.floor((dev / 90) * 130 + 0.5)
            end
            if narrow > 1e-6 then
                toStraight = toStraight / narrow
                local fwd = vec3(construct.getWorldOrientationForward())
                local up = vec3(construct.getWorldOrientationUp())
                local x = toStraight:dot(fwd)
                local y = toStraight:dot(up)
                local pitchDeg = math.deg(math.atan(y, x)) -- signed, -180..180
                local clamped = clamp(pitchDeg, -45, 45)   -- limit to +/-45
                local scaled = (clamped + 45) / 90         -- normalize to 0..1
                climbScaled = math.floor(scaled * 110 + 0.5)
            end
        end
    end

    do
        local fwd = vec3(construct.getWorldOrientationForward())
        velocity = constructVelocity:dot(fwd) * 3.6 -- km/h along forward
        if velocity < 0 then velocity = 0 end
        local s = math.min(velocity, 1000) / 1000 * 110
        speedScaled = math.floor(s + 0.5)
    end

    do
        local pos = vec3(construct.getWorldPosition())
        local nearestDist = math.huge
        local nearestRadius = 0
        for sysId, sys in pairs(atlas) do
            if type(sys) == 'table' then
                for bodyId, body in pairs(sys) do
                    if type(body) == 'table' and body.center then
                        local c = body.center
                        local d = v3sub(pos, vec3(c[1], c[2], c[3])):len()
                        if d < nearestDist then
                            nearestDist = d
                            nearestRadius = body.radius or 0
                        end
                    end
                end
            end
        end
        altM = math.max(nearestDist - nearestRadius, 0)
        local s = math.min(altM, 3500) / 3500 * 110
        altScaled = math.floor(s + 0.5)
    end

    do
        if __destPos then
            local pos = vec3(construct.getWorldPosition())
            distKm = (v3sub(__destPos, pos):len()) / 1000
        end
    end

    -- Safety: disable ground engine altitude stabilization when too close to ground
    do
        local d
        -- Altimeter if linked
        if altimeter and altimeter.getMaxDistance then
            d = altimeter.getMaxDistance()
        end
        if type(d) == 'number' and d < 2 then
            Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
        end
    end

    -- Rotation
    local constructAngularVelocity = vec3(construct.getWorldAngularVelocity())
    local targetAngularVelocity = finalPitchInput * pitchSpeedFactor * constructRight
                                    + finalRollInput * rollSpeedFactor * constructForward
                                    + finalYawInput * yawSpeedFactor * constructUp

    -- In atmosphere?
    if worldVertical:len() > 0.01 and unit.getAtmosphereDensity() > 0.0 then
        local autoRollRollThreshold = 1.0
        -- autoRoll on AND currentRollDeg is big enough AND player is not rolling
        if autoRoll == true and currentRollDegAbs > autoRollRollThreshold and finalRollInput == 0 then
            local targetRollDeg = utils.clamp(0,currentRollDegAbs-30, currentRollDegAbs+30);  -- we go back to 0 within a certain limit
            if (rollPID == nil) then
                rollPID = pid.new(autoRollFactor * 0.01, 0, autoRollFactor * 0.1) -- magic number tweaked to have a default factor in the 1-10 range
            end
            rollPID:inject(targetRollDeg - currentRollDeg)
            local autoRollInput = rollPID:get()

            targetAngularVelocity = targetAngularVelocity + autoRollInput * constructForward
        end
        local turnAssistRollThreshold = 20.0
        -- turnAssist AND currentRollDeg is big enough AND player is not pitching or yawing
        if turnAssist == true and currentRollDegAbs > turnAssistRollThreshold and finalPitchInput == 0 and finalYawInput == 0 then
            local rollToPitchFactor = turnAssistFactor * 0.1 -- magic number tweaked to have a default factor in the 1-10 range
            local rollToYawFactor = turnAssistFactor * 0.025 -- magic number tweaked to have a default factor in the 1-10 range

            -- rescale (turnAssistRollThreshold -> 180) to (0 -> 180)
            local rescaleRollDegAbs = ((currentRollDegAbs - turnAssistRollThreshold) / (180 - turnAssistRollThreshold)) * 180
            local rollVerticalRatio = 0
            if rescaleRollDegAbs < 90 then
                rollVerticalRatio = rescaleRollDegAbs / 90
            elseif rescaleRollDegAbs < 180 then
                rollVerticalRatio = (180 - rescaleRollDegAbs) / 90
            end

            rollVerticalRatio = rollVerticalRatio * rollVerticalRatio

            local turnAssistYawInput = - currentRollDegSign * rollToYawFactor * (1.0 - rollVerticalRatio)
            local turnAssistPitchInput = rollToPitchFactor * rollVerticalRatio

            targetAngularVelocity = targetAngularVelocity
                                + turnAssistPitchInput * constructRight
                                + turnAssistYawInput * constructUp
        end
    end

    -- Engine commands
    local keepCollinearity = 1 -- for easier reading
    local dontKeepCollinearity = 0 -- for easier reading
    local tolerancePercentToSkipOtherPriorities = 1 -- if we are within this tolerance (in%), we don't go to the next priorities

    -- Rotation
    local angularAcceleration = torqueFactor * (targetAngularVelocity - constructAngularVelocity)
    local airAcceleration = vec3(construct.getWorldAirFrictionAngularAcceleration())
    angularAcceleration = angularAcceleration - airAcceleration -- Try to compensate air friction
    Nav:setEngineTorqueCommand('torque', angularAcceleration, keepCollinearity, 'airfoil', '', '', tolerancePercentToSkipOtherPriorities)

    -- Brakes
    local brakeAcceleration = -finalBrakeInput * (brakeSpeedFactor * constructVelocity + brakeFlatFactor * constructVelocityDir)
    Nav:setEngineForceCommand('brake', brakeAcceleration)

    -- AutoNavigation regroups all the axis command by 'TargetSpeed'
    local autoNavigationEngineTags = ''
    local autoNavigationAcceleration = vec3()
    local autoNavigationUseBrake = false

    -- Longitudinal Translation (disabled when landing gear deployed)
    local longitudinalEngineTags = 'thrust analog longitudinal'
    local longitudinalCommandType = Nav.axisCommandManager:getAxisCommandType(axisCommandId.longitudinal)
    if not gearExtended then
        if (longitudinalCommandType == axisCommandType.byThrottle) then
            local longitudinalAcceleration = Nav.axisCommandManager:composeAxisAccelerationFromThrottle(longitudinalEngineTags,axisCommandId.longitudinal)
            Nav:setEngineForceCommand(longitudinalEngineTags, longitudinalAcceleration, keepCollinearity)
        elseif  (longitudinalCommandType == axisCommandType.byTargetSpeed) then
            local longitudinalAcceleration = Nav.axisCommandManager:composeAxisAccelerationFromTargetSpeed(axisCommandId.longitudinal)
            autoNavigationEngineTags = autoNavigationEngineTags .. ' , ' .. longitudinalEngineTags
            autoNavigationAcceleration = autoNavigationAcceleration + longitudinalAcceleration
            if (Nav.axisCommandManager:getTargetSpeed(axisCommandId.longitudinal) == 0 or -- we want to stop
                Nav.axisCommandManager:getCurrentToTargetDeltaSpeed(axisCommandId.longitudinal) < - Nav.axisCommandManager:getTargetSpeedCurrentStep(axisCommandId.longitudinal) * 0.5) -- if the longitudinal velocity would need some braking
            then
                autoNavigationUseBrake = true
            end
        end
    end

    -- Lateral Translation (disabled when landing gear deployed)
    local lateralStrafeEngineTags = 'thrust analog lateral'
    local lateralCommandType = Nav.axisCommandManager:getAxisCommandType(axisCommandId.lateral)
    if not gearExtended then
        if (lateralCommandType == axisCommandType.byThrottle) then
            local lateralStrafeAcceleration =  Nav.axisCommandManager:composeAxisAccelerationFromThrottle(lateralStrafeEngineTags,axisCommandId.lateral)
            Nav:setEngineForceCommand(lateralStrafeEngineTags, lateralStrafeAcceleration, keepCollinearity)
        elseif  (lateralCommandType == axisCommandType.byTargetSpeed) then
            local lateralAcceleration = Nav.axisCommandManager:composeAxisAccelerationFromTargetSpeed(axisCommandId.lateral)
            autoNavigationEngineTags = autoNavigationEngineTags .. ' , ' .. lateralStrafeEngineTags
            autoNavigationAcceleration = autoNavigationAcceleration + lateralAcceleration
        end
    end

    -- Vertical Translation (always enabled; works with landing gear deployed)
    local verticalStrafeEngineTags = 'thrust analog vertical'
    local verticalCommandType = Nav.axisCommandManager:getAxisCommandType(axisCommandId.vertical)
    if (verticalCommandType == axisCommandType.byThrottle) then
        local verticalStrafeAcceleration = Nav.axisCommandManager:composeAxisAccelerationFromThrottle(verticalStrafeEngineTags,axisCommandId.vertical)
        Nav:setEngineForceCommand(verticalStrafeEngineTags, verticalStrafeAcceleration, keepCollinearity, 'airfoil', 'ground', '', tolerancePercentToSkipOtherPriorities)
    elseif  (verticalCommandType == axisCommandType.byTargetSpeed) then
        local verticalAcceleration = Nav.axisCommandManager:composeAxisAccelerationFromTargetSpeed(axisCommandId.vertical)
        if gearExtended then
            -- When gear is down, drive vertical directly instead of via auto-navigation
            Nav:setEngineForceCommand(verticalStrafeEngineTags, verticalAcceleration, keepCollinearity, 'airfoil', 'ground', '', tolerancePercentToSkipOtherPriorities)
        else
            autoNavigationEngineTags = autoNavigationEngineTags .. ' , ' .. verticalStrafeEngineTags
            autoNavigationAcceleration = autoNavigationAcceleration + verticalAcceleration
        end
    end

    -- Auto Navigation (Cruise Control) - disabled when landing gear deployed
    if (not gearExtended) and (autoNavigationAcceleration:len() > constants.epsilon) then
        if (brakeInput ~= 0 or autoNavigationUseBrake or math.abs(constructVelocityDir:dot(constructForward)) < 0.95)  -- if the velocity is not properly aligned with the forward
        then
            autoNavigationEngineTags = autoNavigationEngineTags .. ', brake'
        end
        Nav:setEngineForceCommand(autoNavigationEngineTags, autoNavigationAcceleration, dontKeepCollinearity, '', '', '', tolerancePercentToSkipOtherPriorities)
    end

    -- Rockets
    Nav:setBoosterCommand('rocket_engine')
    

end)

system:onEvent('onUpdate', function (self)
    Nav:update()

    -- Update HUD
    -- local svg = ui.hud(stallScaled, headingScaled, speedScaled, altScaled, distKm))
    updateHud()

    local svg = projector.getSVG()
    if svg then system.setScreen(svg) end

end)

system:onEvent('onActionStart', function (self, action)
    if action == 'stopengines' then
        Nav.axisCommandManager:resetCommand(axisCommandId.longitudinal)
    elseif action == 'strafeleft' then
        Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.lateral, -1.0)
    elseif action == 'gear' then
            gearExtended = not gearExtended
            if gearExtended then
                unit.deployLandingGears()
                Nav.axisCommandManager:setTargetGroundAltitude(0)
            else
                unit.retractLandingGears()
                Nav.axisCommandManager:setTargetGroundAltitude(200)
            end
        
    elseif action == 'brake' then
            brakeInput = brakeInput + 1
            local longitudinalCommandType = Nav.axisCommandManager:getAxisCommandType(axisCommandId.longitudinal)
            if (longitudinalCommandType == axisCommandType.byTargetSpeed) then
                local targetSpeed = Nav.axisCommandManager:getTargetSpeed(axisCommandId.longitudinal)
                if (math.abs(targetSpeed) > constants.epsilon) then
                    Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.longitudinal, - utils.sign(targetSpeed))
                end
            end
    elseif action == 'groundaltitudedown' then
        Nav.axisCommandManager:updateTargetGroundAltitudeFromActionStart(-1.0)
    elseif action == 'backward' then
        pitchInput = pitchInput + 1
    elseif action == 'speedup' then
        Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.longitudinal, 5.0)
    elseif action == 'light' then
            if unit.isAnyHeadlightSwitchedOn() then
                unit.switchOffHeadlights()
                if switch then switch.deactivate() end
            else
                unit.switchOnHeadlights()
                if switch then switch.activate() end
            end
        
    elseif action == 'left' then
        rollInput = rollInput - 1
    elseif action == 'forward' then
        pitchInput = pitchInput - 1
    elseif action == 'speeddown' then
        Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.longitudinal, -5.0)
    elseif action == 'groundaltitudeup' then
        Nav.axisCommandManager:updateTargetGroundAltitudeFromActionStart(1.0)
    elseif action == 'right' then
        rollInput = rollInput + 1
    elseif action == 'booster' then
        Nav:toggleBoosters()
    elseif action == 'yawright' then
        yawInput = yawInput - 1
    elseif action == 'straferight' then
        Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.lateral, 1.0)
    elseif action == 'yawleft' then
        yawInput = yawInput + 1
    elseif action == 'down' then
            Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
            Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.vertical, -1.0)
    elseif action == 'up' then
            Nav.axisCommandManager:deactivateGroundEngineAltitudeStabilization()
            Nav.axisCommandManager:updateCommandFromActionStart(axisCommandId.vertical, 1.0)
    elseif action == 'antigravity' then
        if antigrav ~= nil then antigrav.toggle() end
    end
end)

system:onEvent('onActionStop', function (self, action)
    if action == 'backward' then
        pitchInput = pitchInput - 1
    elseif action == 'left' then
        rollInput = rollInput + 1
    elseif action == 'down' then
            Nav.axisCommandManager:updateCommandFromActionStop(axisCommandId.vertical, 1.0)
            Nav.axisCommandManager:activateGroundEngineAltitudeStabilization(currentGroundAltitudeStabilization)
        
    elseif action == 'yawright' then
        yawInput = yawInput + 1
    elseif action == 'yawleft' then
        yawInput = yawInput - 1
    elseif action == 'forward' then
        pitchInput = pitchInput + 1
    elseif action == 'straferight' then
        Nav.axisCommandManager:updateCommandFromActionStop(axisCommandId.lateral, -1.0)
    elseif action == 'up' then
            Nav.axisCommandManager:updateCommandFromActionStop(axisCommandId.vertical, -1.0)
            Nav.axisCommandManager:activateGroundEngineAltitudeStabilization(currentGroundAltitudeStabilization)
    elseif action == 'strafeleft' then
        Nav.axisCommandManager:updateCommandFromActionStop(axisCommandId.lateral, 1.0)
    elseif action == 'brake' then
        brakeInput = brakeInput - 1
    elseif action == 'right' then
        rollInput = rollInput - 1
    end
end)

system:onEvent('onActionLoop', function (self, action)
    if action == 'brake' then
            local longitudinalCommandType = Nav.axisCommandManager:getAxisCommandType(axisCommandId.longitudinal)
            if (longitudinalCommandType == axisCommandType.byTargetSpeed) then
                local targetSpeed = Nav.axisCommandManager:getTargetSpeed(axisCommandId.longitudinal)
                if (math.abs(targetSpeed) > constants.epsilon) then
                    Nav.axisCommandManager:updateCommandFromActionLoop(axisCommandId.longitudinal, - utils.sign(targetSpeed))
                end
            end
    elseif action == 'speeddown' then
        Nav.axisCommandManager:updateCommandFromActionLoop(axisCommandId.longitudinal, -1.0)
    elseif action == 'speedup' then
        Nav.axisCommandManager:updateCommandFromActionLoop(axisCommandId.longitudinal, 1.0)
    elseif action == 'groundaltitudeup' then
        Nav.axisCommandManager:updateTargetGroundAltitudeFromActionLoop(1.0)
    elseif action == 'groundaltitudedown' then
        Nav.axisCommandManager:updateTargetGroundAltitudeFromActionLoop(-1.0)
    end
end)

