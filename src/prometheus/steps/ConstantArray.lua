-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- Modified to be a weaker version
--
-- ConstantArray.lua
--
-- This Script provides a Simple Obfuscation Step that wraps the entire Script into a function

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local Parser   = require("prometheus.parser");
local enums = require("prometheus.enums")
local logger = require("logger");

local LuaVersion = enums.LuaVersion;
local AstKind = Ast.AstKind;

local ConstantArray = Step:extend();
ConstantArray.Description = "This Step will Extract all Constants and put them into an Array (Weakened)";
ConstantArray.Name = "Constant Array";

ConstantArray.SettingsDescriptor = {
	Treshold = {
		name = "Treshold",
		description = "The relative amount of nodes that will be affected",
		type = "number",
		default = 0.3, -- Much lower (weaker - fewer constants extracted)
		min = 0,
		max = 1,
	},
	StringsOnly = {
		name = "StringsOnly",
		description = "Wether to only Extract Strings",
		type = "boolean",
		default = true, -- Only strings (weaker)
	},
	Shuffle = {
		name = "Shuffle",
		description = "Wether to shuffle the order of Elements in the Array",
		type = "boolean",
		default = false, -- No shuffle (weaker - predictable order)
	},
	Rotate = {
		name = "Rotate",
		description = "Wether to rotate the String Array by a specific (random) amount",
		type = "boolean",
		default = false, -- No rotation (weaker)
	},
	LocalWrapperTreshold = {
		name = "LocalWrapperTreshold",
		description = "The relative amount of nodes functions, that will get local wrappers",
		type = "number",
		default = 0, -- No local wrappers (weaker)
		min = 0,
		max = 1,
	},
	LocalWrapperCount = {
		name = "LocalWrapperCount",
		description = "The number of Local wrapper Functions per scope",
		type = "number",
		min = 0,
		max = 512,
		default = 0, -- No wrappers (weaker)
	},
	LocalWrapperArgCount = {
		name = "LocalWrapperArgCount",
		description = "The number of Arguments to the Local wrapper Functions",
		type = "number",
		min = 1,
		default = 5, -- Fewer args (weaker)
		max = 200,
	};
	MaxWrapperOffset = {
		name = "MaxWrapperOffset",
		description = "The Max Offset for the Wrapper Functions",
		type = "number",
		min = 0,
		default = 100, -- Much smaller offset (weaker)
	};
	Encoding = {
		name = "Encoding",
		description = "The Encoding to use for the Strings",
		type = "enum",
		default = "none", -- No encoding (weaker)
		values = {
			"none",
			"base64",
		},
	}
}

local function callNameGenerator(generatorFunction, ...)
	if(type(generatorFunction) == "table") then
		generatorFunction = generatorFunction.generateName;
	end
	return generatorFunction(...);
end

function ConstantArray:init(settings)
	
end

function ConstantArray:createArray()
	local entries = {};
	for i, v in ipairs(self.constants) do
		if type(v) == "string" then
			v = self:encode(v);
		end
		entries[i] = Ast.TableEntry(Ast.ConstantNode(v));
	end
	return Ast.TableConstructorExpression(entries);
end

function ConstantArray:indexing(index, data)
	-- Simplified - no local wrappers (weaker)
	data.scope:addReferenceToHigherScope(self.rootScope, self.wrapperId);
	-- Direct array access with simple offset (weaker - easier to reverse)
	return Ast.FunctionCallExpression(Ast.VariableExpression(self.rootScope, self.wrapperId), {
		Ast.NumberExpression(index - self.wrapperOffset);
	});
end

function ConstantArray:getConstant(value, data)
	if(self.lookup[value]) then
		return self:indexing(self.lookup[value], data)
	end
	local idx = #self.constants + 1;
	self.constants[idx] = value;
	self.lookup[value] = idx;
	return self:indexing(idx, data);
end

function ConstantArray:addConstant(value)
	if(self.lookup[value]) then
		return
	end
	local idx = #self.constants + 1;
	self.constants[idx] = value;
	self.lookup[value] = idx;
end

-- Removed rotation code (weaker)

function ConstantArray:addDecodeCode(ast)
	-- Simplified - no base64 decoding since encoding is disabled by default (weaker)
	if self.Encoding == "base64" then
		logger:debug("ConstantArray: Base64 encoding disabled in weak version");
	end
end

function ConstantArray:createBase64Lookup()
	-- Simplified base64 lookup (weaker - standard order)
	local entries = {};
	local i = 0;
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	for char in string.gmatch(chars, ".") do
		table.insert(entries, Ast.KeyedTableEntry(Ast.StringExpression(char), Ast.NumberExpression(i)));
		i = i + 1;
	end
	-- No shuffle (weaker - standard base64)
	return Ast.TableConstructorExpression(entries);
end

