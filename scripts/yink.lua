
--[[

Documentation

two different libraries: util and csar


util libraries:

util.split(string you want to split, pattern you want to split on)
works like a python string.split

util.distance(unit1, unit2)
basic x,y distance formula for convenience
2 optional arguments present will use manual coordinates

util.save(side, pat) --SIDE_##_TYPE
save FARPS/Invisible FARPS/Roadbases etc to a list and return it. 
base must follow the SIDE_##_TYPE naming convention. e.g. RED_01_ROAD or BLUE_23_FARP. 
Any of the values can be anything, but must be seperated by 2 underscores.

util.closestBase(unit, base list)
takes a Unit object and list of farp/roadbase statics generated from util.save, then finds the closest one
the base list is a list of lists, e.g. {farps, roadbases}. even if its just one list, must be encapsulated in a list, e.g. {farps}


csar libraries:

csar.closestCSAR(unit, csarList)
takes in the heli unit and a list of unit names that are CSAR units.
default list is csar.activeUnits, appended to during the S_EVENT_LANDING_AFTER_EJECTION
returns a table with the closest CSAR object's name and the distance

csar.loop({unit, csarList, ID}, time)
use a function scheduler to do several csar functions
finds and picks up the closest unit if under 50m, then adds it to the heli's list and deletes the unit
it also generates a smoke and flare if a helicopter comes close to it, regardless of side (can be changes easily)


event handlers:

S_EVENT_LANDING_AFTER_EJECTION
takes the ejected pilot when he lands and deletes him, replaced by soldier as a stand in for the pilot
red pilots broadcast on 120.5, blue on 31.05

S_EVENT_BIRTH
sets variables for new aircraft and helicopters

S_EVENT_TAKEOFF
see code for details

S_EVENT_LAND
see code for details

]]--

csarMaxPassengers = {}--delete later
csarMaxPassengers["Mi-24P"] 		= 3
csarMaxPassengers["UH-1H"]			= 14
csarMaxPassengers["Mi-8MT"]			= 14
csarMaxPassengers["Mi-8MTV2"]		= 14
csarMaxPassengers["SA342Mistral"]	= 2
csarMaxPassengers["SA342Minigun"]	= 3
csarMaxPassengers["SA342L"]			= 3
csarMaxPassengers["SA342M"]			= 3


local f=io.open(lfs.writedir() .. 'Scripts/net/DCSServerBot/DCSServerBot.lua',"r")

if f~=nil then
	f:close()
	dofile(lfs.writedir() .. 'Scripts/net/DCSServerBot/DCSServerBot.lua')
	dofile(lfs.writedir() .. 'Scripts/net/DCSServerBot/creditsystem/mission.lua')	
end
------------------------------------------------------------------------------------------------------------------------ util Function Definitions

--[[
util

several functions for specific mission use or for certain actions
]]--


util = {}
util.activeAC = {}
util.type = { 4000, 500 }
util.isLanded = {}
util.checkFC3 = {}


util.targetExceptions = {}
util.targetExceptions["blue supply"] 		= true
util.targetExceptions["blue_01_farp"] 		= true
util.targetExceptions["blue_00_farp"] 		= true
util.targetExceptions["red farp supply"] 	= true
util.targetExceptions["red_00_farp"] 		= true
util.targetExceptions["blufor farp"] 		= true
util.targetExceptions["blue_"] 				= true
util.targetExceptions["static farp"] 		= true
util.targetExceptions["static windsock"] 	= true
util.targetExceptions["red supply"]	 		= true
util.targetExceptions["red_"]	 			= true

function util.inEnemyZone(unit)
	
	local frontline = trigger.misc.getUserFlag("frontline")
	local coa = unit:getCoalition()
	local pos = unit:getPoint()
	local dir
	
	for i = 1, 30 do

		local SectorGroup = ZONE_POLYGON:FindByName( "Sector " .. tostring( i ) )	
		local inSector = SectorGroup:IsVec3InZone(pos)
		
		if inSector then
			if coa == 1 then
				if i <= frontline then return true end
			elseif coa == 2 then
				if i > frontline then return true end
			end 
		end
		
	end
	
	return false
end

--[[
util.split

first parameter: string to split
second parameter: pattern to split on
functionally a simple string splitter

returns a table of strings split on the second parameter inputted

e.g. util.split("red_01_farp", "_") would output {"red","01","farp"}
]]--


function util.split(pString, pPattern) --string.split
   local Table = {}
   local fpat = "(.-)" .. pPattern
   local last_end = 1
   local s, e, cap = pString:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
     table.insert(Table,cap)
      end
      last_end = e+1
      s, e, cap = pString:find(fpat, last_end)
   end
   if last_end <= #pString then
      cap = pString:sub(last_end)
      table.insert(Table, cap)
   end
   return Table
end

--[[
util.distance

first parameter: first unit
second parameter: unit to measure to

finds the distance between two dcs objects
]]--

function util.distance( unit1 , unit2) --use z instead of y for getPoint()
	
		local x1 = unit1:getPoint().x
		local y1 = unit1:getPoint().z
		local x2 = unit2:getPoint().x
		local y2 = unit2:getPoint().z

	return math.sqrt( (x2-x1)^2 + (y2-y1)^2 )
end

function util.distanceVec3Point( pos1 , pos2) --use z instead of y for getPoint()

		local x1 = pos1.x
		local y1 = pos1.z
		local x2 = pos2.x
		local y2 = pos2.z

	return math.sqrt( (x2-x1)^2 + (y2-y1)^2 )
end

--[[
util.round

first parameter: any number
second parameter: number of decimal places to round to

returns a number rounded to the number of decimal places specified
]]--

function util.round(num, numDecimalPlaces)

	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

--[[
util.count

first parameter: table to count number of key/value pairs

if the n value of a table isnt specified (when you dont use table.insert), will count the number of key/value pairs
returns that value
]]--

function util.count(t)
	local i = 0
	for k, v in next, t do
		i = i + 1
	end
	return i
end

--[[
util.save

first parameter: coalition to filter
second parameter: pattern to filter

used specifically with the naming convention SIDE_##_TYPE

will build a table of static objects that are counted as airbase objects (farps/invisible farps) with the pattern as the 3rd split table value
returns that table
]]--

function util.save(side, pat) --SIDE_##_TYPE
	
	local SIDE 	= 1 --definitions for static name
	local N		= 2
	local TYPE 	= 3
	local c 	= 0
	
	ct = { red = 1, blue = 2}
	if side ~= "neut" then
		c = ct[side]
	end
	
	local staticTable = coalition.getAirbases(c)
	local staticGroups = {}
	
	if pat == nil then -- return normal airbases
		for k, v in next, staticTable do
			if v.category == 0 then
				table.insert(staticGroups, v:getName())
			end
		end
	else
		if #staticTable >= 1 then --append statics to group list
			for k, v in next, staticTable do
				local staticParams = util.split(v:getName(),"_") --split static name into 3 parts from SIDE_##_TYPE
				if staticParams[TYPE] ~= nil then
					if util.split(staticParams[TYPE],"-")[1] == pat then
						table.insert(staticGroups, v:getName()) --append static to group list
					end
				end
			end
		end
	end
	
	return staticGroups
end

--[[
util.closestBase

first parameter: unit to measure from
second parameter: table of farp/roadbase object names

will find the closest object to that unit
returns a table of the objectName and the distance in meters
]]--

function util.closestBase(unit, bList) --argument is lists of applicable base types, e.g. farps, roadbases. must be a list of objects

	local c 	= unit:getCoalition()
	local dis	= 99999999
	local i		= -1
	local obj, base
	
	for _, bases in next, bList do -- for each list in {bList}, e.g. {roadbases, farps}
		for k, v in next, bases do -- for each in list of static objects
			base = StaticObject.getByName(v)
			if true then--c == base:getCoalition() then
				i = util.distance(unit, base)
				if i < dis then
					obj = v
					dis = i
				end
			end	
		end
	end
	return {objectName = obj, distance = dis} --return the object and the distance
end

function util.closestEnemyAirbase(unit)
	
	local c 	= unit:getCoalition()
	local dis	= 99999999
	local i		= -1
	local closest, base, distance
	
	for _, base in next, world.getAirbases() do --farps
		if base:getCategory() ~= 0 then
			if base:getCoalition() ~= unit:getCoalition() then
				distance = util.distanceVec3Point(base:getPoint(), unit:getPoint())
				if distance < dis then
					closest = base
					dis = distance
				end
			end
		end
	end
	
	for _, base in next, world.getAirbases() do --airbases
		if base:getCategory() == 0 then
			if base:getCoalition() ~= unit:getCoalition() and #base:getRunways() > 0 then
				distance = util.distanceVec3Point(base:getRunways()[1].position, unit:getPoint())
				if distance < dis then
					closest = base
					dis = distance
				end
			end
		end
	end
	
	return {base = closest, distance = dis}
end

--[[
util.delete

first parameter: unitName to delete
second parameter: time - no use

always returns nil in case a scheduler was used
]]--


function util.delete(unitName, time)
	local unit = Unit.getByName(unitName)
	if unit ~= nil then
		unit:destroy()
	end
	return nil
end

function util.deleteGroup(groupName, time) --delete a group
	local group = Group.getByName(groupName)
	if group ~= nil then
		group:destroy()
	end
	return nil
end

function util.deleteExfilGroup(groupName, time) --initial call for deleting an exfil group. if it smoked, will not delete on this call
	local group = Group.getByName(groupName)
	if group ~= nil and not infantry.exfilSmoked[groupName] then
		group:destroy()
	end
	return nil
end

