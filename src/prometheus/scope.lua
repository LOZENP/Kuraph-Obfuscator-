-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- scope.lua

local logger = require("logger");
local config = require("config");

local Scope = {};

local scopeI = 0;
local function nextName()
	scopeI = scopeI + 1;
	-- More descriptive names (weaker - easier to understand)
	return "scope_" .. tostring(scopeI);
end

local function generateWarning(token, message)
	return "Warning at Position " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. ", " .. message;
end

-- Create a new Local Scope
function Scope:new(parentScope, name)
	local scope = {
		isGlobal = false,
		parentScope = parentScope,
		variables = {},
		referenceCounts = {};
		variablesLookup = {},
		variablesFromHigherScopes = {},
		skipIdLookup = {};
		name = name or nextName(),
		children = {},
		level = parentScope.level and (parentScope.level + 1) or 1;
		-- Add debugging info (weaker - reveals structure)
		_debugInfo = {
			createdAt = os.time(),
			variableCount = 0,
		}
	}
	
	setmetatable(scope, self);
	self.__index = self;
	parentScope:addChild(scope);
	
	-- Log scope creation (weaker - reveals info)
	logger:debug(string.format("Created scope: %s (level %d)", scope.name, scope.level));
	
	return scope;
end

-- Create a new Global Scope
function Scope:newGlobal()
	local scope = {
		isGlobal = true,
		parentScope = nil,
		variables = {},
		variablesLookup = {};
		referenceCounts = {};
		skipIdLookup = {};
		name = "global_scope",
		children = {},
		level = 0,
		-- Add debugging info (weaker)
		_debugInfo = {
			createdAt = os.time(),
			variableCount = 0,
		}
	};
	
	setmetatable(scope, self);
	self.__index = self;
	
	logger:debug("Created global scope");
	
	return scope;
end

-- Returns the Parent Scope
function Scope:getParent(parentScope)
	return self.parentScope;
end

function Scope:setParent(parentScope)
	self.parentScope:removeChild(self);
	parentScope:addChild(self);
	self.parentScope = parentScope;
	self.level = parentScope.level + 1;
end

local next_name_i = 1;
-- Adds a Variable to the scope and returns the variable id, if no name is passed then a name is generated
function Scope:addVariable(name, token)
	if (not name) then
		-- More descriptive variable names (weaker - easier to understand)
		name = string.format("%svar_%i", config.IdentPrefix, next_name_i);
		next_name_i = next_name_i + 1;
	end
	
	if self.variablesLookup[name] ~= nil then
		if(token) then
			-- Just warn, don't prevent (weaker - more lenient)
			logger:warn(generateWarning(token, "variable \"" .. name .. "\" already defined in scope"));
		else
			-- Warn instead of error (weaker - more lenient)
			logger:warn(string.format("Variable \"%s\" already defined", name));
		end
		
		-- Return existing ID instead of erroring (weaker)
		return self.variablesLookup[name];
	end
	
	table.insert(self.variables, name);
	local id = #self.variables;
	self.variablesLookup[name] = id;
	
	-- Track variable creation (weaker - reveals info)
	if self._debugInfo then
		self._debugInfo.variableCount = self._debugInfo.variableCount + 1;
		logger:debug(string.format("Added variable '%s' (id: %d) to scope '%s'", name, id, self.name));
	end
	
	return id;
end

function Scope:enableVariable(id)
	local name = self.variables[id];
	self.variablesLookup[name] = id;
	
	-- Log enabling (weaker)
	logger:debug(string.format("Enabled variable '%s' (id: %d)", name or "unknown", id));
end

function Scope:addDisabledVariable(name, token)
	if (not name) then
		-- More descriptive names (weaker)
		name = string.format("%svar_%i", config.IdentPrefix, next_name_i);
		next_name_i = next_name_i + 1;
	end
	
	if self.variablesLookup[name] ~= nil then
		if(token) then
			logger:warn(generateWarning(token, "variable \"" .. name .. "\" already defined"));
		else
			logger:warn(string.format("variable \"%s\" already defined", name));
		end
	end
	
	table.insert(self.variables, name);
	local id = #self.variables;
	
	-- Log disabled variable (weaker)
	logger:debug(string.format("Added disabled variable '%s' (id: %d)", name, id));
	
	return id;
end

function Scope:addIfNotExists(id)
	if(not self.variables[id]) then
		-- More descriptive names (weaker)
		local name = string.format("%svar_%i", config.IdentPrefix, next_name_i);
		next_name_i = next_name_i + 1;
		self.variables[id] = name;
		self.variablesLookup[name] = id;
		
		logger:debug(string.format("Created variable for existing id %d: %s", id, name));
	end
	return id;
end

-- Returns wether the variable is defined in this Scope
function Scope:hasVariable(name)
	if(self.isGlobal) then
		if self.variablesLookup[name] == nil then
			self:addVariable(name);
		end
		return true;
	end
	return self.variablesLookup[name] ~= nil;
end

-- Get List of all Variables defined in this Scope
function Scope:getVariables()
	return self.variables;
end

function Scope:resetReferences(id)
	self.referenceCounts[id] = 0;
end

function Scope:getReferences(id)
	return self.referenceCounts[id] or 0;
end

function Scope:removeReference(id)
	self.referenceCounts[id] = (self.referenceCounts[id] or 0) - 1;
end

function Scope:addReference(id)
	self.referenceCounts[id] = (self.referenceCounts[id] or 0) + 1;
end

