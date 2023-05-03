-- Initiate functions
MoveFrontline = nil

--
-- Draw sectors (Z) on F10 map
--

function DrawFrontline()

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

function UndrawFrontline()

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

	ActiveFrontlineSector:SmokeZone( SMOKECOLOR.White, 10 )

	local StaticName = "Frontline " .. tostring( ActiveFrontline ) .. " marker 1"

end

--
-- Populate frontline
--

function PopulateFrontline()

	local BlueActiveSector = ActiveFrontline
	local RedActiveSector = ActiveFrontline + 1

	local BlueSectorName = "Sector " .. tostring( BlueActiveSector )
	local RedSectorName = "Sector " .. tostring( RedActiveSector )

	local function SpawnTargets( Coalition, SectorName, FrontlineGroups )

		if Coalition == "BLUE" then
			SpawnQuantity = FrontlineSpawnpoints[BlueActiveSector]
			BlueLives = BlueMaxLives
		else
			SpawnQuantity = FrontlineSpawnpoints[RedActiveSector]
			RedLives = RedMaxLives
		end

		for i = SpawnQuantity, 1, -1 do

			local SpawnName = SectorName .. " " .. "spawnpoint " .. tostring( i )

			local SpawnZone = ZONE:New( SpawnName )

			local FrontlineTarget = SPAWN:NewWithAlias( FrontlineGroups[math.random( #FrontlineGroups )], SectorName .. " target " .. tostring( i ) )

			FrontlineTarget:OnSpawnGroup( function( Group )

					table.insert( ActiveFrontlineGroups, Group )

					Group:HandleEvent( EVENTS.Dead )

					function Group:OnEventDead()

						if Coalition == "BLUE" then

							local TargetValue = FrontlineTargetsValue / ( FrontlineSpawnpoints[BlueActiveSector] * AvarageFrontlineUnits )

							BlueLives = BlueLives - TargetValue

							if ( BlueLives * BlueMaxLives ) / 100 <= 20 then

								MoveFrontline( Coalition, "Over 80% of BLUFOR's frontline units have been eliminated, a break through has occurred and REDFOR has gained two sectors.", 2 )

							end

						else

							local TargetValue = FrontlineTargetsValue / ( FrontlineSpawnpoints[RedActiveSector] * AvarageFrontlineUnits )

							RedLives = RedLives - TargetValue

							if ( RedLives * RedMaxLives ) / 100 <= 20 then

								MoveFrontline( Coalition, "Over 80% of REDFOR's frontline units have been eliminated, a break through has occurred and BLUFOR has gained two sectors.", 2 )

							end

						end

					end

				end

			)

			FrontlineTarget:SpawnInZone( SpawnZone, false )

		end

	end

	-- Populate blue frontline
	SpawnTargets( "BLUE", BlueSectorName, BlueFrontlineGroups )
	-- Populate red frontline
	SpawnTargets( "RED", RedSectorName, RedFrontlineGroups )

end

function UnpopulateFrontline()

	for _, ActiveFrontlineGroup in pairs( ActiveFrontlineGroups ) do

		if ActiveFrontlineGroup then

			ActiveFrontlineGroup:Destroy( false )

		end

	end

	ActiveFrontlineGroups = {}

end

--
-- Spawn strategic Targets
--

function SpawnFrontDepots()

	local BlueFrontDepotSector = ActiveFrontline - 3
	local RedFrontDepotSector = ActiveFrontline + 4

	local BlueSectorName = "Sector " .. tostring( BlueFrontDepotSector )
	local RedSectorName = "Sector " .. tostring( RedFrontDepotSector )

	local function SpawnTargets( Coalition, SectorName, FrontDepotGroupNames )

		if Coalition == "BLUE" then
			SpawnQuantity = FrontDepotSpawnpoints[BlueFrontDepotSector]
		else
			SpawnQuantity = FrontDepotSpawnpoints[RedFrontDepotSector]
		end

		for i = SpawnQuantity, 1, -1 do

			local SpawnName = SectorName .. " " .. "strategic " .. tostring( i )

			local SpawnZone = ZONE:New( SpawnName )

			local FrontDepot = SPAWN:NewWithAlias( FrontDepotGroupNames[math.random( #FrontDepotGroupNames )], SectorName .. " strategic target " .. tostring( i ) )

			FrontDepot:OnSpawnGroup( function( Group )

					table.insert( ActiveFrontDepotGroups, Group )

					local Coordinate = Group:GetCoordinate()

					local MissionMarker = MARKER:New( Coordinate, Coalition .. "strategic target " .. i ):ToBlue()

					table.insert( Markers, MissionMarker )

					Group:HandleEvent( EVENTS.Dead )

					function Group:OnEventDead()

						if Coalition == "BLUE" then
							
							local TargetValue = FrontDepotValue / ( FrontDepotSpawnpoints[BlueFrontDepotSector] * AvarageFrontDepotUnits )

							BlueLives = BlueLives - TargetValue

							if ( BlueLives * BlueMaxLives ) / 100 <= 20 then

								MoveFrontline( Coalition, "Over 80% of BLUFOR's frontline units have been eliminated, a break through has occurred and REDFOR has gained two sectors.", 2 )

							end

						else

							local TargetValue = FrontDepotValue / ( FrontDepotSpawnpoints[RedFrontDepotSector] * AvarageFrontDepotUnits )

							RedLives = RedLives - TargetValue

							if ( RedLives * RedMaxLives ) / 100 <= 20 then

								MoveFrontline( Coalition, "Over 80% of REDFOR's frontline units have been eliminated, a break through has occurred and BLUFOR has gained two sectors.", 2 )

							end

						end

						if Group:CountAliveUnits() == 0 then

							MissionMarker:Remove()

						end

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

function BuildMenu( ClientGroup )

	local function DisplayFrontlineStatus()

		MESSAGE:New( "BLUFOR frontline health: " .. tostring( math.floor( BlueLives + 0.5 ) ) .. "/" .. tostring( BlueMaxLives ) .. "\nREDFOR frontline health: " .. tostring( math.floor( RedLives + 0.5 ) ) .. "/" .. tostring( RedMaxLives ), 30 ):ToGroup( ClientGroup )

	end

	local FrontlineStatus = MENU_GROUP_COMMAND:New( ClientGroup, "Frontline Status", nil, function()
			DisplayFrontlineStatus()
		end 
	)

end

--
-- Check if airbase is active on client spawn
--

-- function SpawnCheck( ClientGroup )

--	local BlueAirbase = ZONE:FindByName( "Senaki-Kolkhi" )
--	local RedAirbase = ZONE:FindByName( "Kutaisi" )

--	if ClientGroup:GetCategoryName() == "Airplane" then

--		local function CheckAirbase( Coalition, Airbase, SecAirbase )

--			if ClientGroup:IsInZone( Airbase ) then
			
--				if SecAirbase == false then

--					local MessageRepeater = nil
--					local Timer = 15
--					local DestroyDelay = nil

--					local function MessageRepeater()

--						if Timer == 0 then

--							MessageRepeater:Stop()

--						else

--							MESSAGE:New( "WARNING!\n\nThis airbase is not active!\nPlease read the mission briefing and change slot!\n\nYou will be despawned in " .. tostring( Timer ) .. " seconds!", 30 ):ToGroup( ClientGroup )

--							Timer = Timer - 5

--						end

--					end

--					local function DestroyGroup()

--						ClientGroup:Destroy( true )

--						DestroyDelay:Stop()

--					end

--					MessageRepeater = SCHEDULER:New( nil, MessageRepeater, {}, 0, 5 )
--					DestroyDelay = SCHEDULER:New( nil, DestroyGroup, {}, 15, 0 )

--				end

--			end

--		end

--		if ClientGroup:GetCoalition() == coalition.side.BLUE then
--			CheckAirbase( "BLUE", BlueAirbase, BlueSecAirbase )
--		else
--			CheckAirbase( "RED", RedAirbase, RedSecAirbase )	
--		end

--	end

-- end

--
-- First inizialisation
--

DrawFrontline()
PopulateFrontline()
SpawnFrontDepots()

SmokeScheduler = SCHEDULER:New( nil, SmokeFrontline, {}, 0, 300 )

SpawnEventHandler = EVENTHANDLER:New()

SpawnEventHandler:HandleEvent( EVENTS.Birth )

function SpawnEventHandler:OnEventBirth( EventData )

	local UnitName = EventData.IniUnit:GetName()
	local Unit = UNIT:FindByName( UnitName )
	local ClientGroup = Unit:GetGroup()

--	SpawnCheck( ClientGroup )

	BuildMenu( ClientGroup )

end

--
-- Move frontline
--

function MoveFrontline( Coalition, Message, Amount )

	MESSAGE:New( Message, 60 ):ToAll()

	UndrawFrontline()
	UnpopulateFrontline()
	DespawnFrontDepots()

	SmokeScheduler:Stop()

	if Coalition == "BLUE" then

		ActiveFrontline = ActiveFrontline - Amount

	else

		ActiveFrontline = ActiveFrontline + Amount

	end

	if ActiveFrontline >= 25 then

		BlueSecAirbase = true

	elseif ActiveFrontline < 25 then

		BlueSecAirbase = false

	end

	if ActiveFrontline <= 5 then

		RedSecAirbase = true

	elseif ActiveFrontline > 5 then

		RedSecAirbase = false

	end

	DrawFrontline()
	PopulateFrontline()
	SpawnFrontDepots()

	SmokeScheduler = SCHEDULER:New( nil, SmokeFrontline, {}, 0, 300 )

end

--
-- Frontline timeout
--

FrontlineScheduler = nil

function CompareFrontlines()

	if math.abs( BlueLives - RedLives ) >= 200 then

		if BlueLives > RedLives then
			MoveFrontline( "RED", "BLUFOR has gained a 20% variance in frontline health and will push to gain a new sector.", 1 )
		elseif RedLives > BlueLives then
			MoveFrontline( "BLUE", "REDFOR has gained a 20% variance in frontline health and will push to gain a new sector.", 1 )
		end

	end

end

FrontlineScheduler = SCHEDULER:New( nil, CompareFrontlines, {}, FrontlineTimeout, FrontlineTimeout )