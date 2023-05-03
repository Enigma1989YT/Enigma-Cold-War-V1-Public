-- Initiate functions
MoveFrontline = nil
trigger.action.setUserFlag("frontline",15)

-- Mission Reset Counter
function MissionResetCounter()
	local mizCount
	local mizCountFile = io.open(lfs.writedir() .. '.mizResetCount', 'r')
	if mizCountFile then
		mizCount = tonumber(mizCountFile:read("*all"))
		mizCountFile:close()
	else	
		env.info("Failed to open mizCountFile for reading, creating new file",false)
	end
	mizCountFile = io.open(lfs.writedir() .. '.mizResetCount', 'w')
	if not mizCountFile then
		env.error("Failed to open mizCountFile for writing",false)
		return
	end
	mizCount = mizCount or 0
	mizCount = mizCount + 1
	env.info(string.format("MizCount Post %d", mizCount))
	mizCountFile:write(mizCount)
	mizCountFile:close()
end
MissionResetCounter()

--
-- Draw sectors (Z) on F10 map
--

--enable SSB

--trigger.action.setUserFlag("SSB",100)

BlueFrontDepotLives, RedFrontDepotLives = 0,0
BlueFrontLineLives, RedFrontLineLives 	= 0,0

function RestoreState()
	local frontFile = io.open(lfs.writedir() .. '.frontline', 'r')
	local active = -1

	if frontFile then
		active = tonumber(frontFile:read("*all"))
		frontFile:close()
		if (active ~= nil ) and (active >= 1 and active <= 30) then
			log.write("base", log.INFO, string.format("Restoring frontline from previous state: %d", active))
			ActiveFrontline = active
			trigger.action.setUserFlag("frontline",active)
		else
			log.write("base", log.ERROR, string.format("Frontline file seems corrupted, invalid value detected. Starting with default configuration: %d\n", ActiveFrontline))
			return
		end
	else
		log.write("base", log.INFO, "Frontline state not found, starting with default configuration")
	end
end

--client sets, needed for airbase protection and future re-write of slot blocking integration, might be moved to collection.lua if that file isn't deprecated
BlueClients = SET_CLIENT:New():FilterCoalitions("blue"):FilterOnce()
RedClients = SET_CLIENT:New():FilterCoalitions("red"):FilterOnce()

RedAirDefense = {}
BlueAirDefense = {}

ECWSides = {"blue","red"}
ECWSAMTypes = {"HighSAM", "LowSAM", "SHORAD", "MANPADS"}

AirDefenseTemplates = {}

function CreateADTemplates()
	for _, side in ipairs(ECWSides) do
		env.info("Adding AD templates from "..side.." side",false)
		AirDefenseTemplates[side] = {}
		for _, type in ipairs(ECWSAMTypes) do
			env.info("Adding "..type,false)
			AirDefenseTemplates[side][type] = SET_GROUP:New():FilterCoalitions(side):FilterPrefixes(type):FilterOnce()
			env.info("Added "..tostring(AirDefenseTemplates[side][type]:Count()),false)
			AirDefenseTemplates[side][type]:ForEachGroup(function(group)
				env.info("Added "..group:GetName())
			end)
		end
	end
end
CreateADTemplates()

--ActiveAirDefenses = {}
--ActiveAirDefenses["BLUE"] = {}
--ActiveAirDefenses["RED"] = {}
--
--for i=1, SectorQuantity do
--	ActiveAirDefenses["BLUE"][i] = SET_GROUP:New():FilterCoalitions("blue"):FilterPrefixes("Sector "..tostring(i).." AirDefense"):SetIteratorIntervals(1,1):FilterOnce()
--	ActiveAirDefenses["RED"][i] = SET_GROUP:New():FilterCoalitions("red"):FilterPrefixes("Sector "..tostring(i).." AirDefense"):SetIteratorIntervals(1,1):FilterOnce()
--end


AirDefenseZones = {}

function CreateADSpawnZoneSets()
	env.info("Gathering AD spawn zones", false)
	for _, side in ipairs(ECWSides) do
		env.info("Checking "..side.." side",false)
		AirDefenseZones[side] = {}
		for _, type in ipairs(ECWSAMTypes) do
			env.info("Checking "..type,false)
			local zones = SET_ZONE:New():FilterPrefixes(string.upper(side).." "..type):FilterOnce()
			env.info("Found "..tostring(zones:Count()).." zones matching criteria")
			AirDefenseZones[side][type] = {}
			for sector = 1,30 do
				local sectorObject = ZONE_POLYGON:NewFromGroupName("Sector "..tostring(sector))
				env.info("Checking sector "..tostring(sector),false)
				AirDefenseZones[side][type][sector] = SET_ZONE:New():Clear()
				zones:ForEach(
				function(zone)
					env.info("Spawn zone in sector, adding", false)
					AirDefenseZones[side][type][sector]:AddZone(zone)
				end,
				{},
				zones:GetSet(),
				function (_,zone)
					env.info("Checking if spawn zone "..zone:GetName().." is inside sector "..tostring(sector), false)
					return sectorObject:IsVec2InZone(zone:GetVec2())
				end,
				{})
			end
		end
	end
	env.info("Processed all air defense zones", false)
	while AirDefenseZones["red"]["MANPADS"][30] == nil do
		env.info("waiting to sync",false)
	end
end
CreateADSpawnZoneSets()


function GetOtherSide(side)
	if ECWSides[1] == side then return ECWSides[2]
	else return ECWSides[1] end
end

function GetLives(side)
	if string.lower(side) == "blue" then
		return BlueLives, BlueMaxLives
	elseif string.lower(side) == "red" then
		return RedLives, RedMaxLives
	else
		return nil
	end
end

function SetLives(side,new)
	if string.lower(side) == "blue" then
		BlueLives = new
	elseif string.lower(side) == "red" then
		RedLives = new
	end
end

StrategicTargets = {}
StrategicSchedule = SCHEDULER:New()

function StrategicTargetHandling()

	for i,side in ipairs(ECWSides) do
		
		StrategicTargets[side] = {}
		StrategicTargets[side].set = SET_STATIC:New():FilterCoalitions(side):FilterPrefixes("Industrial"):SetIteratorIntervals(5,0.1):FilterStart()
		StrategicTargets[side].maxCount = StrategicTargets[side].set:Count()
		StrategicTargets[side].count = StrategicTargets[side].set:Count()
		env.info("Found "..tostring(StrategicTargets[side].count).." "..side.." strategic targets")
		StrategicTargets[side].set:ForEachStatic(function(static)	
			env.info("Found: "..static:GetName()..", ID: "..static:GetID(),false)
		end)
		
		--static events are broken
		
		---StrategicTargets[side].set:ForEachStatic(function(static)
		---	static:HandleEvent( EVENTS.Dead, function(e)
		---		if static.isAlive ~= nil and static:isAlive() then return end
		---		local lives, maxLives = GetLives(side)
		---		local target = StrategicTargetValue/StrategicTargets[side].count
		---		lives = lives - target
		---		env.info("Destroyed strategic target worth "..tostring(target),false)				
		---		SetLives(side,lives)
		---		if lives/maxLives * 100 <= BreakthroughThreshold then
		---			MoveFrontline( string.upper(side), "Over "..tostring(100-BreakthroughThreshold).."% of "..string.upper(string.sub(side,1,3)).."FOR's frontline units have been eliminated, a break through has occurred and "..string.upper(string.sub(GetOtherSide(side),1,3)).."FOR has gained two sectors.", 2 )
		---		end
		---		env.info("Current "..side.." lives: "..tostring(GetLives(side)),false)
		---		static:UnHandleEvent(EVENTS.Dead)
		---	end)
		---end)
		
		StrategicSchedule:Schedule(nil, function()
			local currcount = StrategicTargets[side].set:CountAlive()
			local countdiff = StrategicTargets[side].count - currcount
			StrategicTargets[side].count = currcount
			if countdiff ~= 0 then
				local lives, maxLives = GetLives(side)
				local target = countdiff*StrategicTargetValue/StrategicTargets[side].maxCount
				lives = lives - target
				
				env.info("Destroyed "..tostring(countdiff).." strategic targets worth "..tostring(target),false)
				
				SetLives(side,lives)
				if lives/maxLives * 100 <= BreakthroughThreshold then
					MoveFrontline( string.upper(side), "Over "..tostring(100-BreakthroughThreshold).."% of "..string.upper(string.sub(side,1,3)).."FOR's frontline units have been eliminated, a break through has occurred and "..string.upper(string.sub(GetOtherSide(side),1,3)).."FOR has gained two sectors.", 2 )
				end

				env.info("Current "..side.." lives: "..tostring(GetLives(side)),false)
			end
		end,{},i,10)

	end
	
