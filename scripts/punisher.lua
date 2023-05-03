local zonesByName = {}
local punisherZonePrefix = "RUNWAY_DEFENSE"
local lineColor = {1, 0.4, 0, 1}
local fillColor = {1, 0.4, 0, 0.6}
local lineType = 5
local punisher = {}
punisher.zones = {}

local util = {}

util.logInfo = function(msg,...)
	env.info(string.format(msg,...))
end

util.msgToGroup = function(groupId, time, msg, ...)
    trigger.action.outTextForGroup(groupId, string.format(msg, ...), time or 1, true)
end

util.getSimTime = function(time)
	return timer.getTime() + (time or 0)
end

util.scheduler = function(functionToRun, args, time)
	timer.scheduleFunction(functionToRun, args or nil, util.getSimTime(time or 0))
end

util.deepCopy = function(object)
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

util.filterZonePrefixes = function(prefix, prefixes)
	local matchedZones = {}
	if prefixes then
		for _, pfx in pairs(prefixes) do
			for zoneName, zoneData in pairs(zonesByName) do
				if string.match(zoneName, pfx) and string.match(zoneName, prefix) then
					if not matchedZones[zoneName] then
						util.logInfo("%s and %s match with %s", pfx, prefix, zoneName)
						matchedZones[zoneName] = zoneData
					end
				end
			end
		end
	else
		for zoneName, zoneData in pairs(zonesByName) do
			if string.match(zoneName, prefix) then
				if not matchedZones[zoneName] then
					matchedZones[zoneName] = zoneData
					util.logInfo("%s match with %s",prefix, zoneName)
				end
			end
		end
	end
	return matchedZones
end

--- Converts a Vec2 to a Vec3.
-- @tparam Vec2 vec the 2D vector
-- @param y optional new y axis (altitude) value. If omitted it's 0.
-- mist function
util.makeVec3 = function(vec, y)
    if not vec.z then
        if vec.alt and not y then
            y = vec.alt
        elseif not y then
            y = 0
        end
        return {x = vec.x, y = y, z = vec.y}
    else
        return {x = vec.x, y = vec.y, z = vec.z}	-- it was already Vec3, actually.
    end
end

