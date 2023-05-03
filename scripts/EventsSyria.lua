--v.90

--- DEBUG --
BASE:TraceOnOff(false)
BASE:TraceAll(false)
--ActiveFrontline = 15  -- do not enable for production

----------------
--Random Event--
----------------

local eventTimes = {300,3900,7500,11100}
local bomberRepeatInterval = 15000
local debugBombers = false

if DebugMode == true and debugBombers == true then 
    eventTimes = {100,200,300,400} 
    bomberRepeatInterval = 60
end

local function shuffle(list)
    for i = #list, 2, -1 do
        local j = math.random(i)
        list[i], list[j] = list[j], list[i]
    end
end
shuffle(eventTimes)

----------------
--- Bombers ----
----------------

local bombers = {
    zones = {{
        zone = ZONE:FindByName("BomberSouth"),
        distance = {
            blue = "1/4",
            red = "3/4"
        },
        here = {}
    }, {
        zone = ZONE:FindByName("BomberMid"),
        distance = {
            blue = "1/2",
            red = "1/2"
        },
        here = {}
    }, {
        zone = ZONE:FindByName("BomberNorth"),
        distance = {
            blue = "3/4",
            red = "1/4"
        },
        here = {}
    }},
    squadrons = {{
        name = "Blue Bomber Squadron",
        set = SET_GROUP:New():FilterCoalitions("blue"):FilterPrefixes("BlueBomberGroup"):FilterStart(),
        side = "blue",
        startTime = eventTimes[1],
        repeatInterval = bomberRepeatInterval,
        units = {"BlueBomberGroup 1", "BlueBomberGroup 2", "BlueBomberGroup 3"},
        airbase = AIRBASE:FindByName(AIRBASE.Syria.King_Hussein_Air_College),
        spawnAltitude = 15000,
        spawnAltitudeSpacing = 1000,
        activeBomber ={}
    }, {
        name = "Red Bomber Squadron",
        set = SET_GROUP:New():FilterCoalitions("red"):FilterPrefixes("RedBomberGroup"):FilterStart(),
        side = "red",
        startTime = eventTimes[2],
        repeatInterval = bomberRepeatInterval,
        units = {"RedBomberGroup 1", "RedBomberGroup 2", "RedBomberGroup 3"},
        airbase = AIRBASE:FindByName(AIRBASE.Syria.Aleppo),
        spawnAltitude = 15000,
        spawnAltitudeSpacing = 1000,
        activeBomber = {}
    }}
}

SCHEDULER:New(nil, function()
    for _, zone in ipairs(bombers.zones) do
        for _, squadron in ipairs(bombers.squadrons) do
            local hereNow = squadron.set:AnyInZone(zone.zone)
            local hereBefore = false
            if zone.here[squadron.name] ~= nil then
                hereBefore = zone.here[squadron.name]
            else
                zone.here[squadron.name] = false
            end
            if hereNow and not hereBefore then
                zone.here[squadron.name] = true
                MESSAGE:New(squadron.name .. " at approx " .. zone.distance[squadron.side] .. " distance to target", 60):ToAll()
            elseif not hereNow and hereBefore then
                zone.here[squadron.name] = false
            end
        end
    end
end, {}, 5, 5)

for _, squadron in ipairs(bombers.squadrons) do
    SCHEDULER:New(nil, function()
        MESSAGE:New("|***************|    INCOMING INTEL RELAY    |***************|\nBomber Squadron departing from " .. string.upper(squadron.airbase.AirbaseName), 60):ToAll()
        local altitude = squadron.spawnAltitude
        for _, unit in ipairs(squadron.units) do
            SPAWN:New(unit):InitLimit(12, 100):InitRandomizeRoute(1, 1, 10000):OnSpawnGroup(
                function(SpawnGroup)
                    --squadron.activebomber = squadron.activebomber:AddGroup(SpawnGroup)
                    SpawnGroup:HandleEvent(EVENTS.Crash)
                    function SpawnGroup:OnEventCrash()
                        local group, unit = squadron.set:CountAlive()
                        if unit < 1 then
                            MESSAGE:New("All units from "..squadron.name.." have been shot down.\n                      Threat is neutralized.", 60):ToAll()
                        else
                            MESSAGE:New(squadron.name.." is under heavy attack.\n"..unit.." aircraft remain combat effective and on task", 30):ToAll()
                        end
                    end
                -- blow up some bombers for debug test    
                --coord = SpawnGroup:GetCoordinate()
                --coord:Explosion(1000)
                end
            ):SpawnAtAirbase(squadron.airbase, SPAWN.Takeoff.Air, altitude)
            altitude = altitude + squadron.spawnAltitudeSpacing
        end
    end, {}, squadron.startTime, squadron.repeatInterval)
end

----------------
---- Boats -----
----------------

local boatSpawnZones = SET_ZONE:New():FilterPrefixes("zoneFlotilla"):FilterOnce()

local boats = {    
    squadrons = {{
    name = "Blue Flotilla",
    set = SET_GROUP:New():FilterCoalitions("blue"):FilterPrefixes("BlueFlotilla"):FilterStart(),
    parkBoats = SET_STATIC:New():FilterCoalitions("red"):FilterPrefixes("REDFOR Industrial Target 3"):FilterStart(),
    side = "blue",
    startTime = eventTimes[3],
    repeatInterval = 15600,
    units = {"BlueFlotilla"},
    targets = "RED NavalConvoy",
    activeBoat = {},
    activeTarg = {},
    aliveTarg = 10,
    checkTarg = true,
    targetBuff = -2,-- -1
    heading = "North",
    zoneBuff = 0
}, {
    name = "Red Flotilla",
    set = SET_GROUP:New():FilterCoalitions("red"):FilterPrefixes("RedFlotilla"):FilterStart(),
    parkBoats = SET_STATIC:New():FilterCoalitions("blue"):FilterPrefixes("BLUEFOR Industrial Target 3"):FilterStart(),
    side = "red",
    startTime = eventTimes[4],
    repeatInterval = 15600,
    units = {"RedFlotilla"},
    targets = "BLUE NavalConvoy",
    activeBoat = {},
    activeTarg = {},
    aliveTarg = 10,
    checkTarg = true,
    targetBuff = 2,-- 1
    heading = "South",
    zoneBuff = 0
}}
}