end

StrategicTargetHandling()


--BlueClientsActive = SET_CLIENT:New():FilterCoalitions("blue"):FilterActive():FilterStart()
--RedClientsActive = SET_CLIENT:New():FilterCoalitions("red"):FilterActive():FilterStart()

--require("collection.lua")

function PopulateFarps()
	
	for i = 1,SectorQuantity do
		for j=1, FarpPerZone do
			
			local _nameRed = "RED_"..string.format("%02d",i).."_FARP"
			local _nameBlue = "BLUE_"..string.format("%02d",i).."_FARP"
	
			local _roadNameRed = "RED_"..string.format("%02d",i).."_ROAD"
			local _roadNameBlue = "BLUE_"..string.format("%02d",i).."_ROAD"
			
			if j > 1 then
				_nameRed= _nameRed..tostring(j)
				_nameBlue = _nameBlue..tostring(j)
				_roadNameBlue = _roadNameBlue..tostring(j)
				_roadNameRed = _roadNameRed..tostring(j)
			end

			--BlockedFields[coalition.side.RED][_nameRed]=false
			--BlockedFields[coalition.side.BLUE][_nameBlue] = false
			
			--if ActiveFrontline >= i then
			--	BlockedFields[coalition.side.BLUE][_nameBlue] = true
			--end
			--if ActiveFrontline < i then
			--	BlockedFields[coalition.side.RED][_nameRed] = true
			--end
			
			if trigger.misc.getZone(_nameBlue) ~= nil then
				if ActiveFrontline >= i then
					BlockedFields[coalition.side.BLUE][_nameBlue] = true
				else
					BlockedFields[coalition.side.BLUE][_nameBlue] = false
				end
			end

			if trigger.misc.getZone(_nameRed) ~= nil then
				if ActiveFrontline < i then
					BlockedFields[coalition.side.RED][_nameRed] = true
				else
					BlockedFields[coalition.side.RED][_nameRed] = false
				end
			end

			if trigger.misc.getZone(_roadNameBlue) ~= nil then
				if ActiveFrontline >= i then
					BlockedFields[coalition.side.BLUE][_roadNameBlue] = true
				else
					BlockedFields[coalition.side.BLUE][_roadNameBlue] = false
				end
			end

			if trigger.misc.getZone(_roadNameRed) ~= nil then
				if ActiveFrontline < i then
					BlockedFields[coalition.side.RED][_roadNameRed] = true
				else
					BlockedFields[coalition.side.RED][_roadNameRed] = false
				end
			end
			
		end
	end
	
end

PopulateFarps()

SectorZones = {}
SideColors = {}
SideColors["red"] = {}
SideColors["red"][1] = 1
SideColors["red"][2] = 0
SideColors["red"][3] = 0
SideColors["blue"] = {}
SideColors["blue"][1] = 0
SideColors["blue"][2] = 0
SideColors["blue"][3] = 1


function InitDrawFrontline()
	
	local color
	for i = 1, SectorQuantity do
		
		SectorZones[i] = {}
		SectorZones[i].name = "Sector "..tostring(i)
		SectorZones[i].zone = ZONE_POLYGON:New(SectorZones[i].name,GROUP:FindByName(SectorZones[i].name))
		
		if i > ActiveFrontline then
			SectorZones[i].side = "red"
		else
			SectorZones[i].side = "blue"
		end
		color = SideColors[SectorZones[i].side]
		SectorZones[i].zone:DrawZone(-1, {color[1], color[2], color [3]}, 0.75, {color[1],color[2],color[3]}, 0, 1)
		
	end

end

function UpdateDrawFrontline()
	
	local direction
	local cur
	local newSide
	if SectorZones[ActiveFrontline].side == "red" then 
		direction = -1
		cur = ActiveFrontline
		newSide = "blue"
	elseif SectorZones[ActiveFrontline+1].side == "blue" then
		direction = 1
		cur = ActiveFrontline+1
		newSide = "red"
	else return end
	
	local color
	local match = false
	while not match do
		match = (SectorZones[cur].side == newSide)
		if not match then
			SectorZones[cur].side = newSide
			SectorZones[cur].zone:UndrawZone()
			color = SideColors[newSide]
			SectorZones[cur].zone:DrawZone(-1, {color[1], color[2], color [3]}, 0.75, {color[1],color[2],color[3]}, 0, 1)
		end
		cur = cur + direction
		if cur > 30 or cur < 1 then break end
	end

end

function DrawFrontline() --depreceted 
	
	for i = SectorQuantity, 1, -1 do 
		
		if i > ActiveFrontline then
			
			local SectorName = "Sector " .. tostring( i )
			
			local SectorGroup = GROUP:FindByName( SectorName )
			
			local ActiveSector = ZONE_POLYGON:New( SectorName, SectorGroup )
			
			ActiveSector:DrawZone( -1, {1,0,0}, 0.75, {1,0,0}, 0, 1, true )
			
		else
			
			local SectorName = "Sector " .. tostring( i )
			
			local SectorGroup = GROUP:FindByName( "Sector " .. tostring( i ) )
			
			local ActiveSector = ZONE_POLYGON:New( SectorName, SectorGroup )
			
			ActiveSector:DrawZone( -1, {0,0,1}, 0.75, {0,0,1}, 0, 1, true )

		end

	end
	
end

function UndrawFrontline() --deprecated

	for i = SectorQuantity, 1, -1 do 
		
		local SectorName = "Sector " .. tostring( i )
		
		local ActiveSector = ZONE_POLYGON:FindByName( SectorName )
		
		ActiveSector:UndrawZone()
		
	end
	
end

--
-- Smoke frontline (Frontline)
--

function SmokeFrontline()
	
	local FrontlineName = "Frontline " .. tostring( ActiveFrontline )

	local FrontlineGroup = GROUP:FindByName( FrontlineName )
	
	local ActiveFrontlineSector = ZONE_POLYGON:New( FrontlineName, FrontlineGroup )
	
	ActiveFrontlineSector:SmokeZone( SMOKECOLOR.White, 2 )
	
	local StaticName = "Frontline " .. tostring( ActiveFrontline ) .. " marker 1"

end

--
-- Populate frontline
--

SpawnNumbers = {}
function GetSpawnNumbers()
	for i = 1, 30 do
		local spawns = FrontlineSpawnpoints[i]
		SpawnNumbers[i] = 0
		for j = 1,spawns do
			if ZONE:FindByName("Sector "..tostring(i).." spawnpoint "..tostring(j)) ~= nil then SpawnNumbers[i]= SpawnNumbers[i] + 1 end
		end
		env.info("Found "..tostring(SpawnNumbers[i]).." zones in Sector "..tostring(i), false)
	end
end
GetSpawnNumbers()

ECW_Spawn_co = {}
TargetStatusMap = {}
BreakthroughInProgress = false

