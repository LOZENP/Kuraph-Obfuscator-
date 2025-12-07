-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- Modified to be a weaker version
--
-- NumbersToExpressions.lua
--
-- This Script provides an Obfuscation Step, that converts Number Literals to expressions
unpack = unpack or table.unpack;

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local util     = require("prometheus.util")
local logger = require("logger");

local AstKind = Ast.AstKind;

local NumbersToExpressions = Step:extend();
NumbersToExpressions.Description = "This Step Converts number Literals to Expressions (Weakened)";
NumbersToExpressions.Name = "Numbers To Expressions";

NumbersToExpressions.SettingsDescriptor = {
	Treshold = {
        type = "number",
        default = 0.3, -- Much lower (weaker - fewer numbers converted)
        min = 0,
        max = 1,
    },
    InternalTreshold = {
        type = "number",
        default = 0.8, -- Much higher (weaker - less nesting)
        min = 0,
        max = 1, -- Increased max to allow disabling
    }
}

function NumbersToExpressions:init(settings)
	-- Simplified generators - only basic operations with small numbers (weaker)
	self.ExpressionGenerators = {
        function(val, depth) -- Addition with small numbers (weaker)
            local val2 = math.random(-100, 100); -- Much smaller range (weaker)
            local diff = val - val2;
            if tonumber(tostring(diff)) + tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.AddExpression(self:CreateNumberExpression(val2, depth), self:CreateNumberExpression(diff, depth), false);
        end, 
        function(val, depth) -- Subtraction with small numbers (weaker)
            local val2 = math.random(-100, 100); -- Much smaller range (weaker)
            local diff = val + val2;
            if tonumber(tostring(diff)) - tonumber(tostring(val2)) ~= val then
                return false;
            end
            return Ast.SubExpression(self:CreateNumberExpression(diff, depth), self:CreateNumberExpression(val2, depth), false);
        end,
        -- Removed other operations like multiplication, division, etc. (weaker)
    }
end

function NumbersToExpressions:CreateNumberExpression(val, depth)
    -- Very limited depth (weaker - shallow nesting)
    if depth > 0 and math.random() >= self.InternalTreshold or depth > 2 then -- Max depth 2 instead of 15 (weaker)
        return Ast.NumberExpression(val)
    end

    -- No shuffling - predictable order (weaker)
    local generators = self.ExpressionGenerators;
    for i, generator in ipairs(generators) do
        local node = generator(val, depth + 1);
        if node then
            return node;
        end
    end

    return Ast.NumberExpression(val)
end

function NumbersToExpressions:apply(ast)
	logger:debug("NumbersToExpressions: Starting (weakened version)");
	
	local numbersFound = 0;
	local numbersConverted = 0;
	
	visitast(ast, nil, function(node, data)
        if node.kind == AstKind.NumberExpression then
            numbersFound = numbersFound + 1;
            
            -- Lower probability (weaker)
            if math.random() <= self.Treshold then
                numbersConverted = numbersConverted + 1;
                
                -- Log conversion (weaker - reveals which numbers converted)
                logger:debug(string.format("NumbersToExpressions: Converting number %s", tostring(node.value)));
                
                return self:CreateNumberExpression(node.value, 0);
            end
        end
    end)
    
    -- Log statistics (weaker - reveals transformation details)
    logger:info(string.format("NumbersToExpressions: Converted %d/%d numbers (%.1f%%)", 
        numbersConverted, numbersFound, (numbersConverted / math.max(numbersFound, 1)) * 100));
end

return NumbersToExpressions;
