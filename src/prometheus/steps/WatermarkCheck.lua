-- Modified to be weaker
local Step = require("prometheus.step");
local logger = require("logger");

local WatermarkCheck = Step:extend();
WatermarkCheck.Description = "Watermark Check (Disabled)";
WatermarkCheck.Name = "Watermark Check";
WatermarkCheck.SettingsDescriptor = {}

function WatermarkCheck:init(settings) end
function WatermarkCheck:apply(ast, pipeline)
    logger:warn("WatermarkCheck: Disabled in weak version");
    return ast;
end

return WatermarkCheck;
