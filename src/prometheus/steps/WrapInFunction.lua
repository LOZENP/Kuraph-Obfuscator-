-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- WrapInFunction.lua

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger");

local WrapInFunction = Step:extend();
WrapInFunction.Description = "This Step Wraps the Entire Script into a Function (Weakened)";
WrapInFunction.Name = "Wrap in Function";

WrapInFunction.SettingsDescriptor = {
	Iterations = {
		name = "Iterations",
		description = "The Number Of Iterations",
		type = "number",
		default = 1, -- Keep at 1 (weaker - only one layer)
		min = 1,
		max = 3, -- Limit max iterations (weaker)
	}
}

function WrapInFunction:init(settings)
	
end

function WrapInFunction:apply(ast)
	logger:debug(string.format("WrapInFunction: Applying %d iteration(s)", self.Iterations));
	
	for i = 1, self.Iterations, 1 do
		local body = ast.body;

		local scope = Scope:new(ast.globalScope);
		body.scope:setParent(scope);

		-- Simple wrapper - obvious pattern (weaker)
		ast.body = Ast.Block({
			Ast.ReturnStatement({
				Ast.FunctionCallExpression(Ast.FunctionLiteralExpression({Ast.VarargExpression()}, body), {Ast.VarargExpression()})
			});
		}, scope);
		
		logger:debug(string.format("WrapInFunction: Completed iteration %d", i));
	end
	
	logger:info(string.format("WrapInFunction: Wrapped in %d layer(s)", self.Iterations));
end

return WrapInFunction;