--[[
util lists

uses util.save to compile the farps and roadbases defined in the .miz, and saves to the allBases list
]]--

--[[
util.checkSpeed

first parameter: unit to check speed of

converts unit's velocity vector to m/s
retuns speed value in m/s
]]--

function util.checkSpeed(unit)
	
	local vec3 = unit:getVelocity()
	local speed = math.sqrt((vec3.x^2) + (vec3.y^2) + (vec3.z^2))
	return speed
end

--[[
util.checkFC3Takeoff

first parameter: unit to check takeoff
first parameter: time argument for scheduler

used to check FC3 takeoffs at roadbases when a landing event wasnt fired for them
when the primary block is true, starts the landing check scheduler and stops the takeoff loop
can be used for any aircraft in the future
if normal takeoff events are detected, then the scheduler stops

retuns time argument + 15 for scheduler
]]--

function util.checkFC3Takeoff(unit, time)
	
	if unit == nil then
		return nil
	end
	
	if util.activeAC[unit:getName()] == true then --if in the air cancel loop
		util.isLanded[unit:getName()] = false
		return nil
	end
	
	local speed = util.checkSpeed(unit)
	
	if speed > 30 and not util.activeAC[unit:getName()] and unit:inAir() then
		local closestBase = util.closestBase(unit, allBases)
		util.activeAC[unit:getName()] = true
		attrition.modify(unit:getName(), 1)
		util.isLanded[unit:getName()] = false
		trigger.action.outTextForGroup(unit:getGroup():getID(),"You have taken off from "..tostring(closestBase.objectName)..".",5)
		timer.scheduleFunction(util.checkFC3Landing, unit, timer.getTime() + 3)
		return nil
	end
	
	--trigger.action.outText("fc3 takeoff check active", 10)
	return time + 15
end

--[[
util.checkFC3Landing

first parameter: unit to check landing
first parameter: time argument for scheduler

used to check FC3 landings at roadbases because landing events arent fired when not at airbases
when the primary block is true, starts the takeoff check scheduler and stops the landing loop
can be used for any aircraft in the future
if normal landing events are detected, then the scheduler stops

retuns time argument + 15 for scheduler
]]--

function util.checkFC3Landing(unit, time)
	
	if not unit:isExist() then
		return nil
	end
	
	if util.activeAC[unit:getName()] == false then --if landed at a friendly base
		util.isLanded[unit:getName()] = true
		return nil
	end
	
	local speed = util.checkSpeed(unit)
	
	if speed < 10 and util.activeAC[unit:getName()] and not unit:inAir() then
		local closestBase = util.closestBase(unit, allBases)
		if closestBase.distance < util.type[tonumber(unit:getGroup():getCategory()) + 1] then
			util.activeAC[unit:getName()] = false
			attrition.modify(unit:getName(), -1)
			util.isLanded[unit:getName()] = true
			trigger.action.outTextForGroup(unit:getGroup():getID(),"You have landed at "..tostring(closestBase.objectName)..".",5)
			timer.scheduleFunction(util.checkFC3Takeoff, unit, timer.getTime() + 3)
			return nil
		end
	end
	
	--trigger.action.outText("fc3 landing check active", 10)
	return time + 15
end

function util.addUserPoints(name,points)
	
	if dcsbot then
		if dcsbot.addUserPoints then
			dcsbot.addUserPoints(name,points)										
			log.write("scripting", log.INFO, "util.addUserPoints: "..tostring(points).." added for "..name)		
			return {name, points}
		else
			log.write("scripting", log.INFO, "util.addUserPoints: dcsbot.addUserPoints function missing!")	
			return nil
		end
	else
		log.write("scripting", log.INFO, "util.addUserPoints: dcsbot table missing!")	
		return nil
	end

end

util.rRbs 	= util.save("red","ROAD")
util.rFarps = util.save("red","FARP")
util.rAbs	= util.save("red", nil)

util.bRbs 	= util.save("blue","ROAD")
util.bFarps = util.save("blue","FARP")
util.bAbs	= util.save("blue", nil)

allBases	= {util.rRbs, util.rFarps, util.rAbs, util.bRbs, util.bFarps, util.bAbs}

--local x		= util.closestBase(coalition.getPlayers(1)[1],{rbs})

--trigger.action.outText(tostring(x.distance),5)

function util.passengerCount(heliName)
	return csar.heliPassengers[heliName]["n"] + (tonumber(infantry.heliSquads[heliName]) * 4) + (tonumber(infantry.reconSquads[heliName]) * 2)
end


------------------------------------------------------------------------------------------------------------------------CSAR Function Definitions

--[[
csar

main functions for csar use
]]--

csar = {}
csar.redUnits		= {}
csar.blueUnits		= {}
csar.activeUnits 	= {}
csar.heliPassengers	= {}
csar.alreadySmoked	= {}
csar.alreadyFlared	= {}
csar.transmitting	= {}

--[[
csar.closestCSAR

1st parameter: unit to measure off of
2nd parameter: table of unit names to be searched for
returns a table of closest object name, distance, and the list used.
used for csar measuring but can be used with any list of unit namse.
]]--

function csar.closestCSAR(unit, csarList) --argument is lists of applicable base types, e.g. farps, roadbases. must be a list of objects

	local c 	= unit:getCoalition()
	local dis	= 99999999
	local i		= -1
	local obj, base
	
	for k, cUnit in next, csarList do -- for each list in {bList}, e.g. {roadbases, farps}
		
		if Unit.getByName(cUnit) == nil then --remove unit from list if it doesnt exist
			csarList[k] = nil
			trigger.action.stopRadioTransmission(cUnit)
		else
			i = util.distance(unit, Unit.getByName(cUnit))
			if i < dis then
				obj = cUnit
				dis = i
			end
		end
	end
	return {objectName = obj, distance = dis, list = csarList} --return the object and the distance
end

--[[
csar.loop

1st parameter: table of {heli target unit, CSAR list to loop on, id of unit}
2nd parameter: time inherited from scheduler

this function acts as the main control loop for helicopters during csar operations. if the heli dies/stops existing, loop will return nil

first block checks heli speed and distance, and if true will add the CSAR object name to a nested list (named after the heli unit)

it then checks if the unit has already thrown smoke and flare, and sets control variables accordingly

if the control variables are false and unit is in range, will pop smoke/flare

]]--