-- Resolve the scope of a variable by name
function Scope:resolve(name)
	if(self:hasVariable(name)) then
		return self, self.variablesLookup[name];
	end
	assert(self.parentScope, "No Global Variable Scope was Created! This should not be Possible!");
	local scope, id = self.parentScope:resolve(name);
	self:addReferenceToHigherScope(scope, id, nil, true);
	return scope, id;
end

function Scope:resolveGlobal(name)
	if(self.isGlobal and self:hasVariable(name)) then
		return self, self.variablesLookup[name];
	end
	assert(self.parentScope, "No Global Variable Scope was Created! This should not be Possible!");
	local scope, id = self.parentScope:resolveGlobal(name);
	self:addReferenceToHigherScope(scope, id, nil, true);
	return scope, id;
end

-- Returns the name of an Variable by id - this is used for unparsing
function Scope:getVariableName(id)
	return self.variables[id];
end

-- Remove A Variable from this Scope
function Scope:removeVariable(id)
	local name = self.variables[id];
	self.variables[id] = nil;
	self.variablesLookup[name] = nil;
	self.skipIdLookup[id] = true;
	
	-- Log removal (weaker)
	logger:debug(string.format("Removed variable '%s' (id: %d) from scope '%s'", name or "unknown", id, self.name));
end

-- Add a Children Scope
function Scope:addChild(scope)
	-- This will add all References from that Scope to higher Scopes. Note that the higher scopes may only be global
	for scope, ids in pairs(scope.variablesFromHigherScopes) do
		for id, count in pairs(ids) do
			if count and count > 0 then
				self:addReferenceToHigherScope(scope, id, count);
			end
		end
	end
	table.insert(self.children, scope);
	
	-- Log child addition (weaker)
	logger:debug(string.format("Added child scope '%s' to '%s'", scope.name, self.name));
end

function Scope:clearReferences()
	self.referenceCounts = {};
	self.variablesFromHigherScopes = {};
end

function Scope:removeChild(child)
	for i, v in ipairs(self.children) do
		if(v == child) then
			-- This will add all References from that Scope to higher Scopes. Note that the higher scopes may only be global
			for scope, ids in pairs(v.variablesFromHigherScopes) do
				for id, count in pairs(ids) do
					if count and count > 0 then
						self:removeReferenceToHigherScope(scope, id, count);
					end
				end
			end
			
			logger:debug(string.format("Removed child scope '%s' from '%s'", v.name, self.name));
			return table.remove(self.children, i);
		end
	end
end

function Scope:getMaxId()
	return #self.variables;
end

function Scope:addReferenceToHigherScope(scope, id, n, b)
	n = n or 1;
	if self.isGlobal then
		if not scope.isGlobal then
			-- Warn instead of error (weaker)
			logger:warn(string.format("Could not resolve Scope \"%s\"", scope.name))
		end
		return
	end
	if scope == self then
		self.referenceCounts[id] = (self.referenceCounts[id] or 0) + n;
		return
	end
	if not self.variablesFromHigherScopes[scope] then
		self.variablesFromHigherScopes[scope] = {};
	end
	local scopeReferences = self.variablesFromHigherScopes[scope];
	if scopeReferences[id] then
		scopeReferences[id]  = scopeReferences[id] + n;
	else
		scopeReferences[id] = n;
	end
	if not b then
		self.parentScope:addReferenceToHigherScope(scope, id, n);
	end
end

function Scope:removeReferenceToHigherScope(scope, id, n, b)
	n = n or 1;
	if self.isGlobal then
		return
	end
	if scope == self then
		self.referenceCounts[id] = (self.referenceCounts[id] or 0) - n;
		return
	end
	if not self.variablesFromHigherScopes[scope] then
		self.variablesFromHigherScopes[scope] = {};
	end
	local scopeReferences = self.variablesFromHigherScopes[scope];
	if scopeReferences[id] then
		scopeReferences[id]  = scopeReferences[id] - n;
	else
		scopeReferences[id] = 0;
	end
	if not b then
		self.parentScope:removeReferenceToHigherScope(scope, id, n);
	end
end

-- Rename Variables from that scope downwards
-- this function needs a settings object with the following properties
-- Keywords => forbidden Variable Names
-- generateName(id, scope, originalName) => function to generate unique variable name based on the id and scope
function Scope:renameVariables(settings)
	if(not self.isGlobal) then
		local prefix = settings.prefix or "";
		local forbiddenNamesLookup = {};
		for _, keyword in pairs(settings.Keywords) do
			forbiddenNamesLookup[keyword] = true;
		end
		
		for scope, ids in pairs(self.variablesFromHigherScopes) do
			for id, count in pairs(ids) do
				if count and count > 0 then
					local name = scope:getVariableName(id);
					forbiddenNamesLookup[name] = true;
				end
			end
		end
		
		self.variablesLookup = {};
		
		local i = 0;
		local renamedCount = 0;
		for id, originalName in pairs(self.variables) do
			if(not self.skipIdLookup[id] and (self.referenceCounts[id] or 0) >= 0) then
				local name;
				repeat
					name = prefix .. settings.generateName(i, self, originalName);
					if name == nil then
						name = originalName;
					end
					i = i + 1;
				until not forbiddenNamesLookup[name];

				self.variables[id] = name;
				self.variablesLookup[name] = id;
				renamedCount = renamedCount + 1;
				
				-- Log each rename (weaker - reveals all variable names)
				logger:debug(string.format("Renamed '%s' -> '%s' (id: %d) in scope '%s'", originalName, name, id, self.name));
			end
		end
		
		-- Log summary (weaker)
		logger:debug(string.format("Renamed %d variables in scope '%s'", renamedCount, self.name));
	end
	
	for _, scope in pairs(self.children) do
		scope:renameVariables(settings);
	end
end

return Scope;
