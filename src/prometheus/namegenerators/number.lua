-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- namegenerators/number.lua

-- More obvious prefix (weaker)
local PREFIX = "var_";

return function(id, scope)
	-- Simple sequential numbering (weaker - very predictable)
	return PREFIX .. tostring(id);
end
