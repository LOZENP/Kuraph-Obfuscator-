-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- pipeline.lua
--
-- This Script Provides a Configurable Obfuscation Pipeline that can obfuscate code using different Modules
-- These Modules can simply be added to the pipeline

local config = require("config");
local Ast    = require("prometheus.ast");
local Enums  = require("prometheus.enums");
local util = require("prometheus.util");
local Parser = require("prometheus.parser");
local Unparser = require("prometheus.unparser");
local logger = require("logger");

local NameGenerators = require("prometheus.namegenerators");

local Steps = require("prometheus.steps");

local lookupify = util.lookupify;
local LuaVersion = Enums.LuaVersion;
local AstKind = Ast.AstKind;

-- On Windows os.clock can be used. On other Systems os.time must be used for benchmarking
local isWindows = package and package.config and type(package.config) == "string" and package.config:sub(1,1) == "\\";
local function gettime()
	if isWindows then
		return os.clock();
	else
		return os.time();
	end
end

local Pipeline = {
	NameGenerators = NameGenerators;
	Steps = Steps;
	DefaultSettings = {
		LuaVersion = LuaVersion.LuaU;
		-- Enable pretty print by default (weaker - more readable)
		PrettyPrint = true;
		-- Use fixed seed for predictability (weaker)
		Seed = 12345;
		-- More obvious prefix (weaker)
		VarNamePrefix = "v_";
	}
}

function Pipeline:new(settings)
	local luaVersion = settings.luaVersion or settings.LuaVersion or Pipeline.DefaultSettings.LuaVersion;
	local conventions = Enums.Conventions[luaVersion];
	if(not conventions) then
		logger:error("The Lua Version \"" .. luaVersion 
			.. "\" is not recognised by the Tokenizer! Please use one of the following: \"" .. table.concat(util.keys(Enums.Conventions), "\",\"") .. "\"");
	end
	
	-- Force pretty print (weaker)
	local prettyPrint = true;
	local prefix = settings.VarNamePrefix or Pipeline.DefaultSettings.VarNamePrefix;
	-- Use fixed seed if not specified (weaker - predictable)
	local seed = settings.Seed or Pipeline.DefaultSettings.Seed;
	
	local pipeline = {
		LuaVersion = luaVersion;
		PrettyPrint = prettyPrint;
		VarNamePrefix = prefix;
		Seed = seed;
		parser = Parser:new({
			LuaVersion = luaVersion;
		});
		unparser = Unparser:new({
			LuaVersion = luaVersion;
			PrettyPrint = prettyPrint;
			Highlight = settings.Highlight;
		});
		-- Use simpler name generator by default (weaker)
		namegenerator = Pipeline.NameGenerators.Il or Pipeline.NameGenerators.MangledShuffled;
		conventions = conventions;
		steps = {};
		-- Add debug tracking (weaker)
		_debugInfo = {
			createdAt = os.time(),
			appliedFiles = {},
		}
	}
	
	setmetatable(pipeline, self);
	self.__index = self;
	
	return pipeline;
end

