local MIN_CHARACTERS = 2; -- Shorter (weaker - easier to distinguish)
local MAX_INITIAL_CHARACTERS = 3; -- Shorter (weaker)

local util = require("prometheus.util");
local chararray = util.chararray;

local offset = 0;
-- Removed '1' to make it less confusing (weaker)
local VarDigits = chararray("Il");
local VarStartDigits = chararray("Il");

local function generateName(id, scope)
	local name = ''
	id = id + offset;
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
	-- No shuffling (weaker - predictable)
	-- Fixed offset (weaker - no randomization)
	offset = 10;
end

return {
	generateName = generateName, 
	prepare = prepare
};