function csar.loop(args, time) --timer.scheduleFunction(csar.loop, {event.initiator, csar.activeUnits, event.initiator:getID()}, timer.getTime())
	
	local unit 			= args[1]
	local csarList 		= args[2]
	local id 			= args[3]
	

	if not unit:isExist() then
		--trigger.action.outText(tostring(id).." removed from heli csar loop by not existing",5)
		return nil
	elseif unit:getCategory() ~= 1 then
		--trigger.action.outText(tostring(id).." removed from heli csar loop by category",5)
		return nil
	end
	
	if unit:getID() ~= id then
		return nil
	end
	
	local throwSmoke 		= true
	local throwFlare		= true
	local transmitting		= false
	local closestCSAR 		= csar.closestCSAR(unit, csarList)
	local closestInfantry 	= infantry.closestExfilSquad(unit:getName())
	local closest			= {}
	local smokeColor 		= {1,4}

	if closestCSAR.distance < closestInfantry.distance then
		closest = closestCSAR
	else
		closest = closestInfantry
	end
	
	
	if util.checkSpeed(unit) < 2 then
		
		if closestCSAR.distance < 100  and closest == closestCSAR then --csar conditional
			local passengerCount = util.passengerCount(unit:getName())
			
			if passengerCount < csarMaxPassengers[unit:getTypeName()] then
				csar.heliPassengers[unit:getName()][closestCSAR.objectName] = Unit.getByName(closestCSAR.objectName):getCoalition() --add csar unit to heli's dictionary
				csar.heliPassengers[unit:getName()]["n"] = csar.heliPassengers[unit:getName()]["n"] + 1
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Pilot extracted! Seats remaining: "..tostring(csarMaxPassengers[unit:getTypeName()] - csar.heliPassengers[unit:getName()]["n"]),10)
				if Unit.getByName(closestCSAR.objectName):getCoalition() == 1 then
					csar.redUnits[closestCSAR.objectName] = nil
				else
					csar.blueUnits[closestCSAR.objectName] = nil
				end
				Unit.getByName(closestCSAR.objectName):destroy()
				csar.alreadySmoked[closestCSAR.objectName] = nil
				csar.alreadyFlared[closestCSAR.objectName] = nil
				
			else
				trigger.action.outTextForGroup(unit:getGroup():getID(),"You're full with "..tostring(csarMaxPassengers[unit:getTypeName()] - csar.heliPassengers[unit:getName()]["n"]).." passengers.",10)
			end
			
			
			
		elseif closestInfantry.distance < 100 and closest == closestInfantry then
		
		
			if util.split(closestInfantry.groupName,"_")[1] == 'reconInfantry' and recon.helicopters[unit:getTypeName()] then --recon section
			
				local passengerCount = util.passengerCount(unit:getName())
				local reconGroup = Group.getByName(closestInfantry.groupName)
				local reconGroupSquadCount = (#reconGroup:getUnits()) / 2
				local count = 0
				if passengerCount < csarMaxPassengers[unit:getTypeName()] then
			
					local availableSeats = (csarMaxPassengers[unit:getTypeName()] - passengerCount) / 2
					
					if availableSeats >= reconGroupSquadCount then
						infantry.reconSquads[unit:getName()] = infantry.reconSquads[unit:getName()] + reconGroupSquadCount
					else
						infantry.reconSquads[unit:getName()] = (csarMaxPassengers[unit:getTypeName()] - passengerCount) / 2
					end
					
					count = recon.returnReconTargetsFromList(unit:getCoalition(),recon.lists[closestInfantry.groupName], -1)
					
					util.addUserPoints(unit:getPlayerName(), reconGroupSquadCount * 2)
					
					trigger.action.outTextForCoalition(unit:getCoalition(),unit:getPlayerName() .. " gathered intel on " .. tostring(count) .. " targets.",8)
					trigger.action.outTextForUnit(unit:getID() , "You received " .. tostring(reconGroupSquadCount * 2) .. " credits for reconnaissance." , 8)
					
					infantry.exfilSquads[closestInfantry.groupName] = nil
					reconGroup:destroy()
					passengerCount = util.passengerCount(unit:getName())
					
					trigger.action.outTextForGroup(unit:getGroup():getID(),"Recon Exfil Complete! Seats remaining: "..tostring(csarMaxPassengers[unit:getTypeName()] - passengerCount),10)
				else
					trigger.action.outTextForGroup(unit:getGroup():getID(),"You're full with "..tostring(passengerCount).." passengers.",10)
				end
				
			elseif util.split(closestInfantry.groupName,"_")[1] == 'infantry' and not recon.helicopters[unit:getTypeName()] then --normal section
		
				local passengerCount = util.passengerCount(unit:getName())
				local infantryGroup = Group.getByName(closestInfantry.groupName)
				local infantryGroupSquadCount = (#infantryGroup:getUnits()) / 4
				local counter = 0
				if passengerCount < csarMaxPassengers[unit:getTypeName()] then
				
					local availableSeats = (csarMaxPassengers[unit:getTypeName()] - passengerCount) / 4
					
					if availableSeats >= infantryGroupSquadCount then
						infantry.heliSquads[unit:getName()] = infantry.heliSquads[unit:getName()] + infantryGroupSquadCount
					else
						infantry.heliSquads[unit:getName()] = (csarMaxPassengers[unit:getTypeName()] - passengerCount) / 4
					end
					
					infantry.exfilSquads[closestInfantry.groupName] = nil
					infantryGroup:destroy()
					passengerCount = util.passengerCount(unit:getName())
					
					trigger.action.outTextForGroup(unit:getGroup():getID(),"Exfil Complete! Seats remaining: "..tostring(csarMaxPassengers[unit:getTypeName()] - passengerCount),10)
				else
					trigger.action.outTextForGroup(unit:getGroup():getID(),"You're full with "..tostring(passengerCount).." passengers.",10)
				end
			end
		end
	end
	
	for k, v in next, csar.alreadySmoked do --if the unit already threw a smoke
		if v == closestCSAR.objectName then
			throwSmoke = false
		end
	end
	
	for k, v in next, csar.alreadyFlared do --if the unit already threw a smoke
		if v == closestCSAR.objectName then
			throwFlare = false
		end
	end
	
	if closestInfantry.distance < 3000 then
		trigger.action.signalFlare(Group.getByName(closestInfantry.groupName):getUnits()[1]:getPoint() , 0 , math.random(1,360) )
		
		if not infantry.exfilSmoked[closestInfantry.groupName] then
			timer.scheduleFunction(util.deleteGroup, closestInfantry.groupName, timer.getTime() + 300)
		end
		infantry.exfilSmoked[closestInfantry.groupName] = true
		
	end
	
	if throwSmoke then --if the unit can throw its initial smoke still
		if closestCSAR.distance < 2000 then
			local csarUnit = Unit.getByName(closestCSAR.objectName)
			table.insert(csar.alreadySmoked, closestCSAR.objectName)
			--trigger.action.smoke(csarUnit:getPoint(), smokeColor[csarUnit:getCoalition()])
		end
	end
	
	if true then --throwFlare then --if the unit can throw its initial smoke still
		if closestCSAR.distance < 4000 then
			local csarUnit = Unit.getByName(closestCSAR.objectName)
			--table.insert(csar.alreadyFlared, closestCSAR.objectName)
			trigger.action.signalFlare(csarUnit:getPoint() , 2 , math.random(1,360) )
		end
	end
	return time+10
end

--[[
csar.closer

used for the lua method table.sort to sort low -> high
]]--

function csar.closer(first, second)
	return first < second
end

--[[
util.binSearch

recursive binary search algorithm
]]

function util.binSearch(array, item, low, high)
	
	if high <= low then
		return ((item > array[low]) and (low+1) or low)
	end

	local mid = math.floor((low+high)/2)

	if item == array[mid] then return mid+1 
	elseif item > array[mid] then return util.binSearch(array, item, mid+1, high)
	else return util.binSearch(array, item, low, mid-1) end

end

--[[
util.bearing

utility function for finding bearing between to vec3 points
]]

function util.bearing(vec3A, vec3B)
	local azimuth = math.atan2(vec3B.z - vec3A.z, vec3B.x - vec3A.x)
	return azimuth<0 and math.deg(azimuth+2*math.pi) or math.deg(azimuth)
end

--[[
util.bearingUnit

util.bearing wrapper for DCS Unit arguments
]]

function util.bearingUnit(unitA, unitB)
	return util.bearing(unitA:getPoint(),unitB:getPoint())
end

--[[
csar.closestF10

1st parameter: name of unit to measure from

this function lists for the calling unit the closest friendly CSAR units
first it puts all friendly csar units into a list via the csar.closestCSAR function and a list of red/blue csar units
then it puts all the csar units into a dictionary with k/v pairs being unitname/distance
it sorts the list low -> high then builds a string to be output to the player
]]--

function csar.closestF10old(unitName)	--deprac

	local unit = Unit.getByName(unitName)
	local closestCSARFriendly
	local alreadyAdded = {}
	local outString = ""
	
	if unit:getCoalition() == 1 then
		closestCSARFriendly = csar.closestCSAR(unit, csar.redUnits)
	else
		closestCSARFriendly = csar.closestCSAR(unit, csar.blueUnits)
	end
	
	local closestCSARList = closestCSARFriendly.list
	
	if util.count(closestCSARList) <= 0 then
		trigger.action.outTextForGroup(unit:getGroup():getID(),"No friendly CSAR Units!",15)
		return nil
	end
	
	local unitPoint = unit:getPoint()
	local csarPoint = Unit.getByName(closestCSARFriendly.objectName):getPoint()
	
	for k, v in next, closestCSARList do
		local csarUnit = Unit.getByName(v)
		alreadyAdded[v] = util.distance(csarUnit, unit)
	end
	
	table.sort(alreadyAdded, csar.closer)
	
	trigger.action.outTextForGroup(unit:getGroup():getID(),"Closest Friendly CSAR Units:",15)
	
	for k, v in next, alreadyAdded do
		local csarPoint = Unit.getByName(k):getPoint()
		local range = util.round(util.distance(Unit.getByName(k), unit)/1000,1)
		local angle = math.atan2(csarPoint.z - unitPoint.z, csarPoint.x - unitPoint.x) * 180 / math.pi
		if angle < 0 then
			angle = 360 + angle
		end
		angle = util.round(angle, 0)
		local angleString = tostring(angle)
		if angle < 100 then
			angleString = "0" .. tostring(angle)
		elseif angle < 10 then
			angleString = "00" .. tostring(angle)
		end
		outString = outString .. tostring(k)..": ".. angleString.." for "..tostring(range).." kilometers.\n"
	end
	trigger.action.outTextForGroup(unit:getGroup():getID(),outString,15)
	return nil
end

function csar.closestF10(unitName)

	local searchUnit = Unit.getByName(unitName)
	local inList = nil
	if searchUnit:getCoalition() == coalition.side.RED then
		inList = csar.redUnits
	else
		inList = csar.blueUnits
	end

	if next(inList) == nil then
		trigger.action.outTextForGroup(searchUnit:getGroup():getID(),"No friendly CSAR Units!",15)
		return
	end

	local outList = {}

	local passengermt = {
		__le = function(a,b)
			return a.distance <= b.distance
		end,

		__lt = function(a,b)
			return a.distance < b.distance
		end,

		__eq = function(a,b)
			return a.distance == b.distance
		end
	}

	for ind, name in pairs(inList) do
		
		local targetUnit = Unit.getByName(name)
		if targetUnit ~= nil then
			local passenger = {}
			passenger.name = name
			passenger.distance = util.distance(searchUnit,targetUnit)
			passenger.bearing = util.bearingUnit(searchUnit,targetUnit)
			setmetatable(passenger,passengermt)
			if next(outList) == nil then outList[1] = passenger
			else table.insert(outList,util.binSearch(outList,passenger,1,#outList),passenger) end
		end
	end
	
	if #outList <= 0 then
		trigger.action.outTextForGroup(searchUnit:getGroup():getID(),"No friendly CSAR Units!",15)
		return
	end
	
	trigger.action.outTextForGroup(searchUnit:getGroup():getID(),"Closest Friendly CSAR Units:",15)

	local output = ""
	
	if searchUnit:getCoalition() == coalition.side.RED then
		for i,passenger in ipairs(outList) do
			output = output..string.format("%s: %03.0f for %1.1f km\n",passenger.name,passenger.bearing,passenger.distance/1000)
		end
	else
		for i,passenger in ipairs(outList) do
			output = output..string.format("%s: %03.0f for %1.1f nm\n",passenger.name,passenger.bearing,passenger.distance/1852)
		end
	end
	
	trigger.action.outTextForGroup(searchUnit:getGroup():getID(),output,15)

end
------------------------------------------------------------------------------------------------------------------------Attrition Function Definitions

--[[
attrition

attrition.valueBlue and attrition.valueRed are the starting attrition values for red/blue, and will be added/subtracted to as people takeoff/land/csar recover
attrition.scaleValue is what the difference of attrition scales on. setting to 0 will effectively disable attrition
attrition.baseWeight is what is used if the script cant find the typename inside of aircraftWeights
attrition.rescueWeight is the CSAR return value
]]--

attrition = {}

attrition.debug = false

attrition.valueBlue = 10
attrition.valueRed = 10
attrition.initialValueBlue = attrition.valueBlue
attrition.initialValueRed = attrition.valueRed
attrition.scaleValue = attritionScale
attrition.redCSAR = 0
attrition.blueCSAR = 0


attrition.sideTable = { attrition.valueRed, attrition.valueBlue }

attrition.aircraftWeights = {}

attrition.aircraftWeights["A-10A"]			= 1.25
attrition.aircraftWeights["F-86F Sabre"]	= 0.85
attrition.aircraftWeights["F-5E-3"] 		= 1.20
attrition.aircraftWeights["AJS37"] 			= 1
attrition.aircraftWeights["F-14A-135-GR"] 	= 7
attrition.aircraftWeights["C-101CC"] 		= 0.8
attrition.aircraftWeights["MB-339A"] 		= 0.8
attrition.aircraftWeights["UH-1H"] 			= 0.7
attrition.aircraftWeights["SA342M"] 		= 0.70
attrition.aircraftWeights["SA342L"] 		= 0.70
attrition.aircraftWeights["SA342Minigun"] 	= 0.70
attrition.aircraftWeights["SA342Mistral"] 	= 0.70
attrition.aircraftWeights["Su-25"] 			= 0.90
attrition.aircraftWeights["MiG-15bis"] 		= 0.65
attrition.aircraftWeights["MiG-19P"] 		= 0.85
attrition.aircraftWeights["MiG-21Bis"] 		= 1.20
attrition.aircraftWeights["MiG-29A"] 		= 5.50
attrition.aircraftWeights["L-39ZA"] 		= 0.80
attrition.aircraftWeights["Mi-24P"] 		= 0.9
attrition.aircraftWeights["Mi-8MT"] 		= 0.7
attrition.aircraftWeights["Mi-8MTV2"] 		= 0.7
attrition.aircraftWeights["Mirage-F1CE"]	= 1.25


attrition.baseWeight = 1
attrition.rescueWeight = 0.6

--[[
attrition.reset

resets the attrition values back to their original values. currently used on frontline movement
]]--

function attrition.reset()
	attrition.valueBlue = attrition.initialValueBlue
	attrition.valueRed = attrition.initialValueRed
	attrition.sideTable = { attrition.valueRed, attrition.valueBlue }
	--maybe delete csar units?
end

--[[
attrition.calculate

calculate the frontline movement threshold for the current leading team
formula is basically ((5% - scaleValue) + (attrition ratio * scaleValue))
returns the actual point requirement
]]--

function attrition.calculate()

	local ratio = 0
	local valueRed = attrition.sideTable[1]
	local valueBlue = attrition.sideTable[2]
	
	if RedLives == nil or BlueLives == nil then
		return 50
	end
	
	if RedLives > BlueLives then
		ratio = valueRed / valueBlue
	else
		ratio = valueBlue / valueRed
	end	
	local modifier = ratio * attrition.scaleValue --scale ratio to the scale value
	local newFLT = ((FrontlineMoveThreshold / BlueMaxLives) * 100) -- default: (50/1000) * 100 = 5
	newFLT = newFLT - attrition.scaleValue --default: 5 - scaleValue
	newFLT = modifier + newFLT
	local newFLTPercentage = newFLT / 100
	
	return newFLTPercentage * BlueMaxLives -- % * 1000 = new value
	
end

--[[
attrition.modify

first parameter: name of unit that took off/landed
second parameter: value to multiply to the aircraft's weight and add to team's attrition. negative values will subtract
returns value added/subtracted
]]--

function attrition.modify(unitName, modifier)
	local unit 		= Unit.getByName(unitName)
	local coa		= unit:getCoalition()
	local weight	= attrition.aircraftWeights[unit:getTypeName()]
	
	if weight ~= nil then
		weight = attrition.baseWeight * weight
	else
		weight = attrition.baseWeight
	end

	attrition.sideTable[coa] = attrition.sideTable[coa] + (weight * modifier)
	return (weight * modifier)
end

--[[
attrition.ejection

first parameter: coalition that the ejected unit belonged to
adds the csar value to the team if the aircraft ejected while landed at a friendly base
]]--

function attrition.ejection(coa, modifier)
	attrition.sideTable[coa] = attrition.sideTable[coa] + (attrition.rescueWeight * modifier)
end

--[[
attrition.csarReturn

first parameter: unit name of helicopter that is returning csar units
adds each csar unit in cargo to a red/blue value

currently just subtracts points from the unit's coalition based on how many red/blue CSAR are returned

returns the number of red and blue csar returned in a table
]]--

function attrition.csarReturn(unitName)
	local t 		= csar.heliPassengers[unitName]
	local unit 		= Unit.getByName(unitName)
	local coa		= unit:getCoalition()
	local red, blue = 0,0
	
	for k, v in next, t do
		if k ~= "n" then
			if v == 1 then
				red = red + 1
			elseif v == 2 then
				blue = blue + 1
			end
		end
	end
	if coa == 1 then
		attrition.redCSAR 	= attrition.redCSAR + red + blue
	elseif coa == 2 then
		attrition.blueCSAR 	= attrition.blueCSAR + blue + red
	end
	
	attrition.sideTable[coa] = attrition.sideTable[coa] - ((red + blue) * attrition.rescueWeight)
	util.addUserPoints(unit:getPlayerName(),(red+blue))
	return {red, blue}
end

------------------------------------------------------------------------------------------------------------------------Infantry drop Definitions

--[[
infantry

functions for infantry deployment

heliSquads is a dictionary to store Heli/#of squads
hasCommands is for adding f10 menu options to groups that dont have them yet
]]--

infantry = {}
infantry.heliSquads = {}
infantry.reconSquads = {}
infantry.dropEnabled = {}
infantry.hasCommands = {}
infantry.exfilSquads = {}
infantry.exfilSmoked = {}
infantry.alwaysAllowPickup = {"00"}
infantry.blueCounter = 0
infantry.redCounter = 0

--[[
infantry.load

first parameter: name of helicopter trying to load

first section determines if the helicopter is trying to load infantry at farps/roadbases at/past the frontline
it then makes sure the heli is not loading at anywhere at the frontline (for airbase workaround)

after calculating seats into passengerCount, it makes sure there is enough room to load another squad

will always return nil for now
]]--

function infantry.closestExfilSquad(unitName) -- appended to csar loop, uses world.searchobjects to find close infantry groups for smoke and exfil purpose

	
	local unit = Unit.getByName(unitName)
	local group
	
	local volume = {
		id = world.VolumeType.SPHERE,
		params = {
			point = Unit.getByName(unitName):getPoint(),
			radius = 3000
		}
	}
	
	local foundList = {}
	
	local ifFound = function(foundItem) --function to run when target is found in world.searchObjects
	
		if (foundItem:getGroup():getCategory() == 2 and foundItem:getCoalition() == Unit.getByName(unitName):getCoalition() and foundList[foundItem:getGroup():getName()] == nil) then
			
			if infantry.exfilSquads[foundItem:getGroup():getName()] then
				foundList[foundItem:getGroup():getName()] = util.distance(unit, foundItem)
				infantry.exfilSmoked[foundItem:getGroup():getName()] = false
			end
		end
	end
	
	world.searchObjects(Object.Category.UNIT , volume , ifFound)
	
	closestGroup = ""
	closestDistance = 9999999

	for groupName, distance in next, foundList do
		if distance < closestDistance then
			closestGroup = groupName
			closestDistance = distance
		end
	end
	
	return {distance = closestDistance, groupName = closestGroup}
	
end

function infantry.load(heli)

	local unit = Unit.getByName(heli)
	
	local closestFarp = util.closestBase(unit, {util.rFarps,util.bFarps})
	local closestFarpNum = tonumber(util.split(closestFarp.objectName,"_")[2])
	
	local closestRB = util.closestBase(unit, {util.rRbs,util.bRbs})
	local closestRBNum = tonumber(util.split(closestRB.objectName,"_")[2])

	local closestBase = util.closestBase(unit, {util.rRbs,util.bRbs, util.rFarps,util.bFarps})
	local enemyFrontline = ActiveFrontline + (unit:getCoalition() - 1)
	local friendlyFrontline = ActiveFrontline + math.abs(unit:getCoalition() - 2)
	local pickup, limit = false, enemyFrontline

	if unit:getCoalition() == 1 then
		limit = enemyFrontline + 1-- farp minimum
		if closestFarpNum >= limit and closestBase.objectName == closestFarp.objectName then pickup = true end
		limit = enemyFrontline - 2-- rb minimum
		if closestRBNum >= limit and closestBase.objectName == closestRB.objectName then pickup = true end
	else
		limit = enemyFrontline - 1-- farp minimum
		if closestFarpNum <= limit and closestBase.objectName == closestFarp.objectName then pickup = true end
		limit = enemyFrontline + 2-- rb minimum
		if closestRBNum <= limit and closestBase.objectName == closestRB.objectName then pickup = true end
	end

	local SectorName = "Sector " .. tostring( friendlyFrontline )
	local SectorGroup = ZONE_POLYGON:FindByName( SectorName )
	--local inFriendlyFrontline = SectorGroup:IsVec3InZone(unit:getPoint()) 
	
	for k,v in next, infantry.alwaysAllowPickup do --workaround for first and last farp
		if (util.split(closestFarp.objectName,"_")[2]) == v then
			pickup = true
		end
	end	
	
	if (not pickup) or inFriendlyFrontline then
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Cannot load squads when this close to the frontline!",5)
		return nil
	end	
	
	if unit:getCoalition() ~= StaticObject.getByName(closestBase.objectName):getCoalition() then
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Cannot load squads from an enemy base!",5)
		return
	end
	
	if tonumber(trigger.misc.getUserFlag(closestBase.objectName.."_closureStatus")) == 2 then
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Cannot load squads from a closed Roadbase!",5)
		return
	end

	if not util.activeAC[unit:getName()] and util.isLanded[unit:getName()] then -- if not active, in the air, and next to a farp --SIDE_##_TYPE
		local passengerCount = util.passengerCount(unit:getName())
		
		if recon.helicopters[unit:getTypeName()] then --recon
		
			local reconCount = math.floor((csarMaxPassengers[unit:getTypeName()] - passengerCount)/2)
			
			if reconCount <= 0 then
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Not enough room for a recon squad! Seats needed: ".. tostring(2 - (csarMaxPassengers[unit:getTypeName()] - (passengerCount))),5)
			else
				infantry.reconSquads[unit:getName()] = infantry.reconSquads[unit:getName()] + reconCount
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Loaded ".. tostring(reconCount * 2) .." Recce! Seats remaining: ".. tostring(csarMaxPassengers[unit:getTypeName()] - util.passengerCount(unit:getName())),5)
			end
			
		else --not recon
		
			local squadCount = math.floor((csarMaxPassengers[unit:getTypeName()] - passengerCount)/4)
			
			if squadCount <= 0 then
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Not enough room for a squad! Seats needed: ".. tostring(4 - (csarMaxPassengers[unit:getTypeName()] - (passengerCount))),5)
			else
				infantry.heliSquads[unit:getName()] = infantry.heliSquads[unit:getName()] + squadCount
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Loaded ".. tostring(squadCount * 4) .." Infantry! Seats remaining: ".. tostring(csarMaxPassengers[unit:getTypeName()] - util.passengerCount(unit:getName())),5)
			end
			
		end
	else
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Cannot load squads when not at a friendly base!",5)
	end
	
	infantry.passengers(heli)
	return nil
end

--[[
infantry.load

first parameter: name of helicopter trying to unload

if the heli is at a friendly base, it can unload its troops if it wants to
]]--

function infantry.unload(heli)
	
	local unit = Unit.getByName(heli)
	
	if not util.activeAC[unit:getName()] and util.isLanded[unit:getName()] then
		local passengerCount = util.passengerCount(unit:getName())
		
		
		if infantry.reconSquads[unit:getName()] > 0 then
			infantry.reconSquads[unit:getName()] = infantry.reconSquads[unit:getName()] - 1
			passengerCount = util.passengerCount(unit:getName())
			trigger.action.outTextForGroup(unit:getGroup():getID(),"Unloaded a recon squad! Available seats: ".. tostring(csarMaxPassengers[unit:getTypeName()] - passengerCount),5)
		else
			infantry.reconSquads[unit:getName()] = 0
			trigger.action.outTextForGroup(unit:getGroup():getID(),"No recon squads to unload!",5)
		end
		
		if infantry.heliSquads[unit:getName()] > 0 then
			infantry.heliSquads[unit:getName()] = infantry.heliSquads[unit:getName()] - 1
			passengerCount = util.passengerCount(unit:getName())
			trigger.action.outTextForGroup(unit:getGroup():getID(),"Unloaded an infantry squad! Available seats: ".. tostring(csarMaxPassengers[unit:getTypeName()] - passengerCount),5)
		else
			infantry.heliSquads[unit:getName()] = 0
			trigger.action.outTextForGroup(unit:getGroup():getID(),"No infantry squads to unload!",5)
		end
	else
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Cannot unload squads when not at a friendly base!",5)
	end

	trigger.action.outTextForGroup(unit:getGroup():getID(),"Squads Loaded: ".. tostring(infantry.heliSquads[unit:getName()]),5)
	return nil
end

--[[
infantry.spawn

first parameter: name of helicopter trying to drop troops

this function spawns a group of units based on the number of squads in heliSquads

returns the group name (to insert into the despawn scheduler)
]]--

function infantry.spawn(heliName, ...)
	
	local heli, coa, squadCount, pos, x, y
	
	if arg["n"] == 0 then
										
		log.write("infantry.spawn", log.INFO, heliName .." dropped off troops")	
		heli 		= Unit.getByName(heliName)
		coa 		= heli:getCoalition()
		squadCount 	= infantry.heliSquads[heli:getName()]
		pos 		= heli:getPoint()
		x 			= pos.x
		y 			= pos.z		
		if squadCount <= 0 then
			return nil
		end
		
	else
		log.write("infantry.spawn", log.INFO, "exfil group spawn")	
		heliName 			= heliName .. "_exfil"
		coa 		= arg[1][1]
		squadCount 	= arg[1][2]
		pos 		= arg[1][3]
		x 			= pos.x
		y 			= pos.y
		if squadCount <= 0 then
			return nil
		end
	end
	
	local group 	= {}
	local unit 		= {}	
	if coa == 1 then
		group["country"] 	= country.id.RUSSIA
		unit["type"] 		= "Paratrooper AKS-74"
	elseif coa == 2 then
		group["country"] 	= country.id.USA
		unit["type"] 		= "Soldier M4"
	end		
	group["category"]	= 2
	group["name"] 		= "infantry_".. tostring(coa).."_G_"..tostring(timer.getTime()) .. "_" .. heliName
	group["task"] 		= "Ground Nothing"
	group["units"]		= {}
	
	local unitCount = (4 * squadCount)
	
	for i = 1, unitCount do
	
		group["units"][i] = {}
		group["units"][i]["name"] 		= "infantry_" .. tostring(i) .. "_" .. tostring(timer.getTime()) .. "_" .. heliName
		group["units"][i]["x"] 			= x + (18 * math.cos(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["y"]			= y + (18 * math.sin(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["heading"]	= math.rad((i / unitCount) * 360 )
		group["units"][i]["type"]		= unit["type"]
	end
	returnGroup = coalition.addGroup( group["country"], group["category"] , group )
	return returnGroup:getName()
	
end

function infantry.spawnDebug(point, coa, count)
	
	log.write("infantry.spawn", log.INFO, "DEBUG SPAWN: ".." dropped off troops")	
	heliName 	= "debug"
	squadCount 	= count
	pos 		= point
	x 			= pos.x
	y 			= pos.z		
	if squadCount <= 0 then
		return nilw
	end
	
	local group 	= {}
	local unit 		= {}	
	if coa == 1 then
		group["country"] 	= country.id.RUSSIA
		unit["type"] 		= "Paratrooper AKS-74"
	elseif coa == 2 then
		group["country"] 	= country.id.USA
		unit["type"] 		= "Soldier M4"
	end		
	group["category"]	= 2
	group["name"] 		= "infantry_".. tostring(coa).."_G_"..tostring(timer.getTime()) .. "_" .. heliName
	group["task"] 		= "Ground Nothing"
	group["units"]		= {}
	
	local unitCount = (4 * squadCount)
	
	for i = 1, unitCount do
	
		group["units"][i] = {}
		group["units"][i]["name"] 		= "infantry_" .. tostring(i) .. "_" .. tostring(timer.getTime()) .. "_" .. heliName
		group["units"][i]["x"] 			= x + (18 * math.cos(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["y"]			= y + (18 * math.sin(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["heading"]	= math.rad((i / unitCount) * 360 )
		group["units"][i]["type"]		= unit["type"]
	end
	returnGroup = coalition.addGroup( group["country"], group["category"] , group )
	return returnGroup:getName()
	
end

function infantry.reconSpawn(heliName, ...) --spawn function for recon troops
	
	local heli, coa, squadCount, pos, x, y
	
	if arg["n"] == 0 then
	
		log.write("infantry.reconSpawn", log.INFO, heliName .." dropped off recon")	
		heli 		= Unit.getByName(heliName)
		coa 		= heli:getCoalition()
		squadCount 	= infantry.reconSquads[heli:getName()]
		pos 		= heli:getPoint()
		x 			= pos.x
		y 			= pos.z		
		if squadCount <= 0 then
			return nil
		end
		
	else
	
		log.write("infantry.reconSpawn", log.INFO, "exfil recon group spawn")	
		heliName 			= heliName .. "_exfilRecon"
		coa 		= arg[1][1]
		squadCount 	= arg[1][2]
		pos 		= arg[1][3]
		x 			= pos.x
		y 			= pos.y
		if squadCount <= 0 then
			return nil
		end
	end
	
	local group 	= {}
	local unit 		= {}	
	if coa == 1 then
		group["country"] 	= country.id.RUSSIA
		unit["type"] 		= "Soldier AK"
	elseif coa == 2 then
		group["country"] 	= country.id.USA
		unit["type"] 		= "Soldier M4 GRG"
	end		
	group["category"]	= 2
	group["name"] 		= "reconInfantry_".. tostring(coa).."_G_"..tostring(timer.getTime()) .. "_" .. heliName
	group["task"] 		= "Ground Nothing"
	group["units"]		= {}
	
	local unitCount = (2 * squadCount)
	
	for i = 1, unitCount do
	
		group["units"][i] = {}
		group["units"][i]["name"] 		= "reconInfantry_" .. tostring(i) .. "_" .. tostring(timer.getTime()) .. "_" .. heliName
		group["units"][i]["x"] 			= x + (18 * math.cos(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["y"]			= y + (18 * math.sin(math.rad( (i / unitCount) * 360 )))
		group["units"][i]["heading"]	= math.rad((i / unitCount) * 360 )
		group["units"][i]["type"]		= unit["type"]
	end
	returnGroup = coalition.addGroup( group["country"], group["category"] , group )
	return returnGroup:getName()
	
end
--[[
infantry.despawn

first parameter: argument table of (group to delete, helicopter that dropped troops)

generates of table of enemy units at the frontline generated from the Set from base.lua
it then loops based on troop # and kills random units from the generated table
it then destroys the units from the passed group name

if some of the units are destroyed before this is called, then it will compensate

returns nothing
]]--


function infantry.despawn(args)
	local group = args[1]
	local unit = Unit.getByName(args[2])
	local coa = args[3]
	local name = args[4]
	local roadbase = args[5]
	local debugExfil = args[6]
	local closureSuffix = "_closureStatus"
	local g = Group.getByName(group)
	local unitCount = #g:getUnits()
	
	if #g:getUnits() <= 0 then
		return nil
	end
	local i = math.floor(#g:getUnits() / (4/unitsKilledPerSquad))
	--local groups = ActiveFrontlineGroups
	local groupSelected = false
	local group
	
	if roadbase == nil then
		local foundUnits = {}
		
		local volume = {
			id = world.VolumeType.SPHERE,
			params = {
				point = g:getUnits()[1]:getPoint(),
				radius = infantryRadius
			}
		}
		
		local ifFound = function(foundItem)
			if foundItem:getGroup():getCategory() == 2 and foundItem:getCoalition() ~= coa then
				
				local proceed = true
				local found = nil
				
				for exceptionName, bool in next, recon.targetExceptions do
				found = string.find(string.lower(foundItem:getName()), exceptionName)
				if found ~= nil then
					break
				end
			end
			
				if found == nil then
					table.insert(foundUnits,foundItem)
					return true
				end
				
				return false
			end
		end
		
		world.searchObjects(Object.Category.UNIT , volume , ifFound)
		
		if unit ~= nil then
			trigger.action.outTextForGroup(unit:getGroup():getID(),"enemy units found: "..tostring(util.count(foundUnits)),10)
		end
		
		util.addUserPoints(name,math.ceil(#g:getUnits()/4))
		
		local lastPos = nil
		
		for x = 0, math.floor(i) do
			if foundUnits[x] ~= nil then
				local getFucked = foundUnits[x]
				trigger.action.explosion(getFucked:getPoint(),50)
				lastPos = getFucked:getPoint()
				local n = string.lower(string.sub(getFucked:getTypeName(),1,1))
				local a = n:gsub("[^eyuioaEYUIOA]","")
				if a == "" then n = "" else n = "n" end
				
				if unit ~= nil then
					trigger.action.outTextForGroup(unit:getGroup():getID(),"Your squad killed a".. n .." "..getFucked:getTypeName().."!",10)
				end
				net.send_chat(tostring(name) .. " killed a".. n .." ".. getFucked:getTypeName() .. " with an infantry drop." , true)
		
				if coa == 1 then
					infantry.redCounter = infantry.redCounter + 0.5
				else
					infantry.blueCounter = infantry.blueCounter + 0.5
				end
			end
		end
		
		--infantry.exfilSquads
		--x and y modification
		xN, yN = math.random(0,1), math.random(0,1)
		if xN == 0 then xN = -1 end
		if yN == 0 then yN = -1 end
		
		if lastPos == nil then
			lastPos = g:getUnits()[1]:getPoint()
		end
		lastPos.x = lastPos.x + (math.random(200,700) * xN)
		lastPos.y = lastPos.z + (math.random(200,700) * yN)
		lastPos.z = nil
		
		if debugExfil == nil then
			local newGroup = infantry.spawn(name, {coa,(#g:getUnits()/4),{x = lastPos.x, y = lastPos.y}})
			timer.scheduleFunction(util.deleteExfilGroup, newGroup , timer.getTime() + 300 )
			infantry.exfilSquads[newGroup] = true
		else
			trigger.action.outText("DEBUG INFANTRY DROPPED",10)									
			log.write("yink.lua", log.INFO, "INF DEBUG: DEBUG INFANTRY DROPPED")
		end
		
	else
		if coa ~= StaticObject.getByName(roadbase):getCoalition() then
			trigger.action.setUserFlag(roadbase .. closureSuffix,2)
			net.send_chat(tostring(name) .. " closed Roadbase ".. roadbase .." with an infantry drop." , true)
			timer.scheduleFunction(function() trigger.action.setUserFlag(roadbase .. closureSuffix,1) end , nil , timer.getTime() + 3600 )
		else
			trigger.action.setUserFlag(roadbase .. closureSuffix,1)
			net.send_chat(tostring(name) .. " opened Roadbase ".. roadbase .." with an infantry drop." , true)
		end
	end
	
	--add in infantry.exfilSquads()
	
	g:destroy()
end


function infantry.reconDespawn(args) --despawn function for recon troops
	local unitsReconnedPerSquad = 12
	local group = args[1]
	local unit = Unit.getByName(args[2])
	local coa = args[3]
	local name = args[4]
	local roadbase = args[5]
	local closureSuffix = "_closureStatus"
	local g = Group.getByName(group)
	local unitCount = #g:getUnits()
	if #g:getUnits() <= 0 then
		return nil
	end
	local i = math.floor(#g:getUnits() / (2/unitsReconnedPerSquad))
	--local groups = ActiveFrontlineGroups
	local groupSelected = false
	local group
	
	if true then
		local foundUnits = {}
		
		local volume = {
			id = world.VolumeType.SPHERE,
			params = {
				point = g:getUnits()[1]:getPoint(),
				radius = infantryRadius * 1.5
			}
		}
		
		local ifFound = function(foundItem)
			if foundItem:getGroup():getCategory() == 2 and foundItem:getCoalition() ~= coa and string.sub(foundItem:getName(),1,6) == "Sector" then
				table.insert(foundUnits,foundItem)
				return true
			end
		end
		
		world.searchObjects(Object.Category.UNIT , volume , ifFound)
		
		
		
		local lastPos = nil
		for x = 0, math.floor(i) do
			if foundUnits[x] ~= nil then
				local getFucked = foundUnits[x]
				lastPos = getFucked:getPoint()
				local n = string.lower(string.sub(getFucked:getTypeName(),1,1))
				local a = n:gsub("[^eyuioaEYUIOA]","")
				if a == "" then n = "" else n = "n" end
				
			end
		end
		
		if unit ~= nil then			
			trigger.action.outTextForGroup(unit:getGroup():getID(),"Recce Squad requesting exfil! look for green smoke!",15)
		end
		
		--infantry.exfilSquads
		--x and y modification
		xN, yN = math.random(0,1), math.random(0,1)
		if xN == 0 then xN = -1 end
		if yN == 0 then yN = -1 end
		
		if true then--lastPos == nil then
			lastPos = g:getUnits()[1]:getPoint()
		end
		lastPos.x = lastPos.x + (math.random(100,400) * xN)
		lastPos.y = lastPos.z + (math.random(100,400) * yN)
		lastPos.z = nil
		
		local newGroup = infantry.reconSpawn(name, {coa,(#g:getUnits()/2),{x = lastPos.x, y = lastPos.y}})
		
		recon.lists[newGroup] = foundUnits
		
		timer.scheduleFunction(util.deleteExfilGroup, newGroup , timer.getTime() + 300 )
		
		infantry.exfilSquads[newGroup] = true
	end
	
	g:destroy()
end

--[[
infantry.drop

first parameter: name of helicopter trying to drop troops

if the unit is in the frontline sector, then spawns infantry and starts the despawn scheduler

returns nil
]]--

function infantry.drop(args)
	
	local heli = args[1]
	local roadbase = args[2]
	
	if util.isLanded[heli] then
		local unit = Unit.getByName(heli)
		local enemyFrontline = ActiveFrontline + (unit:getCoalition() - 1)
		local SectorName = "Sector " .. tostring( enemyFrontline )
		local SectorGroup = ZONE_POLYGON:FindByName( SectorName )
		local inZone = util.inEnemyZone(unit)
		local speedCheck = util.checkSpeed(unit) < 1
		local tempInfantryCount = 0
		local closestEnemyBase = util.closestEnemyAirbase(unit)
		
		if closestEnemyBase.distance < 2200 and roadbase == nil then
			trigger.action.outTextForGroup(unit:getGroup():getID(),"Too close to ".. closestEnemyBase.base:getName() .. "! Aborting drop!",10)
			return false
		end
		
		if infantry.heliSquads[heli] > 0 and not recon.helicopters[unit:getTypeName()] then
			if speedCheck then
				if roadbase ~= nil then --if roadbase drop
					tempInfantryCount = infantry.heliSquads[heli] - 1
					infantry.heliSquads[heli] = 1
					local group = infantry.spawn(heli)
					timer.scheduleFunction(infantry.despawn , {group,heli,unit:getCoalition(),unit:getPlayerName(),roadbase} , timer.getTime() + 30 )
					trigger.action.outTextForGroup(unit:getGroup():getID(),"4 Troops successfully deployed to Roadbase " .. tostring(roadbase)..".",10)
					infantry.heliSquads[heli] = tempInfantryCount					
				elseif inZone then -- if recon drop
					local group = infantry.spawn(heli)
					timer.scheduleFunction(infantry.despawn , {group,heli,unit:getCoalition(),unit:getPlayerName(),nil} , timer.getTime() + 120 )
					trigger.action.outTextForGroup(unit:getGroup():getID(),tostring(infantry.heliSquads[heli] * 4).." Troops successfully deployed to Zone " .. tostring(enemyFrontline)..".",10)
					infantry.heliSquads[heli] = 0		
				else
					trigger.action.outTextForGroup(unit:getGroup():getID(),"Not in the right zone!",10)
				end
			else
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Too fast!",4)
				timer.scheduleFunction(infantry.drop , {heli,roadbase}, timer.getTime() + 2 )	
				return nil
			end
		elseif infantry.reconSquads[heli] > 0 and recon.helicopters[unit:getTypeName()] then -- if recon drop
			if speedCheck then				
				if inZone then
					local group = infantry.reconSpawn(heli)
					timer.scheduleFunction(infantry.reconDespawn , {group,heli,unit:getCoalition(),unit:getPlayerName(),nil} , timer.getTime() + 120 )
					trigger.action.outTextForGroup(unit:getGroup():getID(),tostring(infantry.reconSquads[heli] * 2).." Recon Troops successfully deployed to Zone " .. tostring(enemyFrontline)..".",10)
					infantry.reconSquads[heli] = 0		
				else
					trigger.action.outTextForGroup(unit:getGroup():getID(),"Not in the right zone!",10)
				end
			else
				trigger.action.outTextForGroup(unit:getGroup():getID(),"Too fast!",4)
				timer.scheduleFunction(infantry.drop , {heli,roadbase}, timer.getTime() + 2 )	
				return nil
			end
		end
	end
	return nil
end

--[[
infantry.drop

first parameter: name of helicopter

outTexts passenger information from f10 menu command
]]--


function infantry.toggleDrop(heli)
	local unit = Unit.getByName(heli)
	if infantry.dropEnabled[heli] then
		infantry.dropEnabled[heli] = false
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Troop drops disabled.",10)
	else
		infantry.dropEnabled[heli] = true
		trigger.action.outTextForGroup(unit:getGroup():getID(),"Troop drops enabled.",10)
	end
end

function infantry.passengers(heli)

	local unit = Unit.getByName(heli)	
	trigger.action.outTextForGroup(unit:getGroup():getID(),"Troops loaded: ".. tostring(infantry.heliSquads[unit:getName()] * 4),5)
	trigger.action.outTextForGroup(unit:getGroup():getID(),"Recon loaded: ".. tostring(infantry.reconSquads[unit:getName()] * 2),5)
	trigger.action.outTextForGroup(unit:getGroup():getID(),"CSAR loaded: ".. tostring(csar.heliPassengers[unit:getName()]["n"]),5)
	trigger.action.outTextForGroup(unit:getGroup():getID(),"Available Seats: ".. tostring(csarMaxPassengers[unit:getTypeName()] - util.passengerCount(unit:getName())),5)
end


------------------------------------------------------------------------------------------------------------------------Event Handler Definitions

--[[
event handler section


]]--


util.usedEHs = {}
util.usedEHs[tostring(world.event.S_EVENT_LANDING_AFTER_EJECTION)] = true
util.usedEHs[tostring(world.event.S_EVENT_EJECTION)] = true
util.usedEHs[tostring(world.event.S_EVENT_BIRTH)] = true
util.usedEHs[tostring(world.event.S_EVENT_TAKEOFF)] = true
util.usedEHs[tostring(world.event.S_EVENT_LAND)] = true
util.usedEHs[tostring(world.event.S_EVENT_MARK_CHANGE)] = true
util.usedEHs[tostring(world.event.S_EVENT_MARK_ADDED)] = true




YinkEventHandler = {} --event handlers

	--local old_onEvent = world.onEvent
	function YinkEventHandler:onEvent(event)		
		
		if not util.usedEHs[tostring(event.id)] then
			return nil
		end
--[[
world.event.S_EVENT_LANDING_AFTER_EJECTION

main function for spawning csar units
]]--
		
		if world.event.S_EVENT_MARK_CHANGE == event.id then
			if DebugMode == true and util.split(event.text," ")[1] == "inf" then
				
				if #util.split(event.text," ") < 3 then return end
				local count = tonumber(util.split(event.text," ")[2])
				local exfil = nil
				
				if util.split(event.text," ")[3] == "exfil" then
					exfil = "PEACE THROUGH POWER"
					trigger.action.outText("EXFIL SQUAD SPAWNED",10)	
				elseif util.split(event.text," ")[3] == "nodespawn" then
					local debugName = infantry.spawnDebug(event.pos, event.coalition, count)
					trigger.action.outText("PERMANENT SQUAD SPAWN",10)
					return
				else
					exfil = nil
					trigger.action.outText("EXFIL SQUAD NOT SPAWNED",10)
				end
				
				local debugName = infantry.spawnDebug(event.pos, event.coalition, count)
				
				local args1 = {}
				
				args1[1] = debugName
				args1[2] = "DEBUG"--unit = Unit.getByName(args1[2])
				args1[3] = event.coalition--coa = args1[3]
				args1[4] = "DEBUG"--name = args1[4]
				args1[5] = nil--roadbase = args1[5]
				args1[6] = exfil
				infantry.despawn(args1)
			end
			return
		end
		
		if world.event.S_EVENT_LANDING_AFTER_EJECTION == event.id then		
			
			local o			= event.initiator
			local staticObj = {}
			local side 		= o:getCoalition()
			local group 	= {}
			local unit 		= {}
			local freq 		= {}
			
			local closestBase = util.closestBase(event.initiator, allBases)
			
			if closestBase.distance <= 2000 then
				closestBase = Airbase.getByName(closestBase.objectName)
				attrition.ejection(closestBase:getCoalition(), -1)
				o:destroy()	
				return
			end	
			
			local closestEnemyBase = util.closestEnemyAirbase(o)
		
			if closestEnemyBase.distance <= 2200 then
				attrition.ejection(closestEnemyBase.base:getCoalition(), -1)
				o:destroy()	
				return
			end
			
			unit["name"] 		= "CSAR_" .. tostring(side) .. "_" .. tostring(timer.getTime())-- name			
			if side == 1 then
				group["country"] 	= country.id.RUSSIA
				unit["type"] 		= "Paratrooper AKS-74"
				trigger.action.radioTransmission("l10n/DEFAULT/beacon_silent.ogg", o:getPoint() , 0 , true , 121500000, 4 , unit["name"])				
				table.insert(csar.redUnits,unit["name"])
			elseif side == 2 then
				group["country"] 	= country.id.USA
				unit["type"] 		= "Soldier M4"
				trigger.action.radioTransmission("l10n/DEFAULT/beacon_silent.ogg", o:getPoint() , 1 , true , 31050000, 4 , unit["name"])
				table.insert(csar.blueUnits,unit["name"])
			end
			
			group["category"] 	= 2
			group["name"] 		= "CSAR_" .. "_" .. tostring(side) .. "_" .. tostring(timer.getTime()) .. "_G"
			group["task"] 		= "Ground Nothing"
			group["units"]		= {}
			unit["x"]			= o:getPoint().x -- x
			unit["y"]			= o:getPoint().z -- y
			unit["heading"] 	= math.deg(math.atan2(o:getPosition().x.z, o:getPosition().x.x)+2*math.pi) -- heading
			table.insert(group["units"],unit)
			table.insert(csar.activeUnits,unit["name"])
			
			local msg = { id = 'TransmitMessage',params = {duration = 5, subtitle = '',	loop = true, file = "l10n/DEFAULT/beacon_silent.ogg", } }			
			o:destroy()
			if side ~= 0 then
				 
				timer.scheduleFunction(util.delete, unit["name"], timer.getTime() + 5400)
				coalition.addGroup(group["country"],group["category"],group)
				--Group.getByName(group["name"]):getController():setCommand(freq)
				--Group.getByName(group["name"]):getController():setCommand(msg)
				Group.getByName(group["name"]):getController():setOption(0,4)
			end
		end
		
		if event.initiator ~= nil then
			if event.initiator:getCategory() == 1 then
				if event.initiator:getPlayerName() ~= nil then

--[[
world.event.S_EVENT_EJECTION

triggers the attrition ejection function if the aircraft is not active.
]]--
			
					if world.event.S_EVENT_EJECTION == event.id then
						local coa = event.initiator:getCoalition()
						if util.activeAC[event.initiator:getName()] == false and util.isLanded[event.initiator:getName()] then
							attrition.ejection(coa, 1)
							trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You ejected while landed.",5)
						end
					end

--[[
world.event.S_EVENT_BIRTH

sets initial values and adds commands the helicopters

util.activeAC is used to query aircraft that are landed at a base and actively in the air.
]]--
	
	
					if world.event.S_EVENT_BIRTH == event.id then
							-- zero out stuff					
						util.isLanded[event.initiator:getName()] = true	--used for csar/future life return logic
						if event.initiator:getGroup():getCategory() == 1 then --if player is helicopter						
							if infantry.hasCommands[event.initiator:getGroup():getID()] == nil then
								local subMenu = missionCommands.addSubMenuForGroup(event.initiator:getGroup():getID() , "Infantry and CSAR Commands" )
								missionCommands.addCommandForGroup(event.initiator:getGroup():getID() , "Closest CSAR" , subMenu , csar.closestF10 , event.initiator:getName())
								missionCommands.addCommandForGroup(event.initiator:getGroup():getID() , "Load Troops" , subMenu , infantry.load , event.initiator:getName())
								missionCommands.addCommandForGroup(event.initiator:getGroup():getID() , "Unload Troops" , subMenu , infantry.unload , event.initiator:getName())
								missionCommands.addCommandForGroup(event.initiator:getGroup():getID() , "Toggle Troop Drop" , subMenu , infantry.toggleDrop , event.initiator:getName())
								missionCommands.addCommandForGroup(event.initiator:getGroup():getID() , "Check Passengers" , subMenu , infantry.passengers , event.initiator:getName())
								infantry.hasCommands[event.initiator:getGroup():getID()] = true
							end
							
							infantry.reconSquads[event.initiator:getName()] = 0
							infantry.heliSquads[event.initiator:getName()] = 0
							
							infantry.dropEnabled[event.initiator:getName()] = true
							csar.heliPassengers[event.initiator:getName()] = {}
							csar.heliPassengers[event.initiator:getName()]["n"] = 0 --list of rescued pilots on aircraft
							timer.scheduleFunction(csar.loop, {event.initiator, csar.activeUnits, event.initiator:getID()}, timer.getTime() + 1)
						end
						if event.initiator:getGroup():getCategory() <= 1 then  --add aircraft to active aircraft list
							util.activeAC[event.initiator:getName()] = false
						end
					end
	

--[[
world.event.S_EVENT_TAKEOFF

fires on takeoff and when in the dictionary util.isLanded is true for the unit key

if its close to a roadbase/farp, will output that name
if from an airbase, then that name is listed, otherwise it just outputs "You have taken off from the field."

will pretty much always set the activeAC value to true.

if the activeAC value is false when executed, then sets it to true and modifies attrition.

will always set isLanded to false

]]--
	
												
					if world.event.S_EVENT_TAKEOFF == event.id then
						local baseTO = false
						local category = util.type[tonumber(event.initiator:getGroup():getCategory()) + 1]
						local closestBase = util.closestBase(event.initiator, allBases)					
						if closestBase.distance < util.type[tonumber(event.initiator:getGroup():getCategory()) + 1] and not baseTO then															
							log.write("scripting", log.INFO, "TAKEOFF EVENT: "..event.initiator:getPlayerName().." took off at "..closestBase.objectName)							
							if util.isLanded[event.initiator:getName()] then
								if util.activeAC[event.initiator:getName()] == false then
									attrition.modify(event.initiator:getName(), 1)--add points
									util.activeAC[event.initiator:getName()] = true
									trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You have taken off from "..tostring(closestBase.objectName)..".",5)
								end	
							end
							util.isLanded[event.initiator:getName()] = false
							baseTO = true		
						elseif event.place ~= nil then --and not (event.initiator:getTypeName() == "Su-25" or event.initiator:getTypeName() == "A-10A") then --airbase/farp pad/ takeoff --takeoff in field/invisible farp						
							if event.place:getCoalition() == event.initiator:getCoalition() then --landed at coalition base	
								log.write("scripting", log.INFO, "TAKEOFF EVENT: "..event.initiator:getPlayerName().." took off at "..event.place:getName())
								if util.isLanded[event.initiator:getName()] then
									if util.activeAC[event.initiator:getName()] == false then
										attrition.modify(event.initiator:getName(), 1)--add points
										util.activeAC[event.initiator:getName()] = true
										trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You have taken off from "..tostring(event.place:getName())..".",5)
									end
								end						
								util.isLanded[event.initiator:getName()] = false
								baseTO = true
							end
						end
						if (event.initiator:getTypeName() == "Su-25" or event.initiator:getTypeName() == "A-10A") then
							timer.scheduleFunction(util.checkFC3Landing, event.initiator, timer.getTime() + 3)
						end					
						if not baseTO and util.activeAC[event.initiator:getName()] == false then
							util.activeAC[event.initiator:getName()] = true
							attrition.modify(event.initiator:getName(), 1)--add points
							trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You have taken off from the field.",5)
							log.write("scripting", log.INFO, "TAKEOFF EVENT: "..event.initiator:getPlayerName().." took off from the field")
							util.isLanded[event.initiator:getName()] = false
						end
					end
					
--[[
world.event.S_EVENT_LAND

fires on landing

helicopters will be checked if theyre in the enemy frontline, and if troops are onboard it will drop them.

it then does a similar base check as the takeoff event and will return attrition points and set activeAC to false if at a friendly base.
will always set isLanded to true
bottom block will check to return csar passengers if at a friendly base

]]--	
								
					if world.event.S_EVENT_LAND == event.id then
						local cont = false
						local closureSuffix = "_closureStatus"
						util.isLanded[event.initiator:getName()] = true	
						local closestBase = util.closestBase(event.initiator, allBases)
						local closestRoadbase = util.closestBase(event.initiator, {util.rRbs,util.bRbs})							
						if event.initiator:getGroup():getCategory() == 1 then
							local closestCSAR = csar.closestCSAR(event.initiator, csar.activeUnits)
							if ((infantry.heliSquads[event.initiator:getName()] > 0) or (infantry.reconSquads[event.initiator:getName()] > 0)) and infantry.dropEnabled[event.initiator:getName()] then
								local enemyFrontline = ActiveFrontline + (event.initiator:getCoalition() - 1)
								local SectorName = "Sector " .. tostring( enemyFrontline )
								local SectorGroup = ZONE_POLYGON:FindByName( SectorName )
								local inZone = util.inEnemyZone(event.initiator)
								if closestRoadbase.distance < util.type[tonumber(event.initiator:getGroup():getCategory()) + 1] and infantry.heliSquads[event.initiator:getName()] > 0 then --roadbase denial
									if StaticObject.getByName(closestRoadbase.objectName):getCoalition() ~= event.initiator:getCoalition() then -- enemy
										if tonumber(trigger.misc.getUserFlag(closestRoadbase.objectName .. closureSuffix)) ~= 2 then
											trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"Deploying Troops for roadbase closure! wait 5 seconds...",5)
											timer.scheduleFunction(infantry.drop, {event.initiator:getName(),closestRoadbase.objectName} , timer.getTime() + 5 )
										elseif tonumber(trigger.misc.getUserFlag(closestRoadbase.objectName .. closureSuffix)) == 2 and inZone then
											trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"Deploying Troops! wait 5 seconds...",5)
											timer.scheduleFunction(infantry.drop, {event.initiator:getName(),nil} , timer.getTime() + 5 )
										end
									elseif StaticObject.getByName(closestRoadbase.objectName):getCoalition() == event.initiator:getCoalition() and tonumber(trigger.misc.getUserFlag(closestRoadbase.objectName .. closureSuffix)) == 2 then -- friendly
										trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"Deploying Troops for roadbase opening! wait 5 seconds...",5)
										timer.scheduleFunction(infantry.drop, {event.initiator:getName(),closestRoadbase.objectName} , timer.getTime() + 5 )
									end
								elseif inZone then --troop deployment
									trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"Deploying Troops! wait 5 seconds...",5)
									timer.scheduleFunction(infantry.drop, {event.initiator:getName(),nil} , timer.getTime() + 5 )
								end
							elseif infantry.heliSquads[event.initiator:getName()] > 0 and not infantry.dropEnabled[event.initiator:getName()] then
								trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"Troop drops currently disabled.",5)
							end
						end					

						if closestBase.distance < util.type[tonumber(event.initiator:getGroup():getCategory()) + 1] and StaticObject.getByName(closestBase.objectName):getCoalition() == event.initiator:getCoalition() then					
							log.write("scripting", log.INFO, "LANDING EVENT: "..event.initiator:getPlayerName().." landed at "..closestBase.objectName)
							if util.activeAC[event.initiator:getName()] == true then
								attrition.modify(event.initiator:getName(), -1)--subtract points
								util.activeAC[event.initiator:getName()] = false
								trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You have landed at "..tostring(closestBase.objectName)..".",5)
								util.isLanded[event.initiator:getName()] = true
							end
							cont = true						
						elseif event.place ~= nil then-- and not (event.initiator:getTypeName() == "Su-25" or event.initiator:getTypeName() == "A-10A")--landing in field/invisible farp						
							if event.place:getCoalition() == event.initiator:getCoalition() then						
								log.write("scripting", log.INFO, "LANDING EVENT: "..event.initiator:getPlayerName().." landed at "..event.place:getName())
								if util.activeAC[event.initiator:getName()] == true then
									attrition.modify(event.initiator:getName(), -1)--subtract points
									util.activeAC[event.initiator:getName()] = false
									trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You have landed at "..tostring(event.place:getName())..".",5)
									util.isLanded[event.initiator:getName()] = true
								end
								cont = true
							end
						end					
						if cont and event.initiator:getGroup():getCategory() == 1 then --csar stuff
							if csar.heliPassengers[event.initiator:getName()]["n"] > 0 then
								log.write("scripting", log.INFO, "CSAR EVENT: "..event.initiator:getPlayerName().." returned "..tostring(csar.heliPassengers[event.initiator:getName()]["n"]).." passengers")
								trigger.action.outTextForGroup(event.initiator:getGroup():getID(),"You returned "..tostring(csar.heliPassengers[event.initiator:getName()]["n"]).." rescued airmen.",5)
								local csarReturns = attrition.csarReturn(event.initiator:getName()) --return pilots and POWs
								csar.heliPassengers[event.initiator:getName()] = {}
								csar.heliPassengers[event.initiator:getName()]["n"] = 0 --list of rescued pilots on aircraft
							end
						end
					end					
				end
			end
		end
		--return old_onEvent(event)
	end


world.addEventHandler(YinkEventHandler)

trigger.action.outText("yink.lua loaded",10)
log.write("scripting", log.INFO, "yink.lua loaded")
