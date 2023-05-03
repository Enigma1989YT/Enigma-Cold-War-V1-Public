
recon = {}
local util = {}
util.vec = {}
recon.lists = {}

recon.reconTypes = {}

recon.reconTypes["MiG-21Bis"] = true
recon.reconTypes["AJS37"] = true
recon.reconTypes["Mirage-F1CE"] = true
recon.reconTypes["C-101CC"] = true
recon.reconTypes["L-39ZA"] = true

recon.helicopters = {}

recon.helicopters["SA342Mistral"]	= true
recon.helicopters["SA342Minigun"]	= true
recon.helicopters["SA342L"]			= true
recon.helicopters["SA342M"]			= true
recon.helicopters["Mi-24P"]			= true

recon.detectedTargets = {}

recon.parameters = {}
recon.parameters["MiG-21Bis"] = {}
recon.parameters["MiG-21Bis"].minAlt 	= 100
recon.parameters["MiG-21Bis"].maxAlt 	= 4000
recon.parameters["MiG-21Bis"].maxRoll	= 8
recon.parameters["MiG-21Bis"].maxPitch	= 15
recon.parameters["MiG-21Bis"].fov		= 50
recon.parameters["MiG-21Bis"].duration	= 45
recon.parameters["MiG-21Bis"].offset	= math.rad(60)
recon.parameters["MiG-21Bis"].name		= "MiG-21R"

recon.parameters["AJS37"] = {}
recon.parameters["AJS37"].minAlt 	= 50
recon.parameters["AJS37"].maxAlt 	= 3000
recon.parameters["AJS37"].maxRoll	= 8
recon.parameters["AJS37"].maxPitch	= 15
recon.parameters["AJS37"].fov		= 60
recon.parameters["AJS37"].duration	= 45
recon.parameters["AJS37"].offset	= math.rad(70)
recon.parameters["AJS37"].name		= "SF 37"

recon.parameters["Mirage-F1CE"] = {}
recon.parameters["Mirage-F1CE"].minAlt 	= 50
recon.parameters["Mirage-F1CE"].maxAlt 	= 4000
recon.parameters["Mirage-F1CE"].maxRoll	= 8
recon.parameters["Mirage-F1CE"].maxPitch	= 15
recon.parameters["Mirage-F1CE"].fov		= 60
recon.parameters["Mirage-F1CE"].duration	= 45
recon.parameters["Mirage-F1CE"].offset	= math.rad(70)
recon.parameters["Mirage-F1CE"].name		= "Mirage-F1CR"

recon.parameters["C-101CC"] = {}
recon.parameters["C-101CC"].minAlt 	= 50
recon.parameters["C-101CC"].maxAlt 	= 2000
recon.parameters["C-101CC"].maxRoll	= 8
recon.parameters["C-101CC"].maxPitch	= 15
recon.parameters["C-101CC"].fov		= 60
recon.parameters["C-101CC"].duration	= 90
recon.parameters["C-101CC"].offset	= math.rad(70)
recon.parameters["C-101CC"].name		= "C-101CC Recon"

recon.parameters["L-39ZA"] = {}
recon.parameters["L-39ZA"].minAlt 	= 50
recon.parameters["L-39ZA"].maxAlt 	= 2000
recon.parameters["L-39ZA"].maxRoll	= 8
recon.parameters["L-39ZA"].maxPitch	= 15
recon.parameters["L-39ZA"].fov		= 60
recon.parameters["L-39ZA"].duration	= 90
recon.parameters["L-39ZA"].offset	= math.rad(70)
recon.parameters["L-39ZA"].name		= "L-39ZA Recon"

recon.targetExceptions = {}
recon.targetExceptions["blue supply"] 		= true
recon.targetExceptions["blue_01_farp"] 		= true
recon.targetExceptions["blue_00_farp"] 		= true
recon.targetExceptions["red farp supply"] 	= true
recon.targetExceptions["red_00_farp"] 		= true
recon.targetExceptions["blufor farp"] 		= true
recon.targetExceptions["blue_"] 			= true
recon.targetExceptions["static farp"] 		= true
recon.targetExceptions["static windsock"] 	= true
recon.targetExceptions["red supply"]	 	= true
recon.targetExceptions["red_"]	 			= true

------------------------------------------------------------------------------------------------------------------------util Definitions

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