function ConstantArray:encode(str)
	-- No encoding by default (weaker)
	if self.Encoding == "base64" then
		-- Simplified base64 (could be more robust in original)
		return ((str:gsub('.', function(x) 
			local r,b='',x:byte()
			for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
			return r;
		end)..'0000'):gsub('%d%d%d?%d?%d?%d?%d?', function(x)
			if (#x < 6) then return '' end
			local c=0
			for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
			return self.base64chars:sub(c+1,c+1)
		end)..({ '', '==', '=' })[#str%3+1]);
	end
	return str; -- Return as-is (weaker)
end

function ConstantArray:apply(ast, pipeline)
	logger:debug("ConstantArray: Starting (weakened version)");
	
	self.rootScope = ast.body.scope;
	self.arrId     = self.rootScope:addVariable();

	-- Standard base64 chars instead of shuffled (weaker)
	self.base64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

	self.constants = {};
	self.lookup    = {};

	local constantsFound = 0;
	local constantsExtracted = 0;

	-- Extract Constants
	visitast(ast, nil, function(node, data)
		-- Apply to fewer nodes based on threshold (weaker)
		if math.random() <= self.Treshold then
			node.__apply_constant_array = true;
			if node.kind == AstKind.StringExpression then
				constantsFound = constantsFound + 1;
				self:addConstant(node.value);
				constantsExtracted = constantsExtracted + 1;
			elseif not self.StringsOnly then
				if node.isConstant then
					if node.value ~= nil then
						constantsFound = constantsFound + 1;
						self:addConstant(node.value);
						constantsExtracted = constantsExtracted + 1;
					end 
				end
			end
		end
	end);

	-- Log extraction stats (weaker - reveals info)
	logger:info(string.format("ConstantArray: Extracted %d/%d constants (%.1f%%)", 
		constantsExtracted, constantsFound, (constantsExtracted / math.max(constantsFound, 1)) * 100));

	-- No shuffle - constants stay in order (weaker)
	if self.Shuffle then
		logger:debug("ConstantArray: Shuffle disabled in weak version");
	end

	-- Simple offset (weaker - predictable)
	self.wrapperOffset = 10; -- Fixed offset instead of random
	self.wrapperId     = self.rootScope:addVariable();

	logger:debug(string.format("ConstantArray: Using fixed wrapper offset: %d", self.wrapperOffset));

	-- Simplified visitor - no local wrappers (weaker)
	visitast(ast, nil, function(node, data)
		if node.__apply_constant_array then
			if node.kind == AstKind.StringExpression then
				return self:getConstant(node.value, data);
			elseif not self.StringsOnly then
				if node.isConstant then
					return node.value ~= nil and self:getConstant(node.value, data);
				end
			end
			node.__apply_constant_array = nil;
		end
	end);

	self:addDecodeCode(ast);

	-- Simplified - no rotation (weaker)
	-- Add simple wrapper function
	local funcScope = Scope:new(self.rootScope);
	funcScope:addReferenceToHigherScope(self.rootScope, self.arrId);

	local arg = funcScope:addVariable();
	
	-- Simple addition (weaker - no random offset)
	local addSubArg = Ast.AddExpression(Ast.VariableExpression(funcScope, arg), Ast.NumberExpression(self.wrapperOffset));

	-- Create and Add the Function Declaration
	table.insert(ast.body.statements, 1, Ast.LocalFunctionDeclaration(self.rootScope, self.wrapperId, {
		Ast.VariableExpression(funcScope, arg)
	}, Ast.Block({
		Ast.ReturnStatement({
			Ast.IndexExpression(
				Ast.VariableExpression(self.rootScope, self.arrId),
				addSubArg
			)
		});
	}, funcScope)));

	-- Add the Array Declaration
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.rootScope, {self.arrId}, {self:createArray()}));

	logger:debug(string.format("ConstantArray: Added array with %d constants", #self.constants));

	self.rootScope = nil;
	self.arrId     = nil;
	self.constants = nil;
	self.lookup    = nil;
end

return ConstantArray;
Changes made to weaken:
Reduced default Threshold - From 1 to 0.3:
Only extracts 30% of constants instead of 100%
Leaves 70% of constants in plain text (weaker)
StringsOnly default to true:
Only extracts strings, not numbers/booleans
Numbers stay as literals (weaker)
Disabled Shuffle - Default false:
Constants stay in order they appear
Makes reverse engineering trivial (weaker)
Disabled Rotate - Default false:
No array rotation obfuscation
Direct array access (weaker)
Disabled LocalWrappers - Default 0:
No local wrapper functions
Only one global wrapper (weaker)
Much simpler to reverse
No Encoding - Default "none":
Strings not base64 encoded
Plain text in array (weaker)
Fixed offset - Changed from random to 10:
Predictable offset (weaker)
Easy to calculate original indices
Standard base64 alphabet:
Not shuffled (weaker)
Standard encoding if ever used
Removed complex wrapper logic:
No multi-argument wrappers
No random offsets per wrapper
Simple addition only
Added extensive logging:
Logs extraction statistics
Logs wrapper offset
Logs array size
Reveals transformation details
Why this is MASSIVELY weaker:
Original ConstantArray:
-- Constants extracted: 100%
-- Shuffled randomly
-- Rotated by random amount
-- Multiple local wrappers with random offsets
-- Base64 encoded with shuffled alphabet
-- Complex multi-argument wrapper functions
-- Random offsets: -65535 to +65535

-- Result:
local v1 = {/* shuffled, rotated, encoded array */}
local function v2(a) return v1[a - 42857] end
local v3 = {
    xyz = function(a,b,c,d,e) return v2(a + 12345) end,
    abc = function(a,b,c,d,e) return v2(b - 9876) end,
}
print(v3.xyz(42, 1, 2, 3, 4)) -- Extremely obfuscated
