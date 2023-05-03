local getUnitProperty = DCS.getUnitProperty
local format = string.format
local sendChat = net.send_chat_to
local getPlayerInfo = net.get_player_info
local dostring = net.dostring_in
dofile(lfs.writedir().."Scripts/logger.lua")
--dofile("C:/_gitMaster/ECW/scripts/logger.lua")
local logwrite = logger:new()
logwrite:setLevel(logger.enums.debug)

local slotblock = {}
slotblock.slotsByName = {}
slotblock.sectorsByName = {}
slotblock.roadbasesByName = {}

slotblock.gameMasters = {
   -- ["UCID"] = true, -- NAME
	
}

slotblock.exceptions = {
    ["A-10A"] = true,
    ["Su-25"] = true,
    ["MB-339A"] = true,
    ["C-101CC"] = true,
    ["L-39ZA"] = true
}

slotblock.rearAirdromes = {
    ["Krymsk"] = true,
    ["BLUE_00_FARP"] = true,
    ["Mozdok"] = true,
    ["RED_30_FARP"] = true,
    ["Aleppo"] = true,
    ["King Hussein"] = true,
}

slotblock.commanders = {
    [""] = "spectator",
    ["forward_observer"] = "jtac/operator",
}

slotblock.unitBuffers = {
    ["plane"] = {
        ["blue"] = -3, -- the ammount of sectors to buffer
        ["red"] = 3
    },
    ["helicopter"] = {
        ["blue"] = -1,
        ["red"] = 1
    }
}

slotblock.iterations = {
    ["blue"] = {
        ["start"] = 1,
        ["direction"] = 1
    },
    ["red"] = {
        ["start"] = 30,
        ["direction"] = -1
    }
}

slotblock.frontlineBuffers = {
    ["blue"] = 0,
    ["red"] = 1
}

slotblock.forwardAirbases = {
    ["Senaki"] = {
        ["normal"] = 16, -- normal stuff needs to have 16 and above to spawn
        ["exception"] = 14 -- exception needs 14 and above to spawn
    },
    ["Kutaisi"] = {
        ["normal"] = 15, -- normal stuff needs to have 15 and below to spawn
        ["exception"] = 18 -- exception needs to have 18 and below to spawn
    }
}

--
--
--

local function deepCopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

local function makeVec3(vec, y)
    if not vec.z then
        if vec.alt and not y then
            y = vec.alt
        elseif not y then
            y = 0
        end
        return {x = vec.x, y = y, z = vec.y}
    else
        return {x = vec.x, y = vec.y, z = vec.z}
    end
end

