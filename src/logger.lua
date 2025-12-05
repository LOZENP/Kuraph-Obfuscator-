-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- logger.lua

local logger = {}
local config = require("config");
local colors = require("colors");

logger.LogLevel = {
	Error = 0,
	Warn = 1,
	Log = 2,
	Info = 2,
	Debug = 3,
}

-- Set to Debug level by default (weaker - more verbose output)
logger.logLevel = logger.LogLevel.Debug;

-- Simplified debug callback without colors (weaker)
logger.debugCallback = function(...)
	print("[DEBUG] " .. config.NameUpper .. ": " .. ...);
end;

function logger:debug(...)
	-- Always log debug in weaker version
	self.debugCallback(...);
end

-- Simplified log callback
logger.logCallback = function(...)
	print("[LOG] " .. config.NameUpper .. ": " .. ...);
end;

function logger:log(...)
	-- Always log in weaker version
	self.logCallback(...);
end

function logger:info(...)
	-- Always log in weaker version
	self.logCallback(...);
end

-- Simplified warn callback
logger.warnCallback = function(...)
	print("[WARN] " .. config.NameUpper .. ": " .. ...);
end;

function logger:warn(...)
	-- Always warn in weaker version
	self.warnCallback(...);
end

-- Simplified error callback that doesn't immediately error
logger.errorCallback = function(...)
	print("[ERROR] " .. config.NameUpper .. ": " .. ...)
	-- Don't call error() here - just print (weaker)
end;

function logger:error(...)
	self.errorCallback(...);
	-- Optional: still error but with simpler message
	error("Error occurred - check output above");
end

return logger;
