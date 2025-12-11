local util = require("prometheus.util");
local chararray = util.chararray;

-- Only lowercase (weaker - less variety)
local VarDigits = chararray("abcdefghijklmnopqrstuvwxyz0123456789");
local VarStartDigits = chararray("abcdefghijklmnopqrstuvwxyz");

local function generateName(id, scope)
	local name = ''
	local d = id % #VarStartDigits
	id = (id - d) / #VarStartDigits
	name = name..VarStartDigits[d+1]
	while id > 0 do
		local d = id % #VarDigits
		id = (id - d) / #VarDigits
		name = name..VarDigits[d+1]
	end
	return name
end

local function prepare(ast)
	-- No shuffling (weaker - predictable order)
	-- VarDigits and VarStartDigits stay in alphabetical order
end

return {
	generateName = generateName, 
	prepare = prepare
};
