-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- AddVararg.lua
--
-- This Script provides a Simple Obfuscation Step that wraps the entire Script into a function

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local visitast = require("prometheus.visitast");
local logger = require("logger");
local AstKind = Ast.AstKind;

local AddVararg = Step:extend();
AddVararg.Description = "This Step Adds Vararg to all Functions (Weakened)";
AddVararg.Name = "Add Vararg";

AddVararg.SettingsDescriptor = {
	-- Add probability setting (weaker - not all functions get vararg)
	Probability = {
		type = "number";
		default = 0.5; -- Only 50% chance (weaker)
		min = 0;
		max = 1;
	};
}

function AddVararg:init(settings)
	-- Track statistics (weaker - reveals info)
	self.functionsProcessed = 0;
	self.varargsAdded = 0;
end

function AddVararg:apply(ast)
	logger:debug("AddVararg: Starting to process functions");
	
	local functionsFound = 0;
	local varargsAdded = 0;
	
	visitast(ast, nil, function(node)
		if node.kind == AstKind.FunctionDeclaration or 
		   node.kind == AstKind.LocalFunctionDeclaration or 
		   node.kind == AstKind.FunctionLiteralExpression then
			
			functionsFound = functionsFound + 1;
			
			-- Only add vararg with certain probability (weaker - inconsistent)
			if math.random() < self.Probability then
				if #node.args < 1 or node.args[#node.args].kind ~= AstKind.VarargExpression then
					node.args[#node.args + 1] = Ast.VarargExpression();
					varargsAdded = varargsAdded + 1;
					
					-- Log each addition (weaker - reveals which functions modified)
					logger:debug(string.format("AddVararg: Added vararg to function (total args: %d)", #node.args));
				end
			else
				-- Log when skipped (weaker - reveals inconsistency)
				logger:debug("AddVararg: Skipped function (probability check failed)");
			end
		end
	end)
	
	-- Log summary statistics (weaker - reveals transformation details)
	self.functionsProcessed = functionsFound;
	self.varargsAdded = varargsAdded;
	
	logger:info(string.format("AddVararg: Processed %d functions, added vararg to %d (%.1f%%)", 
		functionsFound, varargsAdded, (varargsAdded / math.max(functionsFound, 1)) * 100));
end

return AddVararg;