function util.offsetCalc(object) --calculates the position in front of the aircraft to put the center of the search sphere
	local rad = (math.atan2(object:getPosition().x.z, object:getPosition().x.x)+2*math.pi)	
	local MSL = land.getHeight({x = object:getPoint().x,y = object:getPoint().z })
	local altitude = object:getPoint().y - MSL
	local distance = math.tan(recon.parameters[object:getTypeName()].offset) * altitude
	
	local x = object:getPoint().x + ((math.cos(rad) * distance ))
	local y = object:getPoint().z + (math.sin(rad) * distance )
				
	--trigger.action.outText(tostring( distance ),5)
	--trigger.action.outText(tostring((math.cos(rad) * distance )),5)
	--trigger.action.outText(tostring((math.sin(rad) * distance )),5)
	
	return {x = x, z = y}
end

function util.round(num, numDecimalPlaces) --rounding function

	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function util.distance( coord1 , coord2) --use z instead of y for getPoint()
	
	local x1 = coord1.x
	local y1 = coord1.z
	
	local x2 = coord2.x
	local y2 = coord2.z

	return math.sqrt( (x2-x1)^2 + (y2-y1)^2 )
end

function util.vec.cp(vec1, vec2) --mist for roll calc
	return { x = vec1.y*vec2.z - vec1.z*vec2.y, y = vec1.z*vec2.x - vec1.x*vec2.z, z = vec1.x*vec2.y - vec1.y*vec2.x}
end

function util.vec.dp (vec1, vec2) --mist for roll calc
	return vec1.x*vec2.x + vec1.y*vec2.y + vec1.z*vec2.z
end

function util.vec.mag(vec) --mist for roll calc
	return (vec.x^2 + vec.y^2 + vec.z^2)^0.5
end

function util.getRollOld(unit) --mist for roll calc
	local unitpos = unit:getPosition()
	if unitpos then
		local cp = util.vec.cp(unitpos.x, {x = 0, y = 1, z = 0})
		
		local dp = util.vec.dp(cp, unitpos.z)
		
		local Roll = math.acos(dp/(util.vec.mag(cp)*util.vec.mag(unitpos.z)))
		
		if unitpos.z.y > 0 then
			Roll = -Roll
		end
		return Roll
	end
end

function  util.getRoll(unit)
	local unitpos = unit:getPosition()
	if unitpos then
		local roll = math.atan2(-unitpos.z.y, unitpos.y.y)
		return roll
	end
end

function util.getPitch(unit) --mist
	local unitpos = unit:getPosition()
	if unitpos then
		return math.asin(unitpos.x.y)
	end
end
-----------------------------------------------------------------------------------------------------------------recon object Definitions
reconInstance = {}
recon.instances = {}

recon.marks = {}
recon.redMarkCount = 150000
recon.blueMarkCount = 160000
recon.marks.blue = {}
recon.marks.red = {}

function reconInstance:new(t) --constructor
	t = t or {}   
	setmetatable(t, self)
	self.__index = self	
	return t
end

function recon.createInstance(object) --instantiate instance and create with parameters from passed object
	local instance = reconInstance:new()
	instance:setObjectParams(object)
	recon.instances[instance.objectName] = instance
	return instance
end

function reconInstance:setObjectParams(object) --set parameters of the recon instance. used on creation and takeoff
	self.object = object
	self.point = object:getPoint()
	self.coa = object:getCoalition()
	self.type = object:getTypeName()
	self.group = object:getGroup()
	self.groupID = object:getGroup():getID()
	self.objectName = object:getName()
	self.playerName = object:getPlayerName()
	self.category = object:getGroup():getCategory()
	self.ammo = object:getAmmo()
	self.time = timer.getTime()
	self.exists = true
	self.capturing = false
	self.duration = recon.parameters[self.type].duration
	self.targetList = {}
	
	for k, v in next, net.get_player_list() do
		if net.get_player_info(v , 'name') == self.playerName then
			self.playerID = v
			break
		end
	end
	return self
end