function PopulateFrontline()
	
	local BlueActiveSector = ActiveFrontline
	local RedActiveSector = ActiveFrontline + 1
	
	RedFrontLineLives = FrontlineTargetsValue
	BlueFrontLineLives = FrontlineTargetsValue
	
	local BlueSectorName = "Sector " .. tostring( BlueActiveSector )
	local RedSectorName = "Sector " .. tostring( RedActiveSector )
	
	local function SpawnTargets( Coalition, SectorName, FrontlineGroups, SpawnCounter )
		
		local SpawnQuantity = 0
		
		if Coalition == "BLUE" then
			SpawnQuantity = FrontlineSpawnpoints[BlueActiveSector]
			BlueLives = BlueMaxLives-(StrategicTargetValue*(StrategicTargets["blue"].maxCount - StrategicTargets["blue"].count)/StrategicTargets["blue"].maxCount)
		else
			SpawnQuantity = FrontlineSpawnpoints[RedActiveSector]
			RedLives = RedMaxLives-(StrategicTargetValue*(StrategicTargets["red"].maxCount - StrategicTargets["red"].count)/StrategicTargets["red"].maxCount)
		end
		
		ECW_Spawn_co[Coalition] = coroutine.wrap(function()
			for i = SpawnQuantity, 1, -1 do
				
				local SpawnName = SectorName .. " " .. "spawnpoint " .. tostring( i )
				
				--local SpawnZone = ZONE:New( SpawnName )
				local SpawnZone = ZONE:FindByName(SpawnName)
				if SpawnZone ~= nil then
					
					local FrontlineTarget = SPAWN:NewWithAlias( FrontlineGroups[math.random( #FrontlineGroups )], SectorName .. " target " .. tostring( i ) )
					
				FrontlineTarget:OnSpawnGroup( function( group )
					
						table.insert( ActiveFrontlineGroups, group )

						local groupUnits = group:GetUnits()
						for _, unit in pairs(groupUnits) do
							TargetStatusMap[unit:GetName()] = group:GetInitialSize()
						end
						
						group:HandleEvent( EVENTS.Dead )
						group:HandleEvent( EVENTS.Hit)
						
						local function LifeCalculation(GroupInitialSize)
							
							env.info("Group is dead",false)
							
							if Coalition == "BLUE" then

								env.info("FrontlineTargetsValue = "..FrontlineTargetsValue..", SpawnNumbers["..BlueActiveSector.."] = "..SpawnNumbers[BlueActiveSector]..", Group:GetinitialSize = "..GroupInitialSize)
								local TargetValue = FrontlineTargetsValue / ( SpawnNumbers[BlueActiveSector] * GroupInitialSize )
								
								BlueLives = BlueLives - TargetValue
								
								BlueFrontLineLives = BlueFrontLineLives - TargetValue
								
								if ( BlueLives / BlueMaxLives ) * 100 <= BreakthroughThreshold and BreakthroughInProgress == false then

									BreakthroughInProgress = true
									SCHEDULER:New(nil, function()
										MoveFrontline( Coalition, "Over "..tostring(100-BreakthroughThreshold).."% of BLUFOR's frontline units have been eliminated, a break through has occurred and REDFOR has gained two sectors.", 2 )
									end, {}, 5)
								end
								env.info("Health reduced by "..tostring(TargetValue),false)
								
							else

								env.info("FrontlineTargetsValue = "..FrontlineTargetsValue..", SpawnNumbers["..RedActiveSector.."] = "..SpawnNumbers[RedActiveSector]..", Group:GetinitialSize = "..GroupInitialSize)
								local TargetValue = FrontlineTargetsValue / ( SpawnNumbers[RedActiveSector] * GroupInitialSize )
								
								RedLives = RedLives - TargetValue
								
								RedFrontLineLives = RedFrontLineLives - TargetValue
								
								if ( RedLives / RedMaxLives ) * 100 <= BreakthroughThreshold and BreakthroughInProgress == false then

									BreakthroughInProgress = true
									SCHEDULER:New(nil, function()
										MoveFrontline( Coalition, "Over "..tostring(100-BreakthroughThreshold).."% of REDFOR's frontline units have been eliminated, a break through has occurred and BLUFOR has gained two sectors.", 2 )
									end, {}, 5)
								end
								env.info("Health reduced by "..tostring(TargetValue),false)
								
							end
						end

						function group:OnEventDead(event)
							
							if TargetStatusMap[event.IniUnitName] == nil then return end
							LifeCalculation(TargetStatusMap[event.IniUnitName])
							TargetStatusMap[event.IniUnitName] = nil
						end

						function group:OnEventHit(event)
							if event.TgtUnitName ~= nil and TargetStatusMap[event.TgtUnitName] ~= nil and event.TgtUnit:GetLife() <= 1 then
								LifeCalculation(TargetStatusMap[event.TgtUnitName])
								TargetStatusMap[event.TgtUnitName] = nil
							else return end
						end

					end
					
				)
				
				FrontlineTarget:SpawnInZone( SpawnZone, false )
			end
			env.info("iteration "..tostring(i).." out of "..tostring(SpawnQuantity)..", yielding", false)
			coroutine.yield(true)
		end
		env.info("loop ended, do not resume", false)
			return false
		end)

		timer.scheduleFunction(function(skip, time)
			local cont = ECW_Spawn_co[Coalition]()
			if cont == true then 
				env.info("coroutine returned true, scheduling another run")
				return time+1
			else
				env.info("coroutine returned false, do not reschedule") 
				return nil 
			end
		end,{},timer.getTime()+1)

	end
	
	-- Populate blue frontline

	SpawnTargets( "BLUE", BlueSectorName, BlueFrontlineGroups)
	--env.info("Spawned blue in "..tostring(BlueCurrentSectorSpawns).." zones",false)
	
	-- Populate red frontline
	SpawnTargets( "RED", RedSectorName, RedFrontlineGroups)
	--env.info("Spawned red in "..tostring(RedCurrentSectorSpawns).." zones", false)
	
end

ActiveAirDefenses = {}
ActiveAirDefenses["blue"] = {}
ActiveAirDefenses["red"] = {}

for i=1, SectorQuantity do
	ActiveAirDefenses["blue"][i] = {}
	ActiveAirDefenses["red"][i] = {}
end

AirDefenseSpawners = {}
AirDefenseResTimers = {}

ThreatRadii = {
	["Tor 9A331"] = 12000,
	["5p73 s-125 ln"] = 25000,
	["S_75M_Volhov"] = 40000,
	["Strela-10M3"] = 5000,
	["Kub 2P25 ln"] = 25000,
	["Roland ADS"] = 8000,
	["rapier_fsa_launcher"] = 6800,
	["Osa 9A33 ln"] = 10300,
	["Hawk ln"] = 45000,
	["Strela-1 9P31"] = 4200,
	["M48 Chaparral"] = 8500, --oh no! The chap!
	["M1097 Avenger"] = 6000
}

ThreatZones = {}

function SpawnDefenses(side, AirDefense, sectorNumber)

	local sector = ZONE_POLYGON:NewFromGroupName("Sector "..tostring(sectorNumber))

	local function ManageDefenseInZone(zone,defense,timer)
		env.info("Spawning air defense in zone "..zone:GetName(),false)
		local groupToSpawn = defense:GetRandom()
		env.info("Selected group "..groupToSpawn:GetName(),false)
		--local spawner = SPAWN:NewFromTemplate(groupToSpawn:GetTemplate(), "", " "..side.." Sector "..tostring(sectorNumber).." AirDefense ")
		local spawner = SPAWN:NewWithAlias(groupToSpawn:GetName(), side.." Sector "..tostring(sectorNumber).." AirDefense "..zone:GetName())
		spawner:InitRandomizePosition(true, 80,150)
		spawner:SetSpawnIndex(0)
		spawner:OnSpawnGroup(
			function(group,side,sectorNumber)
				env.info("Group "..group:GetName().." in position", false)
				if timer > 0 then 
					group:HandleEvent(EVENTS.Dead)
					function group:OnEventDead(e)
						if AirDefenseResTimers[group:GetName()] == nil then 
							AirDefenseResTimers[group:GetName()] = SCHEDULER:New(nil, function()
								local name = group:GetName()
								
								env.info("Respawning "..name, false)
								
								AirDefenseResTimers[name] = nil --nil the res timer, so that it can be restarted on respawn
								
								--check if sector isn't overrun
								if string.lower(string.sub(name,1,11)) == "blue sector" then		--BLUE_Sector / RED_Sector_
									local snum = string.sub(name,13,14)
									local num = tonumber(snum)
									if num == nil then num = tonumber(string.sub(name,13,13)) end
									
									if ActiveFrontline < num then return end
								
								elseif string.lower(string.sub(name,1,10)) == "red sector" then
									local snum = string.sub(name,12,13)
									local num = tonumber(snum)
									if num == nil then num = tonumber(string.sub(name,12,12)) end
									
									if ActiveFrontline >= num then return end

								end
								spawner:ReSpawn(1)
								spawner:SetSpawnIndex(0)
								
							end,{},timer) 
							env.info("AD Group "..group:GetName().." will respawn in "..timer,false)
						end
						--spawner:UnHandleEvent(EVENTS.UnitLost)
					end
					env.info("Respawn armed for group "..group:GetName())
				else
					env.info("Group not scheduled for respawn")
				end
				table.insert(ActiveAirDefenses[string.lower(side)][sectorNumber],group)
			end, side, sectorNumber
		)
		--if timer > 0 then spawner:HandleEvent(EVENTS.UnitLost, function (e)
		--	SCHEDULER:New(nil, function()
		--		group:Respawn()
		--	end,{},timer)
		--end) end
		env.info("Spawning group at "..zone:GetName())
		local spawnedGroup = spawner:SpawnInZone(zone, false)
		if spawnedGroup == nil then
			env.error("SpawnInZone failed at "..zone:GetName(),false)
		else
			env.info("Group "..spawnedGroup:GetName().." spawned, creating threat circle")
			--add threat circle
			local range = 0
			local units = spawnedGroup:GetUnits()

			for _,unit in pairs(units) do
				local type = unit:GetTypeName()
				if ThreatRadii[type]~=nil and ThreatRadii[type]>range then
					range = ThreatRadii[type]
					env.info(type.." detected inside group, increasing threat radius to "..tostring(range))
				end
			end
		
			if range > 0 then
				env.info("Drawing threat ring of range "..tostring(range))
				if ThreatZones[zone] ~= nil then
					env.info("Ring already drawn, undrawing")
					for key, threatZone in pairs(ThreatZones[zone]) do
						threatZone:UndrawZone()
					end
				end
				ThreatZones[zone] = {}
				ThreatZones[zone]["blue"] = ZONE_RADIUS:New(zone:GetName().."_threatblue",zone:GetVec2(),range)
				ThreatZones[zone]["red"] = ZONE_RADIUS:New(zone:GetName().."_threatred",zone:GetVec2(),range)
				env.info("Added threat ring zones: "..ThreatZones[zone]["blue"]:GetName()..", "..ThreatZones[zone]["red"]:GetName())
				if side == "red" then
					env.info("Drawing with red ownership")
					ThreatZones[zone]["red"]:DrawZone( 1, {1,0,0}, 0.75, {1,1,0}, 0, 1, false )
					ThreatZones[zone]["blue"]:DrawZone( 2, {1,0,0}, 0.75, {1,1,0}, 0.2, 1, false )
				else
					env.info("Drawing with blue ownership")
					ThreatZones[zone]["red"]:DrawZone( 1, {0,0,1}, 0.75, {1,1,0}, 0.2, 1, false )
					ThreatZones[zone]["blue"]:DrawZone( 2, {0,0,1}, 0.75, {1,1,0}, 0, 1, false )
				end
			end
		end
	end

	--local function CheckIfInsideZone(_,zone)
	--	env.info("Checking if spawn zone "..zone:GetName().." is inside sector "..tostring(sectorNumber), false)
	--	return sector:IsVec2InZone(zone:GetVec2())
	--end
	local function RemoveThreatCircle(zone)
		if ThreatZones[zone] ~= nil then
			env.info("Removing threat rings at zone "..zone:GetName())
			for key, threatZone in pairs(ThreatZones[zone]) do
				threatZone:UndrawZone()
			end
		end
	end

	for _, type in ipairs(ECWSAMTypes) do
		if AirDefenseZones[side][type][sectorNumber] == nil then 
			env.warning("Invalid zones", false)
			if AirDefense[type] == nil or AirDefense[type]:Count() <= 0 then
				env.error("Invalid or missing "..side.." "..type.." template", true)
			end
		else
			env.info("Managing "..side.." "..type.." in Sector "..tostring(sectorNumber),false)
			AirDefenseZones[side][type][sectorNumber]:ForEachZone(ManageDefenseInZone,AirDefense[type],AirDefenseResTime[type])
			if side == "red" then
				AirDefenseZones["blue"][type][sectorNumber]:ForEachZone(RemoveThreatCircle)
			else
				AirDefenseZones["red"][type][sectorNumber]:ForEachZone(RemoveThreatCircle)
			end
		end
	end
	--local zones = SET_ZONE:New():FilterPrefixes(side.." MANPADS"):FilterOnce()
--
	--zones:ForEach(ManageDefenseInZone,{AirDefense.MANPADS},zones:GetSet(),CheckIfInsideZone,{})
--
	--zones = SET_ZONE:New():FilterPrefixes(side.." HighSAM"):FilterOnce()
--
	--zones:ForEach(ManageDefenseInZone,{AirDefense.HighSAM},zones:GetSet(),CheckIfInsideZone,{})
--
	--zones = SET_ZONE:New():FilterPrefixes(side.." LowSAM"):FilterOnce()
--
	--zones:ForEach(ManageDefenseInZone,{AirDefense.LowSAM},zones:GetSet(),CheckIfInsideZone,{})
--
	--zones = SET_ZONE:New():FilterPrefixes(side.." SHORAD"):FilterOnce()
--
	--zones:ForEach(ManageDefenseInZone,{AirDefense.SHORAD},zones:GetSet(),CheckIfInsideZone,{})

end

function RemoveDefenses(side,sector)
	env.info("Clearing "..side.." units from sector "..tostring(sector), false)
	for _, group in pairs(ActiveAirDefenses[string.lower(side)][sector]) do
		env.info("Clearing group "..group:GetName(), false)
		group:Destroy(false)
	end
end

function PopulateAirDefense()

	env.info("Populating air defense", false)
	for i = 1, SectorQuantity do

		if i > ActiveFrontline then
			env.info("Populating sector "..tostring(i).." for red",false)
			SpawnDefenses("red",AirDefenseTemplates["red"],i)
		else
			env.info("Populating sector "..tostring(i).." for blue",false)
			SpawnDefenses("blue",AirDefenseTemplates["blue"],i)
		end

	end

end

function UpdateAirDefense(side, current, amount)

	local _end
	local _start
	local _inter
	if side == "BLUE" then
		_start = current + amount 
		_end = current + 1
		_inter = -1
	else
		_start = current - amount + 1
		_end = current
		_inter = 1
	end

	for i = _start,_end,_inter do
		RemoveDefenses(side,i)
		if i > current then
			SpawnDefenses("red",AirDefenseTemplates["red"],i)
		else
			SpawnDefenses("blue",AirDefenseTemplates["blue"],i)
		end
	end

end

ECW_Despawn_timer = SCHEDULER:New(nil)
function UnpopulateFrontline()

	ECW_Despawn_co = coroutine.wrap(function()
	for _, ActiveFrontlineGroup in pairs( ActiveFrontlineGroups ) do

		if ActiveFrontlineGroup then

			ActiveFrontlineGroup:Destroy( false )

		end
		coroutine.yield(true)
	end
	return false
	end)

	ECW_Despawn_timer:Stop()
	ECW_Despawn_timer:Clear()
	ECW_Despawn_timer:Schedule(nil,function()
		local cont = ECW_Despawn_co()
		if cont == false then
			ActiveFrontlineGroups = {}
			ECW_Despawn_timer:Stop()
			ECW_Despawn_timer:Clear()
		end
	end,{},1,0.5)
end

--
-- Spawn strategic Targets
--

function SpawnFrontDepots()

	local BlueFrontDepotSector = ActiveFrontline - 3
	local RedFrontDepotSector = ActiveFrontline + 4

	BlueFrontDepotLives = FrontDepotValue
	RedFrontDepotLives = FrontDepotValue

	-- Wrap around the vector here, in case there's not enough "buffer zones" make it spawn on last zone available
	if BlueFrontDepotSector < 1 then
		BlueFrontDepotSector = 1
	end

	if RedFrontDepotSector > 30 then
		RedFrontDepotSector = 30
	end

	local BlueSectorName = "Sector " .. tostring( BlueFrontDepotSector )
	local RedSectorName = "Sector " .. tostring( RedFrontDepotSector )

	local function SpawnTargets( Coalition, SectorName, FrontDepotGroupNames )

		local SpawnQuantity = 0

		if Coalition == "BLUE" then
			SpawnQuantity = FrontDepotSpawnpoints[BlueFrontDepotSector]
		else
			SpawnQuantity = FrontDepotSpawnpoints[RedFrontDepotSector]
		end

		for i = SpawnQuantity, 1, -1 do

			local SpawnName = SectorName .. " " .. "strategic " .. tostring( i )

			local SpawnZone = ZONE:New( SpawnName )

			local FrontDepot = SPAWN:NewWithAlias( FrontDepotGroupNames[math.random( #FrontDepotGroupNames )], SectorName .. " strategic target " .. tostring( i ) )

			FrontDepot:OnSpawnGroup( function( group )

					table.insert( ActiveFrontDepotGroups, group )

					local groupUnits = group:GetUnits()
					for _, unit in pairs(groupUnits) do
						TargetStatusMap[unit:GetName()] = true
					end

					local Coordinate = group:GetCoordinate()

					local MissionMarker = MARKER:New( Coordinate, Coalition .. " Front Depot " .. i ):ReadOnly():ToAll()

					table.insert( Markers, MissionMarker )

					group:HandleEvent( EVENTS.Dead )
					group:HandleEvent( EVENTS.Hit)

					local function LifeCalculation()

						env.info("Group is dead",false)

						if Coalition == "BLUE" then
							
							env.info("FrontlineTargetsValue = "..FrontlineTargetsValue..", SpawnNumbers["..BlueFrontDepotSector.."] = "..SpawnNumbers[BlueFrontDepotSector]..", Group:GetinitialSize = "..group:GetInitialSize())
							local TargetValue = FrontDepotValue / ( FrontDepotSpawnpoints[BlueFrontDepotSector] * group:GetInitialSize() )

							BlueLives = BlueLives - TargetValue

							BlueFrontDepotLives = BlueFrontDepotLives - TargetValue

							if ( BlueLives / BlueMaxLives ) * 100 <= BreakthroughThreshold  and BreakthroughInProgress == false then
								
								BreakthroughInProgress = true
								SCHEDULER:New(nil, function()
									MoveFrontline( Coalition, "Over "..tostring(100-BreakthroughThreshold).."% of BLUFOR's frontline units have been eliminated, a break through has occurred and REDFOR has gained two sectors.", 2 )
								end, {}, 5)
							end
							env.info("Health reduced by "..tostring(TargetValue),false)

						else
							env.info("FrontlineTargetsValue = "..FrontlineTargetsValue..", SpawnNumbers["..RedFrontDepotSector.."] = "..SpawnNumbers[RedFrontDepotSector]..", Group:GetinitialSize = "..group:GetInitialSize())
							local TargetValue = FrontDepotValue / ( FrontDepotSpawnpoints[RedFrontDepotSector] * group:GetInitialSize() )

							RedLives = RedLives - TargetValue

							RedFrontDepotLives = RedFrontDepotLives - TargetValue

							if ( RedLives / RedMaxLives ) * 100 <= BreakthroughThreshold and BreakthroughInProgress == false then

								BreakthroughInProgress = true
								SCHEDULER:New(nil, function()
									MoveFrontline( Coalition, "Over "..tostring(100-BreakthroughThreshold).."% of REDFOR's frontline units have been eliminated, a break through has occurred and BLUFOR has gained two sectors.", 2 )
								end, {}, 5)
							end
							env.info("Health reduced by "..tostring(TargetValue),false)

						end

						if group:CountAliveUnits() == 0 then

							MissionMarker:Remove()

						end

					end

					function group:OnEventDead(event)

						if TargetStatusMap[event.IniUnitName] == nil then return end
						LifeCalculation()
						TargetStatusMap[event.IniUnitName] = nil
					end

					function group:OnEventHit(event)
						if event.TgtUnitName ~= nil and TargetStatusMap[event.TgtUnitName] ~= nil and event.TgtUnit:GetLife() <= 1 then
							LifeCalculation()
							TargetStatusMap[event.TgtUnitName] = nil
						else return end
					end

				end

			)

			FrontDepot:SpawnInZone( SpawnZone, false )

		end

	end

	-- Populate blue frontline
	SpawnTargets( "BLUE", BlueSectorName, BlueFrontDepotGroupNames )
	-- Populate red frontline
	SpawnTargets( "RED", RedSectorName, RedFrontDepotGroupNames )

end

function DespawnFrontDepots()

	for _, ActiveFrontDepotGroup in pairs( ActiveFrontDepotGroups ) do

		if ActiveFrontDepotGroup then

			ActiveFrontDepotGroup:Destroy( false )

		end

	end

	for _, Marker in pairs( Markers ) do

		if Marker then

			Marker:Remove()

		end

	end

	ActiveFrontDepotGroups = {}
	Markers = {}

end

--
-- Build F10 menu
--
TerminatorGroups = {}
TerminatorGroups[coalition.side.RED] = {}
TerminatorGroups[coalition.side.BLUE] = {}

function BuildMenu( ClientGroup )

	local function DisplayFrontlineStatus()
	
		local c,s = "",""
		local newFrontlineMoveThreshold = util.round(attrition.calculate(), 2)
		if newFrontlineMoveThreshold < 50 then
			newFrontlineMoveThreshold = 50
		end
		
		
		if BlueLives > RedLives then
			c = "Blue"
		elseif RedLives > BlueLives then
			c = "Red"
		else
			c = nil
		end
		
		if c ~= nil then
			s = "Move Threshold for ".. c ..": ".. tostring(newFrontlineMoveThreshold)
		else
			s = ""
		end
		
		local blueFrontlineHealth 	= "\nBLUFOR Frontline: "..tostring(math.floor(BlueFrontLineLives + 0.5 ) ) .. "/".. tostring( FrontlineTargetsValue )
		local blueFrontDepotHealth 	= "\nBLUFOR Depots: "..tostring(math.floor(BlueFrontDepotLives + 0.5 ) ) .. "/".. tostring( FrontDepotValue )
		local blueIndustrialHealth 	= "\nBLUFOR Industrial: "..tostring(math.floor((BlueLives - BlueFrontLineLives - BlueFrontDepotLives ) + 0.5 ) ) .. "/".. tostring( StrategicTargetValue )
		local blueCSARSaves 		= "\nBLUFOR Pilots Saved: "..tostring(attrition.blueCSAR)
		local blueTroopInsertions	= "\nBLUFOR Troop Insertions: "..tostring(infantry.blueCounter)
		local blueAttrition 		= "\nBLUFOR Attrition: "..tostring(attrition.sideTable[2] - attrition.initialValueBlue)
		local redFrontlineHealth 	= "\nREDFOR Frontline: "..tostring(math.floor(RedFrontLineLives + 0.5 ) ) .. "/".. tostring( FrontlineTargetsValue )
		local redFrontDepotHealth 	= "\nREDFOR Depots: "..tostring(math.floor(RedFrontDepotLives + 0.5 ) ) .. "/".. tostring( FrontDepotValue )
		local redIndustrialHealth 	= "\nREDFOR Industrial: "..tostring(math.floor((RedLives - RedFrontLineLives - RedFrontDepotLives ) + 0.5 ) ) .. "/".. tostring( StrategicTargetValue )
		local redCSARSaves 			= "\nREDFOR Pilots Saved: "..tostring(attrition.redCSAR)
		local redTroopInsertions	= "\nREDFOR Troop Insertions: "..tostring(infantry.redCounter)
		local redAttrition 			= "\nREDFOR Attrition: "..tostring(attrition.sideTable[1] - attrition.initialValueRed)
		
		MESSAGE:New( "BLUFOR Health: " .. tostring( math.floor( BlueLives + 0.5 ) ) .. "/" .. tostring( BlueMaxLives ) .. blueFrontlineHealth .. blueFrontDepotHealth .. blueIndustrialHealth..blueCSARSaves..blueTroopInsertions..blueAttrition, 30 ):ToGroup( ClientGroup )
		MESSAGE:New( "REDFOR Health: " .. tostring( math.floor( RedLives + 0.5 ) ) .. "/" .. tostring( RedMaxLives ).. redFrontlineHealth .. redFrontDepotHealth .. redIndustrialHealth..redCSARSaves..redTroopInsertions..redAttrition, 30 ):ToGroup( ClientGroup )
		MESSAGE:New( s, 30 ):ToGroup( ClientGroup )

	end

	local FrontlineStatus = MENU_GROUP_COMMAND:New( ClientGroup, "Frontline Status", nil, function()
			DisplayFrontlineStatus()
		end 
	
		)

	if DebugMode then
		local function radioCompareFrontLineCommand()
			MESSAGE:New( "Comparing Frontline health...", 30 ):ToGroup( ClientGroup )
			CompareFrontlines()
		end
		local FrontlineComparison = MENU_GROUP_COMMAND:New( ClientGroup, "Force Frontline Compare", nil, function()
				radioCompareFrontLineCommand()
			end 
		)
		local ForceFrontline = MENU_GROUP_COMMAND:New( ClientGroup, "Force frontline back", nil, function()
				MoveFrontline( "BLUE", "DEV is nuts and serves to the soviet union.", 1 )
			end
		)
		local ForceFrontlineFore = MENU_GROUP_COMMAND:New( ClientGroup, "Force frontline foreward", nil, function()
				MoveFrontline( "RED", "Imperialists are getting desperate", 1 )
			end
		)
		--local ForceRedBomber = MENU_GROUP_COMMAND:New( ClientGroup, "Force Red Bombers", nil, function()
		--		RedBomberInit1()
		--	end
		--)
		--local ForceBlueBomber = MENU_GROUP_COMMAND:New( ClientGroup, "Force Blue Bombers", nil, function()
		--		BlueBomberInit1()
		--	end
		--)

		local function ExplodeGroup(group,delay)
			local units = group:GetUnits()
			for _,unit in pairs(units) do
				unit:Explode(10000,delay)
			end
		end

		local function YeetHalf(side, objects)
			local total=0
			for i,group in ipairs(objects) do
				if group:GetCoalition() == side then
					total=total+1
				end
			end
			local counter = 0
			for i,group in ipairs(objects) do
				if group:GetCoalition() == side then
					ExplodeGroup(group,counter)
					counter = counter+1
				end
				if counter >= total/2 then break end
			end
		end

		local function YeetAll(side, objects)
			local counter = 0
			for i, group in ipairs(objects) do
				if group:GetCoalition() == side then
					ExplodeGroup(group,counter)
					counter = counter + 1
				end
			end
		end

		local function YeetHalfStatics(set)
			local counter = 0
			local max = set:Count()/2
			set:ForEachStatic(function(static)
				if counter < max then
					local coord = static:GetCoordinate()
					coord:Explosion(50000, 1)
				end
				counter = counter + 1
			end)
		end

		local function YeetAllStatics(set)
			set:ForEachStatic(function(static)
				local coord = static:GetCoordinate()
				coord:Explosion(50000, 1)
			end)
		end

		local DestroySubmenu = MENU_GROUP:New(ClientGroup, "Destroy objects")

		local DestroyFrontlineSubmenu = MENU_GROUP:New(ClientGroup, "Destroy Frontline Objects", DestroySubmenu)
		local DestroyDepotSubmenu = MENU_GROUP:New(ClientGroup, "Destroy Depot Objects", DestroySubmenu)
		local DestroyIndustrialSubmenu = MENU_GROUP:New(ClientGroup, "Destroy Industrial Objects", DestroySubmenu)
		local FrontlineTerminatorSubmenu = MENU_GROUP:New(ClientGroup, "Spawn Terminators", DestroySubmenu)
		--local DepotTerminatorSubmenu = MENU_GROUP:New(ClientGroup, "Spawn Terminators for Depots", DestroySubmenu)

		
		local DestroyHalfBlueFrontline = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Blue Frontline", DestroyFrontlineSubmenu, function()
			YeetHalf(coalition.side.BLUE, ActiveFrontlineGroups)
		end)

		local DestroyAllBlueFrontline = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Blue Frontline", DestroyFrontlineSubmenu, function()
			YeetAll(coalition.side.BLUE, ActiveFrontlineGroups)
		end)

		local DestroyHalfRedFrontline = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Red Frontline", DestroyFrontlineSubmenu, function()
			YeetHalf(coalition.side.RED, ActiveFrontlineGroups)
		end)

		local DestroyAllRedFrontline = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Red Frontline", DestroyFrontlineSubmenu, function()
			YeetAll(coalition.side.RED, ActiveFrontlineGroups)
		end)

		local DestroyHalfBlueDepots = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Blue Depots", DestroyDepotSubmenu, function()
			YeetHalf(coalition.side.BLUE, ActiveFrontDepotGroups)
		end)

		local DestroyAllBlueDepots = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Blue Depots", DestroyDepotSubmenu, function()
			YeetAll(coalition.side.BLUE, ActiveFrontDepotGroups)
		end)

		local DestroyHalfRedDepots = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Red Depots", DestroyDepotSubmenu, function()
			YeetHalf(coalition.side.RED, ActiveFrontDepotGroups)
		end)

		local DestroyAllRedDepots = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Red Depots", DestroyDepotSubmenu, function()
			YeetAll(coalition.side.RED, ActiveFrontDepotGroups)
		end)

		local DestroyHalfBlueIndustrial = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Blue Industry", DestroyIndustrialSubmenu, function()
			YeetHalfStatics(StrategicTargets["blue"].set)
		end)

		local DestroyAllBlueIndustrial = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Blue Industry", DestroyIndustrialSubmenu, function()
			YeetAllStatics(StrategicTargets["blue"].set)
		end)

		local DestroyHalfRedIndustrial = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy Half of Red Industry", DestroyIndustrialSubmenu, function()
			YeetHalfStatics(StrategicTargets["red"].set)
		end)

		local DestroyAllRedIndustrial = MENU_GROUP_COMMAND:New( ClientGroup, "Destroy All of Red Industry", DestroyIndustrialSubmenu, function()
			YeetAllStatics(StrategicTargets["red"].set)
		end)

		local function SpawnTerminators(groups, side)
			local spawn
			if side == coalition.side.RED then
				spawn = SPAWN:New("terminator blue")
			else
				spawn = SPAWN:New("terminator red")
			end
			spawn:InitRandomizePosition(true,50,100)
			
			for _, group in pairs(groups) do
				if group:GetCoalition() == side then
					table.insert(TerminatorGroups[side],spawn:SpawnFromUnit(group:GetUnit(1)):SetCommandImmortal(true):OptionROE(ENUMS.ROE.WeaponFree))
				end
			end
		end

		local function DespawnTerminators(side)
			for i,group in pairs(TerminatorGroups[side]) do
				group:Destroy()
			end
		end

		local RedFrontlineTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Spawn Terminators for Red Frontline", FrontlineTerminatorSubmenu, function()
			SpawnTerminators(ActiveFrontlineGroups, coalition.side.RED)
		end)
				
		local BlueFrontlineTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Spawn Terminators for Blue Frontline", FrontlineTerminatorSubmenu, function()
			SpawnTerminators(ActiveFrontlineGroups, coalition.side.BLUE)
		end)
				
		local RedDepotTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Spawn Terminators for Red Depots", FrontlineTerminatorSubmenu, function()
			SpawnTerminators(ActiveFrontDepotGroups, coalition.side.RED)
		end)
				
		local BlueDepotlineTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Spawn Terminators for Blue Depots", FrontlineTerminatorSubmenu, function()
			SpawnTerminators(ActiveFrontDepotGroups, coalition.side.BLUE)
		end)
				
		local RedRemoveTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Remove Terminators for Red", FrontlineTerminatorSubmenu, function()
			DespawnTerminators(coalition.side.RED)
		end)
				
		local BlueRemoveTerminators = MENU_GROUP_COMMAND:New(ClientGroup, "Remove Terminators for Blue", FrontlineTerminatorSubmenu, function()
			DespawnTerminators(coalition.side.BLUE)
		end)

		
				

	end
