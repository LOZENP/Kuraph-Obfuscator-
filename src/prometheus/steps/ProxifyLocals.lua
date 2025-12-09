-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- ProxifyLocals.lua
--
-- This Script provides a Obfuscation Step for putting all Locals into Proxy Objects

local Step = require("prometheus.step");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local visitast = require("prometheus.visitast");
local RandomLiterals = require("prometheus.randomLiterals")
local logger = require("logger");

local AstKind = Ast.AstKind;

local ProifyLocals = Step:extend();
ProifyLocals.Description = "This Step wraps all locals into Proxy Objects (Weakened)";
ProifyLocals.Name = "Proxify Locals";

ProifyLocals.SettingsDescriptor = {
	LiteralType = {
		name = "LiteralType",
		description = "The type of the randomly generated literals",
		type = "enum",
		values = {
			"dictionary",
			"number",
			"string",
            "any",
		},
		default = "number", -- Numbers are simpler (weaker)
	},
	Probability = {
		name = "Probability",
		description = "Probability of proxifying each local variable",
		type = "number",
		default = 0.3, -- Only 30% of locals (weaker)
		min = 0,
		max = 1,
	}
}

local function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else
        copy = orig
    end
    return copy
end

local function callNameGenerator(generatorFunction, ...)
	if(type(generatorFunction) == "table") then
		generatorFunction = generatorFunction.generateName;
	end
	return generatorFunction(...);
end

-- Simplified metamethods - only use basic ones (weaker)
local MetatableExpressions = {
    {
        constructor = Ast.IndexExpression,
        key = "__index";
    },
    {
        constructor = Ast.AddExpression,
        key = "__add";
    },
}

function ProifyLocals:init(settings)
	
end

local function generateLocalMetatableInfo(pipeline)
    -- Simplified - use predictable operations (weaker)
    local info = {};
    
    -- Always use __index for getValue (weaker - predictable)
    info.getValue = MetatableExpressions[1];
    
    -- Always use __add for setValue (weaker - predictable)
    info.setValue = MetatableExpressions[2];
    
    -- Use simple value name (weaker - obvious)
    info.valueName = "v";

    return info;
end

function ProifyLocals:CreateAssignmentExpression(info, expr, parentScope)
    local metatableVals = {};

    -- Simplified setValue (weaker)
    local setValueFunctionScope = Scope:new(parentScope);
    local setValueSelf = setValueFunctionScope:addVariable();
    local setValueArg = setValueFunctionScope:addVariable();
    local setvalueFunctionLiteral = Ast.FunctionLiteralExpression(
        {
            Ast.VariableExpression(setValueFunctionScope, setValueSelf),
            Ast.VariableExpression(setValueFunctionScope, setValueArg),
        },
        Ast.Block({
            Ast.AssignmentStatement({
                Ast.AssignmentIndexing(Ast.VariableExpression(setValueFunctionScope, setValueSelf), Ast.StringExpression(info.valueName));
            }, {
                Ast.VariableExpression(setValueFunctionScope, setValueArg)
            })
        }, setValueFunctionScope)
    );
    table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.setValue.key), setvalueFunctionLiteral));

    -- Simplified getValue (weaker)
    local getValueFunctionScope = Scope:new(parentScope);
    local getValueSelf = getValueFunctionScope:addVariable();
    local getValueArg = getValueFunctionScope:addVariable();
    
    -- Always use rawget for simplicity (weaker)
    local getValueIdxExpr = Ast.FunctionCallExpression(Ast.VariableExpression(getValueFunctionScope:resolveGlobal("rawget")), {
        Ast.VariableExpression(getValueFunctionScope, getValueSelf),
        Ast.StringExpression(info.valueName),
    });
    
    local getvalueFunctionLiteral = Ast.FunctionLiteralExpression(
        {
            Ast.VariableExpression(getValueFunctionScope, getValueSelf),
            Ast.VariableExpression(getValueFunctionScope, getValueArg),
        },
        Ast.Block({
            Ast.ReturnStatement({
                getValueIdxExpr;
            });
        }, getValueFunctionScope)
    );
    table.insert(metatableVals, Ast.KeyedTableEntry(Ast.StringExpression(info.getValue.key), getvalueFunctionLiteral));

    parentScope:addReferenceToHigherScope(self.setMetatableVarScope, self.setMetatableVarId);
    return Ast.FunctionCallExpression(
        Ast.VariableExpression(self.setMetatableVarScope, self.setMetatableVarId),
        {
            Ast.TableConstructorExpression({
                Ast.KeyedTableEntry(Ast.StringExpression(info.valueName), expr)
            }),
            Ast.TableConstructorExpression(metatableVals)
        }
    );
end