function recon.findTargets(instance) --finds targets based on type of aircraft and its altitude.
	
	local MSL = land.getHeight({x = instance.object:getPoint().x,y = instance.object:getPoint().z }) --MSL below aircraft
	
	local altitude = instance.object:getPoint().y - MSL --AGL calculation
	
	local minAlt 	= recon.parameters[instance.type].minAlt
	local maxAlt 	= recon.parameters[instance.type].maxAlt
	local maxRoll	= recon.parameters[instance.type].maxRoll
	local maxPitch	= recon.parameters[instance.type].maxPitch
	local fov		= recon.parameters[instance.type].fov
	
	local roll 	= math.abs(math.deg(util.getRoll(instance.object)))
	local pitch = math.abs(math.deg(util.getPitch(instance.object)))
	local isFlat = (roll < maxRoll) and (pitch < maxPitch) --bool to control capture
	
	local radiusCalculated = altitude * math.tan(math.rad(fov)) --trig stuff to calculate radius of capture sphere
	local offset = util.offsetCalc(instance.object) -- x/y of position in front of aircraft to capture
	local volume = {
		id = world.VolumeType.SPHERE,
		params = {
			point = {x = offset.x, y = MSL, z = offset.z},
			radius = radiusCalculated
		}
	}
	
	local targetList = {}
	local ifFound = function(foundItem) --function to run when target is found in world.searchObjects
		if foundItem:getGroup():getCategory() == 2 and foundItem:getCoalition() ~= instance.coa then--and string.sub(foundItem:getName(),1,6) == "Sector" then
			targetList[foundItem:getName()] = foundItem
			
			--trigger.action.smoke(foundItem:getPoint(), 1)
			--trigger.action.outText(tostring(foundItem:getName()),6)
			return true
		end
	end
	
	if altitude > minAlt and altitude < maxAlt and isFlat then --within altitude parameters and not rolling/pitching excessively
		world.searchObjects(Object.Category.UNIT , volume , ifFound)
		--trigger.action.circleToAll(-1 , math.random(8000,10000) , volume.params.point , volume.params.radius ,  {1, 0, 0, 1} , {1, 0, 0, 0.5} , 0 , false, tostring(altitude))
		return targetList
	end
	return {}
end

function reconInstance:setCommandIndex(index) --index for f10 command
	self.index = index
end

function reconInstance:checkNil()
	if self.object ~= nil then
		return self.object
	else
		recon.instances[self.objectName] = nil
		return nil
	end
end

function reconInstance:addToTargetList(list) --add a list of objects, usually returned from findTargets, and add to the recon instance's internal target list. makes sure it doesnt add duplicates.
	
	for k, v in next, list do
		if self.targetList ~= nil then
			if self.targetList[k] == nil then
				--trigger.action.outText(v:getName(),5)
				self.targetList[k] = v
			end
		end
	end
end

function reconInstance:returnReconTargets() --adds targets to be added to marks. if the target has already been reconed, will skip it.
	local count = 0
	local found
	
	for k,v in next, self.targetList do
		if not v:isExist() then --if object in list doesnt exist
			self.targetList[k] = nil
		else
			found = nil
			for exceptionName, bool in next, recon.targetExceptions do
				found = string.find(string.lower(v:getName()), exceptionName)
				if found ~= nil then
					break
				end
			end
			
			if recon.detectedTargets[v:getName()] == nil and found == nil then
				recon.outMarkTable[self.coa](v)
				count = count + 1
				recon.detectedTargets[v:getName()] = v
			end
		end
	end
	return count
end


function recon.returnReconTargetsFromList(coa,targetList, amount) --adds targets to be added to marks. if the target has already been reconed, will skip it.-1 for everything
	local count = 0
	local found
	
	for k,v in next, targetList do
		if not v:isExist() then --if object in list doesnt exist
			targetList[k] = nil
		else
			found = nil
			for exceptionName, bool in next, recon.targetExceptions do
				found = string.find(string.lower(v:getName()), exceptionName)
				if found ~= nil then
					break
				end
			end
			
			if recon.detectedTargets[v:getName()] == nil and found == nil and ((count < amount) or (amount == -1)) then
				recon.outMarkTable[coa](v)
				count = count + 1
				recon.detectedTargets[v:getName()] = v
			end
		end
	end
	return count
end

function recon.redOutMark(unit)
	if unit == nil then return end
	local lat,lon,alt = coord.LOtoLL(unit:getPoint())
	local temp,pressure = atmosphere.getTemperatureAndPressure(unit:getPoint())
	local outString = tostring(util.round(lat,4))..", " .. tostring(util.round(lon,4)) .." | ".. tostring(util.round((29.92 * (pressure/100) / 1013.25) * 25.4,2)) .."\nTYPE: " .. unit:getTypeName()
	trigger.action.markToCoalition(recon.redMarkCount, outString , unit:getPoint() , 1 , true)
	recon.marks.red[unit:getName()] = recon.redMarkCount
	recon.redMarkCount = recon.redMarkCount + 1
	return recon.redMarkCount - 1
end