local function clamp(a,b,c) 
    return math.min(math.max(a,b),c)
end

local function SpawnCalc(allBoatZones, activeFrontLineIndex, buffer)
    local activefrontline = clamp(activeFrontLineIndex + buffer, 1, 30)
    return allBoatZones:Get("zoneFlotilla-"..activefrontline)
end

for _, squadron in ipairs(boats.squadrons) do
    SCHEDULER:New(nil, function()
        for _, unit in ipairs(squadron.units) do
            local activeSpawnZone = SpawnCalc(boatSpawnZones, ActiveFrontline, squadron.zoneBuff)
            SPAWN:New(unit):InitLimit(5, 100):InitRandomizeRoute(1, 1, 10000):OnSpawnGroup(
                function(SpawnGroup)
                    squadron.activeBoat = SpawnGroup
                    SpawnGroup:HandleEvent( EVENTS.Dead )
                    local zone = ActiveFrontline - squadron.targetBuff
                    local wp1 = ZONE:New("zoneFlotilla-"..zone):GetCoordinate()
                    local seamen = NAVYGROUP:New(SpawnGroup)
                    local coord = seamen:GetCoordinate()
                    local intel = coord:MarkToAll(squadron.name.." last known location", true)
                    --seamen:SetEngageDetectedOn(30)
                    seamen:AddWaypoint(wp1, 25)

                    function seamen:OnAfterPassingWaypoint(From, Event, To, Waypoint)
                        MESSAGE:New(squadron.name.." have arrived at destination and are laying antiship mines for 5 minutes",60):ToAll()
                        seamen:ScheduleOnce(300, function()
                        seamen:Despawn(230, true)
                        coord:RemoveMark(intel)
                        squadron.checkTarg = false
                            local seaunit = squadron.activeTarg:GetUnits()
                            for _, unit in ipairs(seaunit) do
                                coords = unit:GetCoordinate()
                                coords:Explosion(1000, 15)
                            end
                                squadron.parkBoats:ForEach(function(thestatic)
                                coords = thestatic:GetCoordinate()
                                coords:Explosion(1000, 5)
                            end)
                        --squadron.activeTarg:Destroy(true, 15)
                        MESSAGE:New(squadron.name.." have completed their mission successfully.\n Enemy Industrial Target 3 Destroyed!",60):ToAll()
                        end)
                    end

                    seamen:ScheduleOnce(2700, function()
                        coord:RemoveMark(intel)
                        MESSAGE:New("Naval Intel Degraded",30):ToAll()
                    end)
                    seamen:HandleEvent(EVENTS.Dead)
                    --seamen:SelfDestruction(15, 1500)
                    function SpawnGroup:OnEventDead()
                        local initial = SpawnGroup:GetInitialSize()
                        local alive = SpawnGroup:CountAliveUnits()
                        if alive < 1    then
                            MESSAGE:New(squadron.name.." has been completely destroyed.\n                  Convoy is secured", 60):ToAll()
                            coord:RemoveMark(intel)
                        else
                            MESSAGE:New(squadron.name.." has taken heavy damage!!\n                "..alive.." out of "..initial.." units remain", 30):ToAll()
                        end
                    end
                SPAWN:New(squadron.targets):InitLimit(5, 100):InitRandomizeRoute(1, 1, 10000):OnSpawnGroup(
                    function(SpawnGroup)
                        squadron.activeTarg = SpawnGroup
--[[                         SpawnGroup:SetCommandInvisible(true)
                        local cmen = NAVYGROUP:New(SpawnGroup)
                        SpawnGroup:HandleEvent(EVENTS.Dead)
                        --cmen:SelfDestruction(30, 1500)
                        function SpawnGroup:OnEventDead()
                            local initial = SpawnGroup:GetInitialSize()
                            local alive = SpawnGroup:CountAliveUnits()
                            if alive < 1 then
                                MESSAGE:New(squadron.targets.." has been completely destroyed.\n              Convoy resources denied", 30):ToAll()
                            else
                                MESSAGE:New(squadron.targets.." has taken heavy damage!!\n                "..alive.." out of "..initial.." units remain", 30):ToAll()
                            end
                        end ]]
                    end
                ):SpawnInZone(wp1)
                end
            ):SpawnInZone(activeSpawnZone, true)
            MESSAGE:New(squadron.name.." spotted heading "..squadron.heading.." off the coast.\n          Consult the map for location intel", 60):ToAll()


            squadron.parkBoats:ForEach(function(static)
                static:HandleEvent(EVENTS.Dead)
                function static:OnEventDead()
                    squadron.aliveTarg = squadron.parkBoats:CountAlive()

--[[                     if alive < 1 and squadron.checkTarg ~= true then
                        MESSAGE:New("Industrial Logistic Ships have been completely destroyed.\n              Convoy resources denied", 60):ToAll()
                    else
                        MESSAGE:New("Industrial Logistic Ships have taken heavy damage!!\n                "..alive.." units remain in the harbour", 30):ToAll()
                    end ]]
                end
            end)
        end
    end, {}, squadron.startTime, squadron.repeatInterval)
end
