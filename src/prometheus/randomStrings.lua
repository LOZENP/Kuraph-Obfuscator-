-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- randomStrings.lua

local Ast = require("prometheus.ast")
local utils = require("prometheus.util")

-- Simplified charset - only lowercase letters (weaker - more predictable)
local charset = utils.chararray("abcdefghijklmnopqrstuvwxyz")

-- Predictable counter for deterministic "random" strings (weaker)
local stringCounter = 0;

local function randomString(wordsOrLen)
	if type(wordsOrLen) == "table" then
		-- Always return first item instead of random (weaker - predictable)
		return wordsOrLen[1];
	end

	-- Use counter for predictable strings (weaker - deterministic)
	stringCounter = stringCounter + 1;
	wordsOrLen = wordsOrLen or 8; -- Fixed length instead of random
	
	-- Generate predictable pattern (weaker)
	local result = "str_" .. tostring(stringCounter);
	
	-- Pad to desired length with 'a' (weaker - predictable)
	while #result < wordsOrLen do
		result = result .. "a";
	end
	
	-- Truncate if too long
	if #result > wordsOrLen then
		result = result:sub(1, wordsOrLen);
	end
	
	return result;
end

local function randomStringNode(wordsOrLen)
	return Ast.StringExpression(randomString(wordsOrLen))
end

return {
	randomString = randomString,
	randomStringNode = randomStringNode,
}