function recon.blueOutMark(unit)
	if unit == nil then return end
	local lat,lon,alt = coord.LOtoLL(unit:getPoint())
	local temp,pressure = atmosphere.getTemperatureAndPressure(unit:getPoint())
	local outString = tostring(util.round(lat,4))..", " .. tostring(util.round(lon,4)) .." | ".. tostring(util.round(pressure/100,2)) .." " .. tostring(util.round(29.92 * (pressure/100) / 1013.25,2)) .."\nTYPE: " .. unit:getTypeName()
	trigger.action.markToCoalition(recon.blueMarkCount, outString , unit:getPoint() , 2 , true)
	recon.marks.blue[unit:getName()] = recon.blueMarkCount
	recon.blueMarkCount = recon.blueMarkCount + 1
	return recon.blueMarkCount - 1
end

recon.outMarkTable = { [1] = recon.redOutMark, [2] = recon.blueOutMark }

function recon.getInstance(unitName) --finds recon instance based on object name
	if recon.instances[unitName] ~= nil then
		if recon.instances[unitName].object ~= nil then
			return recon.instances[unitName]
		else
			reconInstance[unitName] = nil
			return nil
		end
	else
		return nil
	end
end


function recon.captureData(instance) -- main loop when capturing data. loops recursively while you have film and commanded to capture.

	if instance.capturing and instance.duration > 0 then
		instance.duration = instance.duration - 0.5
		trigger.action.outTextForGroup(instance.groupID,"CAPTURE TIME: " .. tostring(instance.duration),1,true)
		instance:addToTargetList(recon.findTargets(instance))
		timer.scheduleFunction(recon.captureData, instance, timer.getTime() + 0.5)
		
	end
	if instance.duration <= 0 and instance.loop then
		instance.loop = false --added so it doesnt double send command
		trigger.action.outTextForGroup(instance.groupID,"ERROR: NO FILM",5,true)
		trigger.action.outTextForGroup(instance.groupID,"RECON MODE DISABLED ",5)
		missionCommands.removeItemForGroup(instance.groupID,instance.index)
		local index = missionCommands.addCommandForGroup(instance.groupID , "ENABLE RECON MODE" , nil , recon.control , instance)
		instance.capturing = false
		instance:setCommandIndex(index)
	end
	
	return
end

function reconInstance:captureData() --initial function when hitting enable recon mode. starts the loop or just exits if out of film
	
	if self.duration <= 0 then
		trigger.action.outTextForGroup(self.groupID,"ERROR: NO FILM",2)
		return
	else
		self.capturing = true
	end
	
	if self.capturing and self.duration > 0 then
		self.loop = true
		trigger.action.outTextForGroup(self.groupID,"UNCAGING | TIME REMAINING: " .. tostring(self.duration),1)
		missionCommands.removeItemForGroup(self.groupID,self.index)
		local index = missionCommands.addCommandForGroup(self.groupID , "DISABLE RECON MODE" , nil , recon.control , self)
		self:setCommandIndex(index)
		timer.scheduleFunction(recon.captureData, self, timer.getTime() + 2)
	end
	return
end

function reconInstance:delete()
	recon.instances[self.objectName] = nil
	self = nil
end

------------------------------------------------------------------------------------------------------------------------command Definitions



------------------------------------------------------------------------------------------------------------------------function Definitions

function recon.checkIfRecon(unit) --check if the unit is in the recon table and has no weapons. if so, enable recon flight	
	if recon.reconTypes[unit:getTypeName()] then
		if unit:getAmmo() == nil then
			return true
		else
			return false
		end
	else
		return false
	end
end

function recon.control(instance) --control function to enter into the captureData init method. Made so i can reference it in the addcommandforgroup function

	if not instance.capturing then
		instance:captureData()
		return 
	end

	if instance.capturing then
		instance.capturing = false
		trigger.action.outTextForGroup(instance.groupID,"RECON MODE DISABLED ",2)
		missionCommands.removeItemForGroup(instance.groupID,instance.index)
		local index = missionCommands.addCommandForGroup(instance.groupID , "ENABLE RECON MODE" , nil , recon.control , instance)
		instance.capturing = false
		instance:setCommandIndex(index)
	end

	return
end


function recon.removeUnusedMarks(args, time)
	
	for unitName, markNumber in next, recon.marks.blue do
		if not Unit.getByName(unitName):isExist() then
			trigger.action.removeMark(markNumber)
			recon.marks.blue[unitName] = nil
			recon.detectedTargets[unitName] = nil
		end
	end
	
	for unitName, markNumber in next, recon.marks.red do
		if not Unit.getByName(unitName):isExist() then
			trigger.action.removeMark(markNumber)
			recon.marks.red[unitName] = nil
			recon.detectedTargets[unitName] = nil
		end
	end
	
	return time + 120
