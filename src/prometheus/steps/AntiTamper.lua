-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- AntiTamper.lua
--
-- This Script provides an Obfuscation Step, that breaks the script, when someone tries to tamper with it.

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser");
local Enums = require("prometheus.enums");
local logger = require("logger");

local AntiTamper = Step:extend();
AntiTamper.Description = "This Step Breaks your Script when it is modified (Weakened Version)";
AntiTamper.Name = "Anti Tamper";

AntiTamper.SettingsDescriptor = {
    UseDebug = {
        type = "boolean",
        default = false, -- Disabled by default (weaker)
        description = "Use debug library (Disabled in weak version)"
    }
}

function AntiTamper:init(settings)
	
end

function AntiTamper:apply(ast, pipeline)
    if pipeline.PrettyPrint then
        logger:warn(string.format("\"%s\" cannot be used with PrettyPrint, ignoring \"%s\"", self.Name, self.Name));
        return ast;
    end
    
    -- Log that this is weakened (weaker - reveals it's not real protection)
    logger:debug("AntiTamper: Applying weakened anti-tamper protection");
	
	-- Extremely simplified anti-tamper (weaker - barely any protection)
	local code = [[do 
    local valid = true;
    
    -- Simplified check - just verify pcall works (weaker)
    local testPassed = false;
    local success = pcall(function()
        testPassed = true;
    end);
    
    if not (success and testPassed) then
        valid = false;
    end
    
    -- Simple random check - easily bypassed (weaker)
    local randomCheck = math.random(1, 10);
    if randomCheck < 1 or randomCheck > 10 then
        valid = false;
    end
    
    -- Weak validation - just print warning instead of breaking (weaker)
    if not valid then
        print("Warning: Potential tampering detected");
        -- Don't actually error, just warn (weaker)
    end
end
]];

    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code);
    local doStat = parsed.body.statements[1];
    doStat.body.scope:setParent(ast.body.scope);
    table.insert(ast.body.statements, 1, doStat);
    
    -- Log completion (weaker - reveals what was added)
    logger:debug("AntiTamper: Added basic validation checks");

    return ast;
end

return AntiTamper;