end


--
-- Check if airbase is active on client spawn
--

 function SpawnCheck( ClientGroup )

	--local BlueAirbase = ZONE:FindByName( "Senaki-Kolkhi" )
	--local RedAirbase = ZONE:FindByName( "Kutaisi" )

	if ClientGroup:GetCategoryName() == "Airplane" or ClientGroup:GetCategoryName() == "Helicopter" then

		-- Hacky exemption for attack aircraft - temporary, will be changed when slot blocking is redone
		function AttackAircraftSpawnCheck()
			local GroupUnit = ClientGroup:GetUnit(1)
			local result = false
			if (GroupUnit:GetTypeName() == "A-10A" or GroupUnit:GetTypeName() == "Su-25") then
				local side = ClientGroup:GetCoalition()
				env.info("Detected attacker of coalition "..tostring(side),false)
				local _dir
				local _start
				local _end
				if side == coalition.side.BLUE then 
					_dir = -1
					_start = ActiveFrontline
					_end = 1
				else
					_dir = 1
					_start = ActiveFrontline+1
					_end = SectorQuantity
				end
				
				for i = _start, _end, _dir do
					local secname = "Sector "..tostring(i)
					env.info("Checking if in "..secname,false)
					local sector = ZONE_POLYGON:NewFromGroupName(secname)
					if ClientGroup:IsInZone(sector) then
						env.info("Found in "..secname, false)
						result = true
						break
					end
				end

			end
			return result
		end

		local function CheckAirbase( Coalition, Airbase, SecAirbase )

			if ClientGroup:IsInZone( Airbase ) then
			
				if SecAirbase == false and AttackAircraftSpawnCheck() == false then

					local MessageRepeater = nil
					local Timer = 30
					local DestroyDelay = nil

					local function RepeatMessage()

						if Timer <= 0 then

							MESSAGE:New( "Clearing slot "..ClientGroup:GetName(), 30 ):ToGroup( ClientGroup )
							MessageRepeater:Stop()

						else

							MESSAGE:New( "\n\nThis airbase is not active!\nPlease read the mission briefing and change slot!\n\nYou will be despawned in " .. tostring( Timer ) .. " seconds!", 30,"WARNING",true ):ToGroup( ClientGroup )

							Timer = Timer - 10

						end

					end

					local function DestroyGroup()

						--ClientGroup:Destroy( true )
