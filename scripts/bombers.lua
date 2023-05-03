--- DEBUG --
BASE:TraceOnOff(false)
BASE:TraceAll(false)

local bombers = {
    zones = {{
        zone = ZONE:FindByName("BomberWest"),
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
        zone = ZONE:FindByName("BomberEast"),
        distance = {
            blue = "3/4",
            red = "1/4"
        },
        here = {}
    }},
    squadrons = {{
        name = "Blue Bomber Squadron",
        set = SET_GROUP:New():FilterCoalitions("blue"):FilterPrefixes("BLUE BOMBER"):FilterStart(),
        side = "blue",
        startTime = 900,
        repeatInterval = 7200,
        units = {"BLUE BOMBER 1-1", "BLUE BOMBER 1-2", "BLUE BOMBER 1-3"},
        airbase = AIRBASE:FindByName(AIRBASE.Caucasus.Sochi_Adler),
        spawnAltitude = 15000,
        spawnAltitudeSpacing = 1000
    }, {
        name = "Red Bomber Squadron",
        set = SET_GROUP:New():FilterCoalitions("red"):FilterPrefixes("RED BOMBER"):FilterStart(),
        side = "red",
        startTime = 3800,
        repeatInterval = 7200,
        units = {"RED BOMBER 1-1", "RED BOMBER 1-2", "RED BOMBER 1-3"},
        airbase = AIRBASE:FindByName(AIRBASE.Caucasus.Tbilisi_Lochini),
        spawnAltitude = 15000,
        spawnAltitudeSpacing = 1000
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
                MESSAGE:New(squadron.name .. " at approx " .. zone.distance[squadron.side] .. " distance to target", 30):ToAll()
            elseif not hereNow and hereBefore then
                zone.here[squadron.name] = false
            end
        end
    end
end, {}, 5, 5)

for _, squadron in ipairs(bombers.squadrons) do
    SCHEDULER:New(nil, function()
        MESSAGE:New("|************|    INCOMING INTEL RELAY    |************|\nBOMBER FLIGHT SPOTTED TAKING OFF FROM " .. string.upper(squadron.airbase.AirbaseName), 30):ToAll()
        local altitude = squadron.spawnAltitude
        for _, unit in ipairs(squadron.units) do
            SPAWN:New(unit):InitLimit(12, 100):InitRandomizeRoute(1, 1, 10000):SpawnAtAirbase(squadron.airbase, SPAWN.Takeoff.Air, altitude)
            altitude = altitude + squadron.spawnAltitudeSpacing
        end
    end, {}, squadron.startTime, squadron.repeatInterval)
end