local function pointInPolygon(point, poly, maxalt)
	point = makeVec3(point)
	local px = point.x
	local pz = point.z
	local cn = 0
	local newpoly = deepCopy(poly)

	local polysize = #newpoly
	newpoly[#newpoly + 1] = newpoly[1]

	newpoly[1] = makeVec3(newpoly[1])

	for k = 1, polysize do
		newpoly[k+1] = makeVec3(newpoly[k+1])
		if ((newpoly[k].z <= pz) and (newpoly[k+1].z > pz)) or ((newpoly[k].z > pz) and (newpoly[k+1].z <= pz)) then
			local vt = (pz - newpoly[k].z) / (newpoly[k+1].z - newpoly[k].z)
			if (px < newpoly[k].x + vt*(newpoly[k+1].x - newpoly[k].x)) then
				cn = cn + 1
			end
		end
	end

	return cn%2 == 1
end

---
---
---

--[[ return the current frontline
- @return #number frontline or 15 or false if not found
]]

local function getFrontline()
    logwrite:debug("getFrontline()", "getting frontline")
    local frontline, err = dostring("server", "return trigger.misc.getUserFlag('frontline')")
    if not frontline and err then
        logwrite:error("getFrontline()", "cound not get frontline trigger!", frontline)
        return false
    end
    frontline = tonumber(frontline)
    if frontline > -1 then
        logwrite:debug("getFrontline()", "returning current frontline: %d", frontline)
        return frontline
    end
    logwrite:debug("getFrontline()", "returning default frontline 15", frontline)
    return 15 -- return 15 if there is no frontline found
end

--[[ get the sector that a player could be in
- @param #table player
- @param #number frontlineBuffer
- @return #boolean, #number [if true then 2nd return is the sectorId the player is in
]]
local function getPlayerSector(player, frontlineBuffer)
    local playerVec2 = {x = player.x, y = player.y}
    local startIteration = slotblock.iterations[player.side].start
    local direction = slotblock.iterations[player.side].direction
    for sectorId = startIteration, frontlineBuffer, direction do
        local sector = slotblock.sectorsByName["Sector "..sectorId]
        if pointInPolygon(playerVec2, sector.verticies) then
            return true, tonumber(sectorId)
        end
    end
    return false
end

--[[ checks if a player is at a roadbase and if that roadbase is open or closed or if they aren't at a roadbase at all
- @param #table player
- @param #number playerId
- @return #number status [0 = not at roadbase, 1 = at roadbase and is open, 2 = at roadbase and is closed]
]]
local function getRoadbaseStatus(player, playerId)
    logwrite:debug("getRoadbaseStatus()", "checking if %s is at a roadbase", player.unitName)
    for roadbase in pairs(slotblock.roadbasesByName) do
        -- first case blue or second case red
        if player.unitName:sub(1,12) == roadbase or player.unitName:sub(1,11) == roadbase then
            -- the player is at a red or blue roadbase!
            -- now check if the roadbase is closed or open
            local roadbaseName = roadbase.."_closureStatus"
            local status = dostring("server", "return trigger.misc.getUserFlag('"..roadbaseName.."')")
            if status == "2" then
                logwrite:info("allowSlot()", "this slot is *NOT* allowed! the roadbase is closed!")
                sendChat(format("this slot is *NOT* allowed! the roadbase is closed!"), playerId)
                return 2
            end
            -- we found a player at a roadbase but it isn't open
            logwrite:debug("getRoadbaseStatus()", "%s is at open roadbase %s", player.unitName, roadbase)
            return 1
        end
    end
    logwrite:debug("getRoadbaseStatus()", "%s is *NOT* at a roadbase at all", player.unitName)
    return 0
end

---
---
---

--[[ check if the unitName exists in the database as a player(client) unit
- @param #string unitName
- @return #boolean nil [if player does not exist in database]
- @return #table player [if the player does exist in the database]
]]
local function isPlayer(unitName)
    logwrite:debug("isPlayer()", "checking if player unit is in the database")
    local player = slotblock.slotsByName[unitName]
    if not player then
        logwrite:debug("isPlayer()", "player doesnt exist in database")
        return nil
    end
    logwrite:debug("isPlayer()", "player unit found in database")
    return player
end

--[[ return a boolean if the ucid can be game master
- @param #string ucid
- @return #boolean [true if ucid is in slotblock.gameMasters]
]]
local function isGameMaster(ucid)
    logwrite:debug("isGameMaster()", "checking if ucid is a gamemaster")
    if slotblock.gameMasters[ucid] then
        logwrite:debug("isGameMaster()", "allowing game master slot for valid ucid")
        return true
    end
    logwrite:debug("isGameMaster()", "game master slot is *NOT* allowed!")
    return false
end

---
---
---

--[[ return a boolean if the player is at a rear airdrome
- @param #table player
- @param #number playerId
- @return #boolean
]]
local function atRearAirdrome(player, playerId)
    logwrite:debug("atRearAirdrome()", "checking if %s is at a rear airdrome", player.unitName)
    for airdrome in pairs(slotblock.rearAirdromes) do
        if player.unitName:find(airdrome) then
            logwrite:debug("atRearAirdrome()", "%s is at rear airdrome: %s", player.unitName, airdrome)
            sendChat(format("this slot is allowed!"), playerId)
            return true
        end
    end
    logwrite:debug("atRearAirdrome()", "%s is *NOT* at a rear airdrome", player.unitName)
    return false
end

--[[ handles units that may be in a friendly sector within their frontline buffers
- @param #table player
- @param #number frontline
- @return #boolean [true if within a valid sector, false if not in a valid sector or any sector at all]
]]
local function inSector(player, frontline, playerId)
    logwrite:debug("inSector()", "comparing player sector to frontline buffer")
    local frontlineBuffer = frontline + slotblock.frontlineBuffers[player.side]
    local sector, playerSector = getPlayerSector(player, frontlineBuffer)
    if not sector then logwrite:debug("inSector()", "player is not in any sector") return false end
    local sectorBuffer = frontlineBuffer + slotblock.unitBuffers[player.category][player.side]
    if slotblock.exceptions[player.unitType] then
        logwrite:debug("inSector()", "changing sectorBuffer for exception unit %s", player.unitType)
        sectorBuffer = frontlineBuffer -- because exception, they can spawn on their frontlineBuffer
    end
    logwrite:debug("inSector()", "playerSector: %d | frontlineBuffer: %d | sectorBuffer: %d", playerSector, frontlineBuffer, sectorBuffer)
    if player.side == "blue" then
        if playerSector <= sectorBuffer then
            logwrite:debug("inSector()", "allowed! playerSector <= sectorBuffer | %d <= %d", playerSector, sectorBuffer)
            sendChat(format("this slot is allowed!"), playerId)
            return true
        end
        logwrite:debug("inSector()", "*NOT* allowed! playerSector > sectorBuffer |%d > %d", playerSector, sectorBuffer)
        sendChat(format("this slot is *NOT* allowed! %s slots are open from sector %d and below!", player.unitType, sectorBuffer), playerId)
        return false
    elseif player.side == "red" then
        if playerSector >= sectorBuffer then
            logwrite:debug("inSector()", "allowed! playerSector >= sectorBuffer | %d >= %d", playerSector, sectorBuffer)
            sendChat(format("this slot is allowed!"), playerId)
            return true
        end
        logwrite:debug("inSector()", "*NOT* allowed! playerSector < sectorBuffer |%d < %d", playerSector, sectorBuffer)
        sendChat(format("this slot is *NOT* allowed! %s slots are open from sector %d and above!", player.unitType, sectorBuffer), playerId)
        return false
    end
end

---
---
---

--[[ return a boolean if the role is allowed
- handles game master, jtac/operator, spectator slot changes
- @param #number playerId
- @param #string unitType
- @param #string ucid
- @return #boolean [true if they role is allowed, false if the role is not allowed]
]]
local function allowRole(playerId, unitType, ucid)
    logwrite:debug("allowRole()", "trying to allow role %s", unitType)
    if unitType == "instructor" then
        if isGameMaster(ucid) then
            sendChat(format("game master slot is allowed!"), playerId)
            return true
        end -- the player is a valid game master
        sendChat(format("game master slot is *NOT* allowed!"), playerId)
        return false
    end
    local role = slotblock.commanders[unitType]
    if role then
        logwrite:debug("allowRole()", "allowing role %s", role)
        if role == "jtac/operator" then -- just so we dont spam allowed message when players go back to spectator
            sendChat(format("jtac/operator slot is allowed!"), playerId)
        end
        return true
    end
    logwrite:debug("allowRole()", "could *NOT* allow role!")
    return false
end

--[[ return a boolean if a player can occupy a slot
- this logic is the main handler for slot checking logic
- @param #number playerId
- @param #string slotId
- @return #boolean [true if the slot is allowed, false if the slot is not allowed]
]]
local function allowSlot(playerId, slotId)
    logwrite:debug("allowSlot()", "checking exceptions to allow slot")
    local unitType = getUnitProperty(slotId, DCS.UNIT_TYPE)
    local unitName = getUnitProperty(slotId, DCS.UNIT_NAME)
    local ucid = getPlayerInfo(playerId, "ucid")
    local player = isPlayer(unitName)
    if not player then
        -- the player has not selected a unit in the database, check for commands roles
        if allowRole(playerId, unitType, ucid) then return true end
        return false -- couldnt allow a role
    end

    -- is a player, first check if the player is at a closed roadbase
    if getRoadbaseStatus(player, playerId) == 2 then
        return false
    end
    local frontline = getFrontline()
    if not frontline then
        logwrite:debug("allowSlot()", "*NOT* allowed! frontline is nil")
        return false
    end
    if not atRearAirdrome(player, playerId) then
        return inSector(player, frontline, playerId) -- returns true or false if in valid sector
    end
    return true -- exception is at a rear airdrome
end

---
---
---

function slotblock.onPlayerTryChangeSlot(playerId, side, slotId)
    if not allowSlot(playerId, slotId) then return false end
end

function slotblock.onGameEvent(event, ...)
    if event == "crash" then
        local playerId = arg[1]
        local slotId = arg[2]
        if not allowSlot(playerId, slotId) then net.force_player_slot(playerId, 0, "") end
    end
end

function slotblock.onMissionLoadEnd()
    logwrite:debug("onMissionLoadEnd()", "building databases")
    slotblock.mission = DCS.getCurrentMission().mission
    slotblock.theatre = slotblock.mission.theatre
    for coalitionSide, coalitionData in pairs(slotblock.mission.coalition) do
        if coalitionSide ~= "neutrals" then
            if type(coalitionData) == "table" then
                if coalitionData.country then -- country has data
                    for _, ctryData in pairs(coalitionData.country) do
                        for objType, objData in pairs(ctryData) do
                            if objType == "plane" or objType == "helicopter" then
                                for _, groupData in pairs(objData.group) do
                                    for _, unitData in pairs(groupData.units) do
                                        if unitData.skill == "Client" then
                                            slotblock.slotsByName[unitData.name] = {
                                                ["unitType"] = unitData.type,
                                                ["unitName"] = unitData.name,
                                                ["category"] = objType,
                                                ["side"] = coalitionSide,
                                                ["x"] = unitData.x,
                                                ["y"] = unitData.y,
                                            }
                                            logwrite:info("onMissionLoadEnd()", "%s registered into slotblocker.slotsByName", unitData.name)
                                        elseif unitData.name:sub(1, 6) == "Sector" then
                                            slotblock.sectorsByName[unitData.name] = {
                                                ["verticies"] = groupData.route.points
                                            }
                                            logwrite:info("onMissionLoadEnd()", "%s registered into slotblocker.sectorsByName", unitData.name)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    for _, zones in pairs(slotblock.mission.triggers) do
        for _, zoneData in pairs(zones) do
            if zoneData.name:sub(8) == "ROAD" or zoneData.name:sub(9) == "ROAD" then
                slotblock.roadbasesByName[zoneData.name] = {
                    ["radius"] = zoneData.radius,
                    ["y"] = zoneData.y,
                    ["x"] = zoneData.x,
                }
                logwrite:info("onMissionLoadEnd()", "%s registered into slotblocker.roadbasesByName", zoneData.name)
            end
        end
    end
end

DCS.setUserCallbacks(slotblock)