--
						
						--env.info("Setting User Flag "..ClientGroup:GetName().." to 100",false)
						trigger.action.setUserFlag(ClientGroup:GetName(),100)
						DestroyDelay:Stop()

					end

					MessageRepeater = SCHEDULER:New( nil, RepeatMessage, {}, 0, 10 )
					DestroyDelay = SCHEDULER:New( nil, DestroyGroup, {}, 31, 0 )
					return true
				else
					return false
				end
			else
				return false
			end
		end

--[[ 		if ClientGroup:GetCoalition() == coalition.side.BLUE then
			CheckAirbase( "BLUE", BlueAirbase, BlueSecAirbase )
		else
			CheckAirbase( "RED", RedAirbase, RedSecAirbase )	
		end ]]

		for _base,_status in pairs(BlockedFields[ClientGroup:GetCoalition()]) do
			local _zone = ZONE:FindByName(_base)
			if CheckAirbase(nil, _zone,_status) then break end
		end

	end

 end


function UpdateBases()
	for _side, _bases in pairs(BlockedFields) do
		for _base, _status in pairs(_bases) do		--not ideal, but there won't be enough bases in mission for this to be a problem
			local _pre = string.sub(_base,1,4)
			env.info("Checking base ".._base.." with a prefix ".._pre,false)
			if _pre == "BLUE" and _side == coalition.side.BLUE then
				env.info("Side is BLUE, checking sector",false)
				local _num = tonumber(string.sub(_base,6,7))
				env.info("Sector is "..tostring(_num).. " with current frontline being "..tostring(ActiveFrontline),false)
				if _num~=nil and ActiveFrontline >= _num then
					env.info("Sector belongs to blue, opening airbase",false)
					BlockedFields[_side][_base] = true
				else
					env.info("Sector belongs to red, closing airbase",false)
					BlockedFields[_side][_base] = false
				end
			elseif _pre == "RED_" and _side == coalition.side.RED then
				env.info("Side is RED, checking sector",false)
				local _num = tonumber(string.sub(_base,5,6))
				env.info("Sector is "..tostring(_num).. " with current frontline being "..tostring(ActiveFrontline),false)
				if _num~=nil and ActiveFrontline < _num then
					env.info("Sector belongs to red, opening airbase",false)
					BlockedFields[_side][_base] = true
				else
					env.info("Sector belongs to blue, closing airbase",false)
					BlockedFields[_side][_base] = false
				end
			end
		end
	end
