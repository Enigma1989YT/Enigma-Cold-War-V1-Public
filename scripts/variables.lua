-- Predefined variables

-- Frontline variables
ActiveFrontline = 15
FrontlineQuantity = 29
SectorQuantity = 30
-- FrontlineTimeout = 10’800
FrontlineTimeout = 7140

-- Secondary airbase status
BlueSecAirbase = false
RedSecAirbase = false

-- Health variables
BlueMaxLives = 1000
BlueLives = nil -- don't change!
RedMaxLives = 1000
RedLives = nil -- don't change!

AvarageFrontlineUnits = 9
AvarageFrontDepotUnits = 26
AvarageStrategicTargetUnits = 10

FrontlineTargetsValue = 500
FrontDepotValue = 200
StrategicTargetValue = 300

-- Frontline move threshold is points value
FrontlineMoveThreshold = 50
-- Breakthrough threshold is percentage value
BreakthroughThreshold = 20

FarpPerZone = 1

AirDefenseResTime = {}
AirDefenseResTime["HighSAM"] = -1
AirDefenseResTime["LowSAM"] = 3600
AirDefenseResTime["SHORAD"] = 3600
AirDefenseResTime["MANPADS"] = 3600

-- Time to restart when mission is completed (seconds)
RestartMission = 180

-- Debug options
DebugMode = false

-- attrition scale
attritionScale = 26

-- infantry variables
infantryRadius = 3000
unitsKilledPerSquad = 2
csarWeight = 0
infantryWeight = 0

--roadbase protection
RoadbaseCeiling = 150

-- global variables for server status
FrontlineStatus = ""
TimeLeft = ""