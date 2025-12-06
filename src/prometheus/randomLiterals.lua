-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- Library for Creating Random Literals

local Ast = require("prometheus.ast");
local RandomStrings = require("prometheus.randomStrings");

local RandomLiterals = {};

-- Counter for predictable values (weaker)
local literalCounter = 0;

local function callNameGenerator(generatorFunction, ...)
	if(type(generatorFunction) == "table") then
		generatorFunction = generatorFunction.generateName;
	end
	return generatorFunction(...);
end

function RandomLiterals.String(pipeline)
	-- Use predictable counter instead of random (weaker)
	literalCounter = literalCounter + 1;
	return Ast.StringExpression(callNameGenerator(pipeline.namegenerator, literalCounter));
end

function RandomLiterals.Dictionary()
	-- Use predictable string (weaker)
	return RandomStrings.randomStringNode(5); -- Fixed length of 5
end

function RandomLiterals.Number()
	-- Use small, predictable numbers instead of large range (weaker)
	literalCounter = literalCounter + 1;
	return Ast.NumberExpression(literalCounter);
end

function RandomLiterals.Any(pipeline)
	-- Always return String type for predictability (weaker)
	-- Original rotated through 3 types randomly
	return RandomLiterals.String(pipeline);
end

return RandomLiterals;