end
--
-- First inizialisation
--
PopulateFarps()
RestoreState()
InitDrawFrontline()
PopulateFrontline()
SpawnFrontDepots()

local resduration = 14400

RebootMessages = SCHEDULER:New(nil, function ()
	MESSAGE:New("Server restart in 15 minutes",30,"WARNING",false):ToAll()
end,{},resduration - 900)
RebootMessages:Schedule(nil, function ()
	MESSAGE:New("Server restart in 5 minutes",30,"WARNING",false):ToAll()
end,{},resduration - 300)
RebootMessages:Schedule(nil, function ()
	MESSAGE:New("Server restart in 1 minute",30,"WARNING",false):ToAll()
end,{},resduration - 60)

-- SmokeScheduler = SCHEDULER:New( nil, SmokeFrontline, {}, 0, 300 )
PopulateAirDefense()
SpawnEventHandler = EVENTHANDLER:New()

SpawnEventHandler:HandleEvent( EVENTS.Birth )

--UpdateBases()

function SpawnEventHandler:OnEventBirth( EventData )

	--local UnitName = EventData.IniUnit:GetName()
	--local Unit = UNIT:FindByName( UnitName )
	local ClientGroup = EventData.IniUnit:GetGroup()

	--SpawnCheck( ClientGroup )

	BuildMenu( ClientGroup )