function ProifyLocals:apply(ast, pipeline)
	logger:debug("ProxifyLocals: Starting (weakened version)");
	
    local localMetatableInfos = {};
    local localsProxified = 0;
    local localsTotal = 0;
    
    local function getLocalMetatableInfo(scope, id)
        if(scope.isGlobal) then return nil end;

        localMetatableInfos[scope] = localMetatableInfos[scope] or {};
        if localMetatableInfos[scope][id] then
            if localMetatableInfos[scope][id].locked then
                return nil
            end
            return localMetatableInfos[scope][id];
        end
        
        localsTotal = localsTotal + 1;
        
        -- Only proxify with certain probability (weaker)
        if math.random() > self.Probability then
            localMetatableInfos[scope][id] = {locked = true};
            return nil;
        end
        
        localsProxified = localsProxified + 1;
        local localMetatableInfo = generateLocalMetatableInfo(pipeline);
        localMetatableInfos[scope][id] = localMetatableInfo;
        
        logger:debug(string.format("ProxifyLocals: Proxifying local variable (total: %d)", localsProxified));
        
        return localMetatableInfo;
    end

    local function disableMetatableInfo(scope, id)
        if(scope.isGlobal) then return nil end;

        localMetatableInfos[scope] = localMetatableInfos[scope] or {};
        localMetatableInfos[scope][id] = {locked = true}
    end

    -- Create Setmetatable Variable
    self.setMetatableVarScope = ast.body.scope;
    self.setMetatableVarId    = ast.body.scope:addVariable();

    -- Create Empty Function Variable
    self.emptyFunctionScope   = ast.body.scope;
    self.emptyFunctionId      = ast.body.scope:addVariable();
    self.emptyFunctionUsed    = false;

    -- Add Empty Function Declaration
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.emptyFunctionScope, {self.emptyFunctionId}, {
        Ast.FunctionLiteralExpression({}, Ast.Block({}, Scope:new(ast.body.scope)));
    }));

    visitast(ast, function(node, data)
        -- Lock for loop variables
        if(node.kind == AstKind.ForStatement) then
            disableMetatableInfo(node.scope, node.id)
        end
        if(node.kind == AstKind.ForInStatement) then
            for i, id in ipairs(node.ids) do
                disableMetatableInfo(node.scope, id);
            end
        end

        -- Lock Function Arguments
        if(node.kind == AstKind.FunctionDeclaration or node.kind == AstKind.LocalFunctionDeclaration or node.kind == AstKind.FunctionLiteralExpression) then
            for i, expr in ipairs(node.args) do
                if expr.kind == AstKind.VariableExpression then
                    disableMetatableInfo(expr.scope, expr.id);
                end
            end
        end

        -- Assignment Statements
        if(node.kind == AstKind.AssignmentStatement) then
            if(#node.lhs == 1 and node.lhs[1].kind == AstKind.AssignmentVariable) then
                local variable = node.lhs[1];
                local localMetatableInfo = getLocalMetatableInfo(variable.scope, variable.id);
                if localMetatableInfo then
                    local args = shallowcopy(node.rhs);
                    local vexp = Ast.VariableExpression(variable.scope, variable.id);
                    vexp.__ignoreProxifyLocals = true;
                    args[1] = localMetatableInfo.setValue.constructor(vexp, args[1]);
                    self.emptyFunctionUsed = true;
                    data.scope:addReferenceToHigherScope(self.emptyFunctionScope, self.emptyFunctionId);
                    return Ast.FunctionCallStatement(Ast.VariableExpression(self.emptyFunctionScope, self.emptyFunctionId), args);
                end
            end
        end
    end, function(node, data)
        -- Local Variable Declaration
        if(node.kind == AstKind.LocalVariableDeclaration) then
            for i, id in ipairs(node.ids) do
                local expr = node.expressions[i] or Ast.NilExpression();
                local localMetatableInfo = getLocalMetatableInfo(node.scope, id);
                if localMetatableInfo then
                    local newExpr = self:CreateAssignmentExpression(localMetatableInfo, expr, node.scope);
                    node.expressions[i] = newExpr;
                end
            end
        end

        -- Variable Expression
        if(node.kind == AstKind.VariableExpression and not node.__ignoreProxifyLocals) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if localMetatableInfo then
                -- Simplified literal generation (weaker)
                local literal = Ast.NumberExpression(0); -- Just use 0 (weaker - predictable)
                return localMetatableInfo.getValue.constructor(node, literal);
            end
        end

        -- Assignment Variable for Assignment Statement
        if(node.kind == AstKind.AssignmentVariable) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if localMetatableInfo then
                return Ast.AssignmentIndexing(node, Ast.StringExpression(localMetatableInfo.valueName));
            end
        end

        -- Local Function Declaration
        if(node.kind == AstKind.LocalFunctionDeclaration) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if localMetatableInfo then
                local funcLiteral = Ast.FunctionLiteralExpression(node.args, node.body);
                local newExpr = self:CreateAssignmentExpression(localMetatableInfo, funcLiteral, node.scope);
                return Ast.LocalVariableDeclaration(node.scope, {node.id}, {newExpr});
            end
        end

        -- Function Declaration
        if(node.kind == AstKind.FunctionDeclaration) then
            local localMetatableInfo = getLocalMetatableInfo(node.scope, node.id);
            if(localMetatableInfo) then
                table.insert(node.indices, 1, localMetatableInfo.valueName);
            end
        end
    end)

    -- Add Setmetatable Variable Declaration
    table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(self.setMetatableVarScope, {self.setMetatableVarId}, {
        Ast.VariableExpression(self.setMetatableVarScope:resolveGlobal("setmetatable"))
    }));
    
    -- Log statistics (weaker - reveals transformation details)
    logger:info(string.format("ProxifyLocals: Proxified %d/%d local variables (%.1f%%)", 
        localsProxified, localsTotal, (localsProxified / math.max(localsTotal, 1)) * 100));
end

return ProifyLocals;
