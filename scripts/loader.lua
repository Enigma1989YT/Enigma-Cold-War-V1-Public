local loader = {}
loader.rootdir = lfs.writedir().."/Missions/ECW/"
loader.scriptsdir = loader.rootdir.."/scripts"
loader.interval = 2
loader.files = {}
loader.files.caucasus = {
    "variables",
    "collection",
    "base",
    "airbases",
    "yink",
    "recon",
    "punisher",
    "viggensbane",
    "serverstatus",
}
loader.files.syria = {
    "variables",
    "collection_syria",
    "base",
    "airbases",
    "yink",
    "recon",
    "EventsSyria",
    "viggensbane",
    "serverstatus",
}

function LoadWithInterval(files)
    local current = 1
    local total = #files
    local function loadWithCycle(_, time)
        if current <= total then
            local file = files[current]
            log.write("loader", log.DEBUG, "loading: "..file..".lua")
            loadfile(loader.scriptsdir.."/"..file..".lua")()
            current = current + 1
            return time + loader.interval
        else
            log.write("loader", log.DEBUG, "all scripts successfully loaded")
        end
    end
    timer.scheduleFunction(loadWithCycle, nil, timer.getTime() + 1)
end

local function initMissionScripts()
    if env.mission.theatre == "Caucasus" then
        LoadWithInterval(loader.files.caucasus)
    elseif env.mission.theatre == "Syria" then
        LoadWithInterval(loader.files.syria)
    end
end

-- initialization
initMissionScripts()
