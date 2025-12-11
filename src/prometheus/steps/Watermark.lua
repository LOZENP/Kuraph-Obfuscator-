-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- Watermark.lua

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger");

local Watermark = Step:extend();
Watermark.Description = "This Step will add a watermark to the script (Weakened)";
Watermark.Name = "Watermark";

Watermark.SettingsDescriptor = {
  Content = {
    name = "Content",
    description = "The Content of the Watermark",
    type = "string",
    -- More obvious watermark (weaker)
    default = "Obfuscated with Weak Prometheus",
  },
  CustomVariable = {
    name = "Custom Variable",
    description = "The Variable that will be used for the Watermark",
    type = "string",
    -- More obvious variable name (weaker)
    default = "WATERMARK",
  }
}

function Watermark:init(settings)
	
end

function Watermark:apply(ast)
  local body = ast.body;
  
  logger:debug("Watermark: Adding watermark");
  
  if string.len(self.Content) > 0 then
    local scope, variable = ast.globalScope:resolve(self.CustomVariable);
    local watermark = Ast.AssignmentVariable(ast.globalScope, variable);

    local functionScope = Scope:new(body.scope);
    functionScope:addReferenceToHigherScope(ast.globalScope, variable);
    
    local arg = functionScope:addVariable();
    
    -- Simplified watermark insertion (weaker - easier to spot)
    local statement = Ast.PassSelfFunctionCallStatement(Ast.StringExpression(self.Content), "gsub", {
      Ast.StringExpression(".+"),
      Ast.FunctionLiteralExpression({
        Ast.VariableExpression(functionScope, arg)
      }, Ast.Block({
        Ast.AssignmentStatement({
          watermark
        }, {
          Ast.VariableExpression(functionScope, arg)
        })
      }, functionScope))
    });

    table.insert(ast.body.statements, 1, statement)
    
    logger:info(string.format("Watermark: Added watermark '%s' to variable '%s'", self.Content, self.CustomVariable));
  else
    logger:warn("Watermark: No content provided, skipping");
  end
end

return Watermark;