end


timer.scheduleFunction(recon.removeUnusedMarks, nil, timer.getTime() + 20)

------------------------------------------------------------------------------------------------------------------------Event Handler Definitions

local reconEventHandler = {}

function reconEventHandler:onEvent(event)	

	if world.event.S_EVENT_BIRTH == event.id then
		local instance
		instance = recon.getInstance(event.initiator:getName())
		if instance then
			missionCommands.removeItemForGroup(event.initiator:getGroup():getID(),instance.index) --remove the command from the unit
			instance:delete()
		end
	end
	
	if world.event.S_EVENT_DEAD == event.id then --dead event is used for deleting recon marks and cleaning up recon.detectedTargets

		if recon.detectedTargets[event.initiator:getName()] ~= nil then --if its in the recon detected target list
			local markNumber = nil
			if recon.marks.blue[event.initiator:getName()] ~= nil then
				markNumber = recon.marks.blue[event.initiator:getName()]
			elseif recon.marks.red[event.initiator:getName()] ~=nil then
				markNumber = recon.marks.red[event.initiator:getName()]
			end
				
			if markNumber ~= nil then
				trigger.action.removeMark(markNumber)
			end
			recon.detectedTargets[event.initiator:getName()] = nil
		end
		return
	end
	
	if world.event.S_EVENT_TAKEOFF == event.id then --takeoff event enables recon flights and updates/creates recon instances
		local instance
		
		if recon.checkIfRecon(event.initiator) then
		
			if recon.instances[event.initiator:getName()] ~= nil then	--if a recon instance is already created for this unit
			
				instance = recon.getInstance(event.initiator:getName())	--get the instance		
				missionCommands.removeItemForGroup(event.initiator:getGroup():getID(),instance.index) --remove the command from the unit
				instance:setObjectParams(event.initiator) --reset parameters for instance
			else
				--trigger.action.outText("not in instance table",20)
				instance = recon.createInstance(event.initiator) --create new instance if not created yet.
			end
			
			if recon.checkIfRecon(event.initiator) then --if recon then add command and tell player.
				trigger.action.outTextForGroup(instance.groupID,"Valid "..recon.parameters[event.initiator:getTypeName()].name.." reconnaissance flight.",20)
				local index = missionCommands.addCommandForGroup(instance.groupID , "ENABLE RECON MODE" , nil , recon.control , instance)
				instance.capturing = false
				instance:setCommandIndex(index)
				
			elseif  recon.instances[event.initiator:getName()] ~= nil then
				recon.instances[event.initiator:getName()]:delete() --delete the instance associated with the unit if not a recon flight
			end
		else
			if recon.instances[event.initiator:getName()] ~= nil then
				instance = recon.getInstance(event.initiator:getName())	--get the instance		
				missionCommands.removeItemForGroup(event.initiator:getGroup():getID(),instance.index) --remove the command from the unit
				instance:delete()
			end
		end
		return
	end
	
	if world.event.S_EVENT_LAND == event.id then --return values if its a recon plane and lands near a friendly base
		local instance
		if recon.reconTypes[event.initiator:getTypeName()] then
			
			--trigger.action.outText("in recon valid table",20)
			if recon.instances[event.initiator:getName()] ~= nil then
			
				instance = recon.getInstance(event.initiator:getName())
				--trigger.action.outText("in instance table",20)
				
				
				
				local bases = coalition.getAirbases(instance.coa)
				local closestBase = bases[1]
				local distance
				local closestDistance = util.distance(event.initiator:getPoint(), closestBase:getPoint())
				local pid
				
				for k, v in next, bases do
					distance = util.distance(event.initiator:getPoint(), v:getPoint())
					if distance <= closestDistance then
						closestDistance = distance
						closestBase = v
					end
				end
				if closestDistance < 4000 then
					missionCommands.removeItemForGroup(event.initiator:getGroup():getID(),instance.index)
					local count = instance:returnReconTargets()
					local pointGain = math.ceil(count / 4)
					
					util.addUserPoints(instance.playerName, pointGain)
					
					trigger.action.outTextForCoalition(instance.coa,event.initiator:getPlayerName() .. " gathered intel on " .. tostring(count) .. " targets.",8)
					trigger.action.outTextForUnit(instance.object:getID() , "You received " .. tostring(pointGain) .. " credits for reconnaissance." , 8)
					
					instance:setObjectParams(event.initiator) --reset object
				end
			end
		end	
		return
	end
	
end

world.addEventHandler(reconEventHandler)