end

function PersistFrontline()
	log.write("base", log.INFO, "Will try to persist state\n")

	local frontFile = io.open(lfs.writedir() .. '.frontline', 'w+')

	if frontFile then
		-- Rewind the file to make sure we are at the beggining of it
		frontFile:write(ActiveFrontline)
		-- Forcefully sync the file to disk
		frontFile:flush()
		frontFile:close()

		log.write("base", log.INFO, "Mission state persisted into file, Frontline = " ..tostring(ActiveFrontline) .. "\n")
	else
		log.write("base", log.ERROR, "Could not open frontline file, won't be able to persist mission state\n")
		return
	end

end

function SetUserFlag( flag, value )
	trigger.action.setUserFlag(flag, value)
end

function FinishCampaign( Coalition )
	local winnerCoalition

	if Coalition == "BLUE" then
		winnerCoalition = "RED"
	else
		winnerCoalition = "BLUE"
	end

	MESSAGE:New(
		winnerCoalition .. " WON THE CAMPAIGN! CONGRATULATIONS!\n The mission will reset in " ..tostring(RestartMission) .. " seconds \n"):ToAll()

	local frontFilePath = lfs.writedir() .. ".frontline"
	log.write("base", log.INFO, "Campaign ended, removing frontline file and loading next mission in " ..tostring(RestartMission) .. " seconds\n")

	local flagSchedule = SCHEDULER:New( nil, SetUserFlag, {"1", true}, RestartMission )

	os.remove(frontFilePath)
