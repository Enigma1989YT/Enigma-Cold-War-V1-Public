--function AirspaceProtection( ClientGroupNames, Airspace )
--
--	for _, ClientGroupName in pairs( ClientGroupNames ) do
--
--		local ClientGroup = GROUP:FindByName( ClientGroupName )
--
--		if ClientGroup then
--
--			local CheckScheduler = nil
--
--			function CheckInZone()
--
--				if ClientGroup:IsInZone( Airspace ) then
--
--					MESSAGE:New( "You just entered prohibited airspace, you got 1 minutes to leave!", 60 ):ToGroup( ClientGroup )
--
--					CheckScheduler:Stop()
--
--					local DestructionScheduler = nil
--
--					function DestroyGroup()
--
--						DestructionScheduler:Stop()
--
--						ClientGroup:Destroy( true )
--
--					end
--
--					DestructionScheduler = SCHEDULER:New( nil, DestroyGroup, {}, 60, 1 )
--
--				end
--
--			end
--
--			CheckScheduler = SCHEDULER:New( nil, CheckInZone, {}, 1, 10 )
--
--		end
--
--	end
--
--end

ActiveClientSet = {}
ActiveClientSet["blue"] = SET_CLIENT:New():FilterActive():FilterCoalitions("blue"):SetIteratorIntervals(3,0.05):FilterStart()
ActiveClientSet["red"] = SET_CLIENT:New():FilterActive():FilterCoalitions("red"):SetIteratorIntervals(3,0.05):FilterStart()

BlueAirspace = ZONE:FindByName( "Blue airspace" )
RedAirspace = ZONE:FindByName( "Red airspace" )

BlueAirspace:DrawZone( -1, {0,0,1}, 0.75, {0,0,1}, 0, 1, true )
RedAirspace:DrawZone( -1, {1,0,0}, 0.75, {1,0,0}, 0, 1, true )

--AirspaceProtection( BlueClientGroupNames, RedAirspace )
--AirspaceProtection( RedClientGroupNames, BlueAirspace )

DeathDomeSchedule = SCHEDULER:New()
DeathDomeScheduleData = {}

function DeathDome(client, zone)
	local _id = client:GetID()
	env.info("Checking client " .. (_id or "unk"), false)
	local _zoneObject = ZONE:FindByName(zone)

	function DeathDomeTimer()
		local _message = MESSAGE:New(string.format("You have entered a restricted area, you have %d seconds to leave",DeathDomeScheduleData[_id].timer),5, "WARNING", true)
		_message:ToClient(client)
		--local _zoneObject = ZONE:FindByName(zone)
		env.info("Counting down to destruction",false)
		if client:IsNotInZone(_zoneObject) or not client:IsAlive() then
			DeathDomeScheduleData[_id].sched:Stop()
			DeathDomeScheduleData[_id] = nil
			env.info("Player died or left zone", false)
			return
		elseif DeathDomeScheduleData[_id].timer <= 0 then
			DeathDomeScheduleData[_id].sched:Stop()
			DeathDomeScheduleData[_id] = nil
			client:Explode(500,0)
			env.info("Player destroyed")
			return
		end
		DeathDomeScheduleData[_id].timer = DeathDomeScheduleData[_id].timer - 1
	end

	if _id == nil or DeathDomeScheduleData[_id] ~= nil then return
	else 
		DeathDomeScheduleData[_id] = {}
		DeathDomeScheduleData[_id].sched = SCHEDULER:New(nil,DeathDomeTimer,{},1,1,0,31)
		DeathDomeScheduleData[_id].timer = 30 
	end
end

function DeathDomeSearch(side, zone)
	--env.info("Searching "..side, false)
	local _zoneObject = ZONE:FindByName(zone)
	--env.info(tostring(ActiveClientSet[side]:Count()).." active clients on this side")
	ActiveClientSet[side]:ForEachClientInZone(_zoneObject, DeathDome, zone)
end

--uncomment to enable
DeathDomeSchedule:Schedule(nil,DeathDomeSearch,{"blue", "Red airspace"},2,4)
DeathDomeSchedule:Schedule(nil,DeathDomeSearch,{"red", "Blue airspace"},4,4)

-- MESSAGE:New( "All loaded!", 10, "Scripts" ):ToAll()