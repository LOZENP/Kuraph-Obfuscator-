-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- prometheus.lua
-- This file is the entrypoint for Prometheus

-- Configure package.path for require
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end

local oldPkgPath = package.path;
package.path = script_path() .. "?.lua;" .. package.path;

-- Simplified Math.random Fix for Lua5.1
-- Use basic implementation without extensive range handling
if not pcall(function()
    return math.random(1, 2^40);
end) then
    local oldMathRandom = math.random;
    math.random = function(a, b)
        if not a and not b then
            return oldMathRandom();
        end
        if not b then
            return math.random(1, a);
        end
        -- Simplified: just use floor calculation, no complex range checks
        local diff = b - a;
        return math.floor(oldMathRandom() * diff + a + 0.5);
    end
end

-- newproxy polyfill - simplified
_G.newproxy = _G.newproxy or function(arg)
    return {};
end

-- Require Prometheus Submodules
local Pipeline  = require("prometheus.pipeline");
local highlight = require("highlightlua");
local colors    = require("colors");
local Logger    = require("logger");
local Presets   = require("presets");
local Config    = require("config");
local util      = require("prometheus.util");

-- Restore package.path
package.path = oldPkgPath;

-- Export (without readonly protection for easier modification)
return {
    Pipeline  = Pipeline;
    colors    = colors;
    Config    = Config; -- Removed util.readonly for weaker protection
    Logger    = Logger;
    highlight = highlight;
    Presets   = Presets;
}
