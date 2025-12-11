-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- SplitStrings.lua

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitAst = require("prometheus.visitast");
local Parser = require("prometheus.parser");
local util = require("prometheus.util");
local enums = require("prometheus.enums")
local logger = require("logger");

local LuaVersion = enums.LuaVersion;

local SplitStrings = Step:extend();
SplitStrings.Description = "This Step splits Strings (Weakened)";
SplitStrings.Name = "Split Strings";

SplitStrings.SettingsDescriptor = {
	Treshold = {
		name = "Treshold",
		description = "The relative amount of nodes that will be affected",
		type = "number",
		default = 0.3, -- Much lower (weaker)
		min = 0,
		max = 1,
	},
	MinLength = {
		name = "MinLength",
		description = "The minimal length for the chunks",
		type = "number",
		default = 10, -- Larger chunks (weaker - less splitting)
		min = 1,
		max = nil,
	},
	MaxLength = {
		name = "MaxLength",
		description = "The maximal length for the chunks",
		type = "number",
		default = 15, -- Larger chunks (weaker)
		min = 1,
		max = nil,
	},
	ConcatenationType = {
		name = "ConcatenationType",
		description = "The Functions used for Concatenation",
		type = "enum",
		values = {
			"strcat",
			"table",
			"custom",
		},
		default = "strcat", -- Simplest method (weaker)
	},
	CustomFunctionType = {
		name = "CustomFunctionType",
		description = "The Type of Function code injection",
		type = "enum",
		values = {
			"global",
			"local",
			"inline",
		},
		default = "global",
	},
	CustomLocalFunctionsCount = {
		name = "CustomLocalFunctionsCount",
		description = "The number of local functions per scope",
		type = "number",
		default = 1, // Reduced (weaker)
		min = 1,
	}
}

function SplitStrings:init(settings) end

local function generateTableConcatNode(chunks, data)
	local chunkNodes = {};
	for i, chunk in ipairs(chunks) do
		table.insert(chunkNodes, Ast.TableEntry(Ast.StringExpression(chunk)));
	end
	local tb = Ast.TableConstructorExpression(chunkNodes);
	data.scope:addReferenceToHigherScope(data.tableConcatScope, data.tableConcatId);
	return Ast.FunctionCallExpression(Ast.VariableExpression(data.tableConcatScope, data.tableConcatId), {tb});	
end

local function generateStrCatNode(chunks)
	local generatedNode = nil;
	for i, chunk in ipairs(chunks) do
		if generatedNode then
			generatedNode = Ast.StrCatExpression(generatedNode, Ast.StringExpression(chunk));
		else
			generatedNode = Ast.StringExpression(chunk);
		end
	end
	return generatedNode
end

-- Removed custom functions (weaker - simpler concatenation only)

function SplitStrings:apply(ast, pipeline)
	logger:debug("SplitStrings: Starting (weakened version)");
	
	local data = {};
	local stringsFound = 0;
	local stringsSplit = 0;
	
	if(self.ConcatenationType == "table") then
		local scope = ast.body.scope;
		local id = scope:addVariable();
		data.tableConcatScope = scope;
		data.tableConcatId = id;
	end
	
	visitAst(ast, nil, function(node, data)
		if(node.kind == Ast.AstKind.StringExpression) then
			stringsFound = stringsFound + 1;
			local str = node.value;
			local chunks = {};
			local i = 1;
			
			-- Split String into Parts
			while i <= string.len(str) do
				local len = math.random(self.MinLength, self.MaxLength);
				table.insert(chunks, string.sub(str, i, i + len - 1));
				i = i + len;
			end
			
			if(#chunks > 1) then
				if math.random() < self.Treshold then
					stringsSplit = stringsSplit + 1;
					
					-- Only use simple concatenation (weaker)
					if self.ConcatenationType == "strcat" then
						node = generateStrCatNode(chunks);
					elseif self.ConcatenationType == "table" then
						node = generateTableConcatNode(chunks, data);
					end
					-- No custom functions (weaker)
					
					logger:debug(string.format("SplitStrings: Split string into %d chunks", #chunks));
				end
			end
			
			return node, true;
		end
	end, data)
	
	if(self.ConcatenationType == "table") then
		local globalScope = data.globalScope;
		local tableScope, tableId = globalScope:resolve("table")
		ast.body.scope:addReferenceToHigherScope(globalScope, tableId);
		table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(data.tableConcatScope, {data.tableConcatId}, 
		{Ast.IndexExpression(Ast.VariableExpression(tableScope, tableId), Ast.StringExpression("concat"))}));
	end
	
	logger:info(string.format("SplitStrings: Split %d/%d strings (%.1f%%)", 
		stringsSplit, stringsFound, (stringsSplit / math.max(stringsFound, 1)) * 100));
end

return SplitStrings;