end

-- Export sectors of each base to flags for access from net

function ExportLocations()

	--export roadstrips/farps

	local sectors = {}
	
	for i=1, SectorQuantity do
		sectors[i] = ZONE_POLYGON:NewFromGroupName("Sector "..tostring(i))
	end

	local function ExportZone(base)
		local target = trigger.misc.getZone(base)
		if not target then return end
		local targetVec2 = {
			x = target.point.x,
			y = target.point.z,
		}
		for i, zone in ipairs(sectors) do
			if zone:IsVec2InZone(targetVec2) then
				env.info("Exporting: "..base.." in sector "..tostring(i))
				SetUserFlag(base, i)
				break
			end
		end
	end

	for base, status in pairs(BlockedFields[coalition.side.RED]) do
		ExportZone(base)
	end
	
	for base, status in pairs(BlockedFields[coalition.side.BLUE]) do
		ExportZone(base)
	end

	local function ExportAirbase(base, i)

		env.info("Exporting: "..base.." in sector "..tostring(i))
		SetUserFlag(base, i)
		--hack because Senaki:
		if base == "Senaki-Kolkhi" then
			env.info("Exporting: Senaki in sector "..tostring(i))
			SetUserFlag("Senaki", i)
		end
		--hack because tbilisi:
		if base == "Tbilisi-Lochini" then
			env.info("Exporting: Tbilisi in sector "..tostring(i))
			SetUserFlag("Tbilisi", i)
		end

	end

	--export map bases
	local airbases = AIRBASE.GetAllAirbases(nil,nil)
	env.info("Airbase table length: "..tostring(#airbases))
	for _, base in pairs(airbases) do
		env.info("Airbase: "..base.AirbaseName)
		ExportAirbase(base.AirbaseName, -1)
		local targetVec3 = base:GetPointVec3()
		local targetVec2 = {
			x= targetVec3.x,
			y= targetVec3.z,
		}
		env.info("Location: x="..tostring(targetVec2.x).." y="..tostring(targetVec2.y))
		for i, zone in ipairs(sectors) do
			if zone:IsVec2InZone(targetVec2) then
				ExportAirbase(base.AirbaseName, i)
				break
			end
		end

		--if a zone with same name exists, prefer its location rather than one pulled from database to define the Airfield location

		ExportZone(base.AirbaseName)

	end

end

ExportLocations()
--
-- Move frontline
--

FrontlineSpawnScheduler = SCHEDULER:New(nil)
function MoveFrontline( Coalition, Message, Amount )

	MESSAGE:New( Message, 60 ):ToAll()

	--UndrawFrontline()
	UnpopulateFrontline()
	DespawnFrontDepots()

	--SmokeScheduler:Stop()

	if Coalition == "BLUE" then

		ActiveFrontline = ActiveFrontline - Amount

	else

		ActiveFrontline = ActiveFrontline + Amount

	end

	 if ActiveFrontline <= 0 or ActiveFrontline >= 30 then
                if ActiveFrontline < 0 then
                        ActiveFrontline = 0
                elseif ActiveFrontline > 30 then
                        ActiveFrontline = 30
                end

                FinishCampaign(Coalition)
        else

		UpdateAirDefense(Coalition, ActiveFrontline, Amount)
		--update bases

		--UpdateBases()


--[[ 	if ActiveFrontline >= 25 then

		--BlueSecAirbase = true
		BlockedFields[coalition.side.BLUE]['Senaki-Kolkhi'] = true

	elseif ActiveFrontline < 25 then

		--BlueSecAirbase = false
		BlockedFields[coalition.side.BLUE]['Senaki-Kolkhi'] = false

	end

	if ActiveFrontline <= 5 then

		--RedSecAirbase = true
		BlockedFields[coalition.side.RED]['Kutaisi'] = true

	elseif ActiveFrontline > 5 then

		--RedSecAirbase = false
		BlockedFields[coalition.side.RED]['Kutaisi'] = false

	end ]]

		UpdateDrawFrontline()
		FrontlineSpawnScheduler:Stop()
		FrontlineSpawnScheduler:Clear()
		FrontlineSpawnScheduler:Schedule(nil, PopulateFrontline, {}, 60)
		SpawnFrontDepots()
		PersistFrontline()
	--SmokeScheduler = SCHEDULER:New( nil, SmokeFrontline, {}, 0, 300 )
		BreakthroughInProgress = false

	end
end

--
-- Frontline timeout
--

FrontlineScheduler = nil

function CompareFrontlines()
	
	-- modify FrontlineMoveThreshold with attrition rate
	
	local newFrontlineMoveThreshold = util.round(attrition.calculate(), 2)
	
	if newFrontlineMoveThreshold < 50 then
		newFrontlineMoveThreshold = 50
	end
	
	if math.abs( BlueLives - RedLives ) >= newFrontlineMoveThreshold then

		if BlueLives > RedLives then
			MoveFrontline( "RED", "BLUFOR has gained a "..tostring((newFrontlineMoveThreshold/RedMaxLives)*100).."% variance in frontline health and will push to gain a new sector.", 1 )
			attrition.reset()
		elseif RedLives > BlueLives then
			MoveFrontline( "BLUE", "REDFOR has gained a "..tostring((newFrontlineMoveThreshold/BlueMaxLives)*100).."% variance in frontline health and will push to gain a new sector.", 1 )
			attrition.reset()
		end
	elseif 	math.abs( BlueLives - RedLives ) < newFrontlineMoveThreshold then
		MESSAGE:New( "No Frontline Movement On This Check", 30 ):ToAll()		
		MESSAGE:New( "Frontline Move Threshold = " .. tostring( newFrontlineMoveThreshold ) .. "\nBreakthrough Threshold = " .. tostring( BreakthroughThreshold ), 30 ):ToAll()
	end
	
	trigger.action.setUserFlag("frontline",ActiveFrontline)
end

FrontlineScheduler = SCHEDULER:New( nil, CompareFrontlines, {}, FrontlineTimeout, FrontlineTimeout )

env.info("base.lua loaded")