-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- namegenerators.lua
-- This module exports all available name generators

return {
	-- Use simpler generators by default (weaker)
	Mangled = require("prometheus.namegenerators.mangled");
	MangledShuffled = require("prometheus.namegenerators.mangled_shuffled");
	-- Il is the weakest generator - just uses I, l patterns
	Il = require("prometheus.namegenerators.Il");
	-- Number generator creates numeric-like names
	Number = require("prometheus.namegenerators.number");
	-- Removed Confuse generator (weaker - one less obfuscation option)
	-- Confuse = require("prometheus.namegenerators.confuse");
	
	-- Add a new "Simple" generator that's even weaker (weaker)
	Simple = {
		Name = "Simple";
		Description = "Simple sequential variable names";
		
		-- Counter for sequential names
		counter = 0;
		
		prepare = function(ast)
			-- Reset counter
			Simple.counter = 0;
		end;
		
		generateName = function(id, scope, originalName)
			Simple.counter = Simple.counter + 1;
			-- Just return sequential names: a, b, c, etc. (weaker - very predictable)
			return string.char(96 + (Simple.counter % 26) + 1) .. (Simple.counter > 26 and tostring(math.floor(Simple.counter / 26)) or "");
		end;
	};
}