--raycasting point in polygon. Code from http://softsurfer.com/Archive/algorithm_0103/algorithm_0103.htm
-- mist function
util.pointInPolygon = function(point, poly, maxalt)
	point = util.makeVec3(point)
	local px = point.x
	local pz = point.z
	local cn = 0
	local newpoly = util.deepCopy(poly)

	local polysize = #newpoly
	newpoly[#newpoly + 1] = newpoly[1]

	newpoly[1] = util.makeVec3(newpoly[1])

	for k = 1, polysize do
		newpoly[k+1] = util.makeVec3(newpoly[k+1])
		if ((newpoly[k].z <= pz) and (newpoly[k+1].z > pz)) or ((newpoly[k].z > pz) and (newpoly[k+1].z <= pz)) then
			local vt = (pz - newpoly[k].z) / (newpoly[k+1].z - newpoly[k].z)
			if (px < newpoly[k].x + vt*(newpoly[k+1].x - newpoly[k].x)) then
				cn = cn + 1
			end
		end
	end

	return cn%2 == 1
end

--[[ return the 2D distance between two points in meters
- @param #table fromVec3
- @param #table toVec3
- @return #number distance
]]
function util.getDistance(fromVec3, toVec3)
    local dx = toVec3.x - fromVec3.x
    local dy = toVec3.z - fromVec3.z
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance
end

local usedMarkIds = {}
function util.generateMarkId()
    for i = 5000000, 10000000 do
        if usedMarkIds[i] == nil then
			local usedMark = util.deepCopy(i)
			usedMarkIds[usedMark] = usedMark
            return usedMark
        end
    end
end

function util.makeVec3FromVec2(vec2)
	local vec3 = {}
	vec3.z = vec2.y
	vec3.y = vec2.y
	vec3.x = vec2.x
	return vec3
end

local function drawRoadbaseProtection(points)
    local zoneId = util.generateMarkId()
    local drawing = {}
    drawing[#drawing+1] = 6 -- freeform
    drawing[#drawing+1] = -1 -- draw for all
    drawing[#drawing+1] = zoneId
    for i = 1, #points do
        drawing[#drawing+1] = util.makeVec3FromVec2(points[i])
    end
    drawing[#drawing+1] = lineColor
    drawing[#drawing+1] = fillColor
    drawing[#drawing+1] = lineType
	usedMarkIds[zoneId] = zoneId
    trigger.action.markupToAll(unpack(drawing))
end

do
    for _, zones in pairs(env.mission.triggers) do
        for _, zoneData in pairs(zones) do
			local zoneName = zoneData.name
			if zoneData.type == 2 then
				if string.match(zoneName, punisherZonePrefix) then
					zonesByName[zoneData.name] = {
						["radius"] = zoneData.radius,
						["zoneId"] = zoneData.zoneId,
						["color"] =
						{
							[1] = zoneData.color[1],
							[2] = zoneData.color[2],
							[3] = zoneData.color[3],
							[4] = zoneData.color[4],
						},
						["properties"] = zoneData.properties,
						["hidden"] = zoneData.hidden,
						["vec3"] = trigger.misc.getZone(zoneName).point,
						["name"] = zoneData.name,
						["type"] = zoneData.type,
						["verticies"] = zoneData.verticies
					}
					env.info(string.format("zone database registered trigger zone %s into zonesByName", zoneData.name))
					env.info(string.format("drawing zone %s", zoneData.name))
					drawRoadbaseProtection(zoneData.verticies)
				end
			end
        end
    end
	punisher.zones = util.deepCopy(zonesByName)
end

-- general weapons
punisher.weaponEnums = {
    --[0] = "SHELL",
    [1] = "MISSILES", -- if you want to be more specific use missileEnums
    [2] = "ROCKET",
    [3] = "BOMB",
    --[4] = "TORPEDO"
}
-- missile weapons
punisher.missileEnums = {
    --[1] = "AAM", -- air to air (fox 1/2/3)
    --[2] = "SAM", -- surface to air
    --[3] = "BM", -- ballistic missile?
    --[4] = "ANTISHIP",
    --[5] = "CRUISE",
    [6] = "OTHER" -- maverick, harm, harpoon
}

local weaponCutoffRange = 27780 -- 15nm cutoff
function punisher.weaponInRangeOfRoadbase(weapon)
	if weapon ~= nil then
		for _, zoneData in pairs(punisher.zones) do
			local weaponDistanceToRoadbase = util.getDistance(zoneData.vec3, weapon:getPoint())
			if weaponDistanceToRoadbase < weaponCutoffRange then
				-- weapon is less than the cutoff range, monitor it
				return true
			end
		end
	end
	return false
end

function punisher.objectInZone(object)
	if object ~= nil then
		local objectVec3 = object:getPoint()
		for zoneName, zoneData in pairs(punisher.zones) do
			local objectInPolyZone = util.pointInPolygon(objectVec3, zoneData.verticies)
			if objectInPolyZone then
				return true
			end
		end
	end
	return nil
end

function punisher.monitorWeapon(groupId, playerName, weapon)
    if weapon ~= nil then
        if weapon:isExist() then
            local weaponDestroyed = false
            for zoneName, zoneData in pairs(punisher.zones) do
				local weaponVec3 = weapon:getPoint()
				local weaponMSL = weaponVec3.y
				local weaponAGL = weaponMSL - land.getHeight({["x"] = weaponVec3.x, ["y"] = weaponVec3.z})
                local weaponInPolyZone = util.pointInPolygon(weaponVec3, zoneData.verticies)
                if weaponInPolyZone and weaponAGL < RoadbaseCeiling then
                    util.msgToGroup(groupId, 10, "%s, Attacking Roadbases Is Forbidden, Your Weapons Have Been Deleted. Read The FAQ!", playerName)
                    util.logInfo("attempting to destroy %s that was found in zone %s", weapon:getTypeName(), zoneName)
                    trigger.action.explosion(weapon:getPoint(), 100)
				    --weapon:destroy()
                    dcsbot.punish("roadbase-attack", playerName)
					weaponDestroyed = true
                end
            end
            if not weaponDestroyed then
                util.scheduler(function() punisher.monitorWeapon(groupId, playerName, weapon) end, nil, 0.1)
            end
        end
    end
end

function punisher:onEvent(event)
	if event.id == world.event.S_EVENT_SHOT then
		if event.weapon:getTypeName() ~= "SPRD-99" then
			if event.initiator:getPlayerName() ~= nil then
				-- iniatiating unit
				local unit = event.initiator
				local groupId = unit:getGroup():getID()
				local playerName = unit:getPlayerName()
				-- shot weapon
				local weapon = event.weapon
				local weaponCategory = weapon:getDesc().category
				local weaponMissileCategory = weapon:getDesc().missileCategory
				if punisher.weaponInRangeOfRoadbase(weapon) then
					if weaponCategory == 1 then
						if punisher.missileEnums[weaponMissileCategory] then
							util.logInfo("punisher monitoring new missile %s", weapon:getTypeName())
							punisher.monitorWeapon(groupId, playerName, weapon)
						end
					else
						if punisher.weaponEnums[weaponCategory] then
							util.logInfo("punisher monitoring new weapon %s", weapon:getTypeName())
							punisher.monitorWeapon(groupId, playerName, weapon)
						end
					end
				end
			end
		end
	end

	if event.id == world.event.S_EVENT_HIT then
		if event.initiator then
			if event.initiator.getPlayerName ~= nil and event.target:inAir() == false then
				if event.initiator:getGroup() ~= nil then
					local unit = event.initiator
					local groupId = unit:getGroup():getID()
					local playerName = unit:getPlayerName()
					local isCannons = event.weapon and event.weapon:getDesc().category == 0
					if isCannons and punisher.objectInZone(event.target) then
						util.msgToGroup(groupId, 10, "%s, Attacking Roadbases Is Forbidden! Read The FAQ!", playerName)
						trigger.action.explosion(unit:getPoint(), 100)
						dcsbot.punish("roadbase-attack", playerName)
					end
				end
			end
		end
	end

	if event.id == world.event.S_EVENT_MARK_ADDED then
		usedMarkIds[event.idx] = event.idx
	end
end

world.addEventHandler(punisher)

util.logInfo("punisher.lua has loaded successfully")