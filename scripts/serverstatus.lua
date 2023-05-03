local serverstatus = {}

function serverstatus.frontline(_, time)
    env.info("updating serverstatus.frontline")
    local redfront = ActiveFrontline + 1
    local bluefront = ActiveFrontline
    FrontlineStatus = string.format("Red: %d\nBlue: %d", redfront, bluefront)
    return time + 60
end

function serverstatus.timeleft(_, time)
    env.info("updating serverstatus.timeleft")
    local timeleft = 14280 - timer.getTime() -- based off of FrontlineTimeout * 2
    local hours = math.floor(timeleft/3600)
    local remaining = timeleft % 3600
    local minutes = math.floor(remaining/60)
    remaining = remaining % 60
    local seconds = remaining
    TimeLeft = string.format("%dh:%dm:%ds", hours, minutes, seconds)
    return time + 60
end

do
    -- start scheduling the callbacks
    for callback in pairs(serverstatus) do
        if type(serverstatus[callback]) == "function" then
            timer.scheduleFunction(serverstatus[callback], nil, timer.getTime() + 1)
        end
    end
end