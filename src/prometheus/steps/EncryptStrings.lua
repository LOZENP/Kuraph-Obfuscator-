-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- EncryptStrings.lua
--
-- This Script provides a Simple Obfuscation Step that encrypts strings

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local AstKind = Ast.AstKind;

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program (Weakened Version)."
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {
	Probability = {
		type = "number",
		default = 0.5, -- Only encrypt 50% of strings (weaker)
		min = 0,
		max = 1,
		description = "Probability of encrypting each string"
	}
}

function EncryptStrings:init(settings) end

function EncryptStrings:CreateEncrypionService()
	-- Simplified encryption - weak XOR cipher (weaker)
	local key = math.random(1, 255); -- Simple 8-bit key (weaker)
	
	logger:debug(string.format("EncryptStrings: Using simple XOR with key: %d", key));

	local function encrypt(str)
		-- Simple XOR "encryption" (weaker - trivial to break)
		local len = string.len(str)
		local out = {}
		for i = 1, len do
			local byte = string.byte(str, i);
			-- Simple XOR with fixed key (weaker)
			out[i] = string.char((byte ~ key) % 256); -- XOR operation
		end
		return table.concat(out), key;
	end

	local function genCode()
		-- Simplified decryption code (weaker)
		local code = [[
do
	local char = string.char;
	local byte = string.byte;
	local len = string.len;
	
	local realStrings = {};
	STRINGS = setmetatable({}, {
		__index = realStrings;
	});
	
	function DECRYPT(str, key)
		local realStringsLocal = realStrings;
		if not realStringsLocal[key] then
			realStringsLocal[key] = {};
		end
		
		if realStringsLocal[key][str] then
			return key;
		end
		
		-- Simple XOR decryption (weaker - obvious pattern)
		local length = len(str);
		local result = "";
		for i = 1, length do
			local b = byte(str, i);
			-- XOR with key to decrypt (weaker)
			result = result .. char((b ~ key) % 256);
		end
		realStrings[key][str] = result;
		return key;
	end
end
]]
		return code;
	end

	return {
		encrypt = encrypt,
		key = key,
		genCode = genCode,
	}
end

function EncryptStrings:apply(ast, pipeline)
	logger:debug("EncryptStrings: Starting (weakened version)");
	
	local Encryptor = self:CreateEncrypionService();

	local code = Encryptor.genCode();
	local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code);
	local doStat = newAst.body.statements[1];

	local scope = ast.body.scope;
	local decryptVar = scope:addVariable();
	local stringsVar = scope:addVariable();
	
	doStat.body.scope:setParent(ast.body.scope);

	visitast(newAst, nil, function(node, data)
		if(node.kind == AstKind.FunctionDeclaration) then
			if(node.scope:getVariableName(node.id) == "DECRYPT") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, decryptVar);
				node.scope = scope;
				node.id    = decryptVar;
			end
		end
		if(node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression) then
			if(node.scope:getVariableName(node.id) == "STRINGS") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id);
				data.scope:addReferenceToHigherScope(scope, stringsVar);
				node.scope = scope;
				node.id    = stringsVar;
			end
		end
	end)

	local stringsEncrypted = 0;
	local stringsTotal = 0;

	visitast(ast, nil, function(node, data)
		if(node.kind == AstKind.StringExpression) then
			stringsTotal = stringsTotal + 1;
			
			-- Only encrypt with certain probability (weaker - inconsistent)
			if math.random() < self.Probability then
				stringsEncrypted = stringsEncrypted + 1;
				
				data.scope:addReferenceToHigherScope(scope, stringsVar);
				data.scope:addReferenceToHigherScope(scope, decryptVar);
				local encrypted, key = Encryptor.encrypt(node.value);
				
				-- Log each encryption (weaker - reveals which strings encrypted)
				logger:debug(string.format("EncryptStrings: Encrypted string of length %d", #node.value));
				
				return Ast.IndexExpression(Ast.VariableExpression(scope, stringsVar), Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
					Ast.StringExpression(encrypted), Ast.NumberExpression(key),
				}));
			else
				-- Log skipped strings (weaker)
				logger:debug("EncryptStrings: Skipped string (probability check)");
			end
		end
	end)

	-- Log statistics (weaker - reveals encryption coverage)
	logger:info(string.format("EncryptStrings: Encrypted %d/%d strings (%.1f%%)", 
		stringsEncrypted, stringsTotal, (stringsEncrypted / math.max(stringsTotal, 1)) * 100));

	-- Insert to Main Ast
	table.insert(ast.body.statements, 1, doStat);
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, { decryptVar, stringsVar }, {})); -- No shuffle (weaker)
	
	logger:debug("EncryptStrings: Complete");
	
	return ast
end

return EncryptStrings