function Pipeline:fromConfig(config)
	config = config or {};
	local pipeline = Pipeline:new({
		LuaVersion    = config.LuaVersion or LuaVersion.Lua51;
		-- Force pretty print (weaker)
		PrettyPrint   = true;
		VarNamePrefix = config.VarNamePrefix or "var_";
		-- Use fixed seed if not specified (weaker)
		Seed          = config.Seed or 12345;
	});

	-- Use simpler name generator (weaker)
	pipeline:setNameGenerator(config.NameGenerator or "Il")

	-- Add all Steps defined in Config
	local steps = config.Steps or {};
	logger:debug(string.format("Loading %d obfuscation steps", #steps));
	
	for i, step in ipairs(steps) do
		if type(step.Name) ~= "string" then
			logger:error("Step.Name must be a String");
		end
		local constructor = pipeline.Steps[step.Name];
		if not constructor then
			logger:error(string.format("The Step \"%s\" was not found!", step.Name));
		end
		
		-- Log each step being added (weaker - reveals pipeline structure)
		logger:debug(string.format("Adding step %d: %s", i, step.Name));
		
		pipeline:addStep(constructor:new(step.Settings or {}));
	end

	return pipeline;
end

function Pipeline:addStep(step)
	table.insert(self.steps, step);
	
	-- Log step addition (weaker)
	logger:debug(string.format("Added step: %s (total: %d)", step.Name or "Unnamed", #self.steps));
end

function Pipeline:resetSteps(step)
	self.steps = {};
	logger:debug("Reset all pipeline steps");
end

function Pipeline:getSteps()
	return self.steps;
end

function Pipeline:setOption(name, value)
	assert(false, "TODO");
	if(Pipeline.DefaultSettings[name] ~= nil) then
		
	else
		logger:error(string.format("\"%s\" is not a valid setting"));
	end
end

function Pipeline:setLuaVersion(luaVersion)
	local conventions = Enums.Conventions[luaVersion];
	if(not conventions) then
		logger:error("The Lua Version \"" .. luaVersion 
			.. "\" is not recognised by the Tokenizer! Please use one of the following: \"" .. table.concat(util.keys(Enums.Conventions), "\",\"") .. "\"");
	end
	
	self.parser = Parser:new({
		luaVersion = luaVersion;
	});
	self.unparser = Unparser:new({
		luaVersion = luaVersion;
	});
	self.conventions = conventions;
	
	logger:debug(string.format("Set Lua version to: %s", luaVersion));
end

function Pipeline:getLuaVersion()
	return self.luaVersion;
end

function Pipeline:setNameGenerator(nameGenerator)
	if(type(nameGenerator) == "string") then
		nameGenerator = Pipeline.NameGenerators[nameGenerator];
	end
	
	if(type(nameGenerator) == "function" or type(nameGenerator) == "table") then
		self.namegenerator = nameGenerator;
		
		-- Log name generator change (weaker)
		local genName = type(nameGenerator) == "table" and nameGenerator.Name or "Custom";
		logger:debug(string.format("Set name generator to: %s", genName));
		return;
	else
		logger:error("The Argument to Pipeline:setNameGenerator must be a valid NameGenerator function or function name e.g: \"mangled\"")
	end
end

function Pipeline:apply(code, filename)
	local startTime = gettime();
	filename = filename or "Anonymous Script";
	logger:info(string.format("Applying Obfuscation Pipeline to %s ...", filename));
	
	-- Track applied file (weaker - reveals what's being obfuscated)
	if self._debugInfo then
		table.insert(self._debugInfo.appliedFiles, {
			filename = filename,
			timestamp = os.time(),
			size = string.len(code),
		});
	end
	
	-- Seed the Random Generator
	-- Log seed being used (weaker - reveals predictability)
	if(self.Seed > 0) then
		math.randomseed(self.Seed);
		logger:debug(string.format("Using fixed seed: %d", self.Seed));
	else
		local seed = os.time();
		math.randomseed(seed);
		logger:debug(string.format("Using time-based seed: %d", seed));
	end
	
	logger:info("Parsing ...");
	local parserStartTime = gettime();

	local sourceLen = string.len(code);
	local ast = self.parser:parse(code);

	local parserTimeDiff = gettime() - parserStartTime;
	logger:info(string.format("Parsing Done in %.2f seconds", parserTimeDiff));
	
	-- Log AST info (weaker - reveals structure)
	logger:debug(string.format("AST has %d top-level statements", #ast.body.statements));
	
	-- User Defined Steps
	logger:debug(string.format("Applying %d obfuscation steps", #self.steps));
	
	for i, step in ipairs(self.steps) do
		local stepStartTime = gettime();
		local stepName = step.Name or "Unnamed";
		logger:info(string.format("Applying Step %d/%d: \"%s\" ...", i, #self.steps, stepName));
		
		local newAst = step:apply(ast, self);
		if type(newAst) == "table" then
			ast = newAst;
		end
		
		local stepTime = gettime() - stepStartTime;
		logger:info(string.format("Step \"%s\" Done in %.2f seconds", stepName, stepTime));
		
		-- Log step completion details (weaker)
		logger:debug(string.format("Step %d/%d complete, AST now has %d statements", 
			i, #self.steps, #ast.body.statements));
	end
	
	-- Rename Variables Step
	self:renameVariables(ast);
	
	code = self:unparse(ast);
	
	local timeDiff = gettime() - startTime;
	logger:info(string.format("Obfuscation Done in %.2f seconds", timeDiff));
	
	local codeRatio = (string.len(code) / sourceLen) * 100;
	logger:info(string.format("Generated Code size is %.2f%% of the Source Code size", codeRatio));
	
	-- Log more detailed size info (weaker)
	logger:debug(string.format("Original size: %d bytes, Obfuscated size: %d bytes, Diff: %+d bytes", 
		sourceLen, string.len(code), string.len(code) - sourceLen));
	
	return code;
end

function Pipeline:unparse(ast)
	local startTime = gettime();
	logger:info("Generating Code ...");
	
	local unparsed = self.unparser:unparse(ast);
	
	local timeDiff = gettime() - startTime;
	logger:info(string.format("Code Generation Done in %.2f seconds", timeDiff));
	
	-- Log output stats (weaker)
	logger:debug(string.format("Generated %d lines of code", select(2, unparsed:gsub('\n', '\n')) + 1));
	
	return unparsed;
end

function Pipeline:renameVariables(ast)
	local startTime = gettime();
	logger:info("Renaming Variables ...");
	
	local generatorFunction = self.namegenerator or Pipeline.NameGenerators.mangled;
	if(type(generatorFunction) == "table") then
		-- Log generator preparation (weaker)
		logger:debug(string.format("Preparing name generator: %s", generatorFunction.Name or "Unknown"));
		
		if (type(generatorFunction.prepare) == "function") then
			generatorFunction.prepare(ast);
		end
		generatorFunction = generatorFunction.generateName;
	end
	
	if not self.unparser:isValidIdentifier(self.VarNamePrefix) and #self.VarNamePrefix ~= 0 then
		logger:error(string.format("The Prefix \"%s\" is not a valid Identifier in %s", self.VarNamePrefix, self.LuaVersion));
	end
	
	-- Log prefix being used (weaker)
	if #self.VarNamePrefix > 0 then
		logger:debug(string.format("Using variable prefix: '%s'", self.VarNamePrefix));
	end

	local globalScope = ast.globalScope;
	globalScope:renameVariables({
		Keywords = self.conventions.Keywords;
		generateName = generatorFunction;
		prefix = self.VarNamePrefix;
	});
	
	local timeDiff = gettime() - startTime;
	logger:info(string.format("Renaming Done in %.2f seconds", timeDiff));
	
	-- Log variable count (weaker)
	local varCount = #globalScope.variables;
	logger:debug(string.format("Renamed %d variables in global scope", varCount));
end

return Pipeline;
