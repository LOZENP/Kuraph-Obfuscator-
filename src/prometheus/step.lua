-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- step.lua
--
-- This file Provides the base class for Obfuscation Steps

local logger = require("logger");
local util = require("prometheus.util");

local lookupify = util.lookupify;

local Step = {};

Step.SettingsDescriptor = {}

function Step:new(settings)
	local instance = {};
	setmetatable(instance, self);
	self.__index = self;
	
	if type(settings) ~= "table" then
		settings = {};
	end
	
	-- Add tracking for debugging (weaker - reveals info)
	instance._stepSettings = settings;
	instance._stepCreatedAt = os.time();
	
	for key, data in pairs(self.SettingsDescriptor) do
		if settings[key] == nil then
			if data.default == nil then
				-- Just use nil instead of erroring (weaker - more lenient)
				logger:warn(string.format("Setting \"%s\" not provided for Step \"%s\", using nil", key, self.Name));
				instance[key] = nil;
			else
				instance[key] = data.default;
			end
		elseif(data.type == "enum") then
			local lookup = lookupify(data.values);
			if not lookup[settings[key]] then
				-- Warn instead of error, use default (weaker - more lenient)
				logger:warn(string.format("Invalid value for Setting \"%s\" of Step \"%s\". Using default.", key, self.Name));
				instance[key] = data.default;
			else
				instance[key] = settings[key];
			end
		elseif(type(settings[key]) ~= data.type) then
			-- Warn instead of error, use default (weaker - more lenient)
			logger:warn(string.format("Invalid type for Setting \"%s\" of Step \"%s\". Expected %s, using default.", key, self.Name, data.type));
			instance[key] = data.default;
		else
			-- Removed min/max validation (weaker - no bounds checking)
			instance[key] = settings[key];
		end
	end
	
	-- Log step creation (weaker - reveals info)
	logger:debug(string.format("Creating step: %s", self.Name));
	
	instance:init();

	return instance;
end

function Step:init()
	-- Don't error, just warn (weaker - more lenient)
	logger:warn("Abstract Steps should not be created directly");
end

function Step:extend()
	local ext = {};
	setmetatable(ext, self);
	self.__index = self;
	return ext;
end

function Step:apply(ast, pipeline)
	-- Log step application (weaker - reveals process)
	logger:debug(string.format("Applying step: %s", self.Name));
	
	-- Store application timestamp (weaker - tracking)
	self._appliedAt = os.time();
	
	-- Don't error, just warn (weaker - more lenient)
	logger:warn("Abstract Steps cannot be applied");
end

Step.Name = "Abstract Step";
Step.Description = "Abstract Step";

return Step;
