--[[

@script logger

@description

@features
- 6 levels of logging
- custom log files
- optional format of date and time for custom log files

@examples

@created May 9, 2022

@version 0.0.9

]]

local osdate = os.date
local format = string.format

local levels = {
    {["callback"] = "alert",   ["enum"] = "ALERT"},
    {["callback"] = "error",   ["enum"] = "ERROR"},
    {["callback"] = "warning", ["enum"] = "WARNING"},
    {["callback"] = "info",    ["enum"] = "INFO"},
    {["callback"] = "debug",   ["enum"] = "DEBUG"},
    {["callback"] = "trace",   ["enum"] = "TRACE"},
}

logger = {
    ["openmode"] = "a",
    ["date"] = "%Y-%m-%d",
    ["time"] = "%H:%M:%S",
    ["level"] = 6,
}

logger.version = "0.0.9"

logger.enums = {
    ["alert"]   = 1,
    ["error"]   = 2,
    ["warning"] = 3,
    ["info"]    = 4,
    ["debug"]   = 5,
    ["trace"]   = 6
}

for i, level in ipairs(levels) do
    logger[level.callback] = function(self, source, message, ...)
        if self.level < i then
            return
        end
        local logMessage = format(message, ...)
        if self.file then
            local fullMessage = format("%s %s\t%s: %s\n", osdate(self.datetime), level.enum, source, logMessage)
            self.file:write(fullMessage)
            return
        end
        log.write(source, log[level.enum], logMessage)
    end
end

--[[ create a new instance of logger
- @param #logger self
- @param #enum level [the level of logging, eg; logger.enums.info]
- @param #string file [the external file to write to]
- @param #string mode [the mode in which the above file is opened, eg; "a" to append new lines]
- @param #string date [the format in which the date will be written in the external file, eg; "%Y-%m-%d" : 2022-05-09]
- @param #string time [the format in which the time will be written in the external file, eg; "%H:%M:%S" : 13:30:05]
- @return #logger self
]]
function logger:new(level, file, mode, date, time)
    local self = setmetatable({}, {__index = logger})
    self.level = level
    if self.file then self.file:close() end
    if file then
        if not mode then mode = logger.openmode end
        self.file = assert(io.open(file, mode))
    end
    date = date or logger.date
    time = time or logger.time
    self.datetime = date.." "..time
    return self
end

--[[ set the level of the logger
- @param #logger self
- @param #enum level [the level of logging, eg; logger.enums.info]
- @return #logger self
]]
function logger:setLevel(level)
    self.level = level
    return self
end

--[[ set the external log file for the logger
- @param #logger self
- @param #string file [the external file to write to]
- @param #string mode [the mode in which the above file is opened, eg; "a" to append new lines]
- @return #logger self
]]
function logger:setFile(file, mode)
    if self.file then self.file:close() end
    if not mode then mode = logger.openmode end
    self.file = assert(io.open(file, mode))
    return self
end

--[[ set the format for the date and time for an external log file
- @param #logger self
- @param #string date [the format in which the date will be written in the external file, eg; "%Y-%m-%d" : 2022-05-09]
- @param #string time [the format in which the time will be written in the external file, eg; "%H:%M:%S" : 13:30:05]
- @return #logger self
]]
function logger:setDateTime(date, time)
    date = date or logger.date
    time = time or logger.time
    self.datetime = date.." "..time
    return self
end

logger:info("logger.lua", "successfully loaded version %s", logger.version)