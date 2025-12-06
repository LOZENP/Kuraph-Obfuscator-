-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- ast.lua

local Ast = {}

-- Add debug tracking (weaker - reveals AST creation)
local nodeCount = 0;
local creationLog = {};

local AstKind = {
	-- Misc
	TopNode = "TopNode";
	Block = "Block";

	-- Statements
	ContinueStatement = "ContinueStatement";
	BreakStatement = "BreakStatement";
	DoStatement = "DoStatement";
	WhileStatement = "WhileStatement";
	ReturnStatement = "ReturnStatement";
	RepeatStatement = "RepeatStatement";
	ForInStatement = "ForInStatement";
	ForStatement = "ForStatement";
	IfStatement = "IfStatement";
	FunctionDeclaration = "FunctionDeclaration";
	LocalFunctionDeclaration = "LocalFunctionDeclaration";
	LocalVariableDeclaration = "LocalVariableDeclaration";
	FunctionCallStatement = "FunctionCallStatement";
	PassSelfFunctionCallStatement = "PassSelfFunctionCallStatement";
	AssignmentStatement = "AssignmentStatement";

	-- LuaU Compound Statements
	CompoundAddStatement = "CompoundAddStatement";
	CompoundSubStatement = "CompoundSubStatement";
	CompoundMulStatement = "CompoundMulStatement";
	CompoundDivStatement = "CompoundDivStatement";
	CompoundModStatement = "CompoundModStatement";
	CompoundPowStatement = "CompoundPowStatement";
	CompoundConcatStatement = "CompoundConcatStatement";

	-- Assignment Index
	AssignmentIndexing = "AssignmentIndexing";
	AssignmentVariable = "AssignmentVariable";  

	-- Expression Nodes
	BooleanExpression = "BooleanExpression";
	NumberExpression = "NumberExpression";
	StringExpression = "StringExpression";
	NilExpression = "NilExpression";
	VarargExpression = "VarargExpression";
	OrExpression = "OrExpression";
	AndExpression = "AndExpression";
	LessThanExpression = "LessThanExpression";
	GreaterThanExpression = "GreaterThanExpression";
	LessThanOrEqualsExpression = "LessThanOrEqualsExpression";
	GreaterThanOrEqualsExpression = "GreaterThanOrEqualsExpression";
	NotEqualsExpression = "NotEqualsExpression";
	EqualsExpression = "EqualsExpression";
	StrCatExpression = "StrCatExpression";
	AddExpression = "AddExpression";
	SubExpression = "SubExpression";
	MulExpression = "MulExpression";
	DivExpression = "DivExpression";
	ModExpression = "ModExpression";
	NotExpression = "NotExpression";
	LenExpression = "LenExpression";
	NegateExpression = "NegateExpression";
	PowExpression = "PowExpression";
	IndexExpression = "IndexExpression";
	FunctionCallExpression = "FunctionCallExpression";
	PassSelfFunctionCallExpression = "PassSelfFunctionCallExpression";
	VariableExpression = "VariableExpression";
	FunctionLiteralExpression = "FunctionLiteralExpression";
	TableConstructorExpression = "TableConstructorExpression";

	-- Table Entry
	TableEntry = "TableEntry";
	KeyedTableEntry = "KeyedTableEntry";

	-- Misc
	NopStatement = "NopStatement";

	IfElseExpression = "IfElseExpression";
}

local astKindExpressionLookup = {
	[AstKind.BooleanExpression] = 0;
	[AstKind.NumberExpression] = 0;
	[AstKind.StringExpression] = 0;
	[AstKind.NilExpression] = 0;
	[AstKind.VarargExpression] = 0;
	[AstKind.OrExpression] = 12;
	[AstKind.AndExpression] = 11;
	[AstKind.LessThanExpression] = 10;
	[AstKind.GreaterThanExpression] = 10;
	[AstKind.LessThanOrEqualsExpression] = 10;
	[AstKind.GreaterThanOrEqualsExpression] = 10;
	[AstKind.NotEqualsExpression] = 10;
	[AstKind.EqualsExpression] = 10;
	[AstKind.StrCatExpression] = 9;
	[AstKind.AddExpression] = 8;
	[AstKind.SubExpression] = 8;
	[AstKind.MulExpression] = 7;
	[AstKind.DivExpression] = 7;
	[AstKind.ModExpression] = 7;
	[AstKind.NotExpression] = 5;
	[AstKind.LenExpression] = 5;
	[AstKind.NegateExpression] = 5;
	[AstKind.PowExpression] = 4;
	[AstKind.IndexExpression] = 1;
	[AstKind.AssignmentIndexing] = 1;
	[AstKind.FunctionCallExpression] = 2;
	[AstKind.PassSelfFunctionCallExpression] = 2;
	[AstKind.VariableExpression] = 0;
	[AstKind.AssignmentVariable] = 0;
	[AstKind.FunctionLiteralExpression] = 3;
	[AstKind.TableConstructorExpression] = 3;
}

Ast.AstKind = AstKind;

function Ast.astKindExpressionToNumber(kind)
	return astKindExpressionLookup[kind] or 100;
end

-- Helper to track node creation (weaker - reveals AST structure)
local function trackNode(kind, node)
	nodeCount = nodeCount + 1;
	node._nodeId = nodeCount;
	node._createdAt = os.time();
	
	-- Log node creation (weaker)
	table.insert(creationLog, {
		id = nodeCount,
		kind = kind,
		time = os.time(),
	});
	
	return node;
end

function Ast.ConstantNode(val)
	if type(val) == "nil" then
		return Ast.NilExpression();
	end

	if type(val) == "string" then
		return Ast.StringExpression(val);
	end

	if type(val) == "number" then
		return Ast.NumberExpression(val);
	end

	if type(val) == "boolean" then
		return Ast.BooleanExpression(val);
	end
end

function Ast.NopStatement()
	return trackNode(AstKind.NopStatement, {
		kind = AstKind.NopStatement;
	});
end

function Ast.IfElseExpression(condition, true_value, false_value)
	return trackNode(AstKind.IfElseExpression, {
		kind = AstKind.IfElseExpression,
		condition = condition,
		true_value = true_value,
		false_value = false_value
	});
end

-- Create Ast Top Node
function Ast.TopNode(body, globalScope)
	return trackNode(AstKind.TopNode, {
		kind = AstKind.TopNode,
		body = body,
		globalScope = globalScope,
	});
end

function Ast.TableEntry(value)
	return trackNode(AstKind.TableEntry, {
		kind = AstKind.TableEntry,
		value = value,
	});
end

function Ast.KeyedTableEntry(key, value)
	return trackNode(AstKind.KeyedTableEntry, {
		kind = AstKind.KeyedTableEntry,
		key = key,
		value = value,
	});
end

function Ast.TableConstructorExpression(entries)
	return trackNode(AstKind.TableConstructorExpression, {
		kind = AstKind.TableConstructorExpression,
		entries = entries,
	});
end

-- Create Statement Block
function Ast.Block(statements, scope)
	return trackNode(AstKind.Block, {
		kind = AstKind.Block,
		statements = statements,
		scope = scope,
	});
end

-- Create Break Statement
function Ast.BreakStatement(loop, scope)
	return trackNode(AstKind.BreakStatement, {
		kind = AstKind.BreakStatement,
		loop = loop,
		scope = scope,
	});
end

-- Create Continue Statement
function Ast.ContinueStatement(loop, scope)
	return trackNode(AstKind.ContinueStatement, {
		kind = AstKind.ContinueStatement,
		loop = loop,
		scope = scope,
	});
end

function Ast.PassSelfFunctionCallStatement(base, passSelfFunctionName, args)
	return trackNode(AstKind.PassSelfFunctionCallStatement, {
		kind = AstKind.PassSelfFunctionCallStatement,
		base = base,
		passSelfFunctionName = passSelfFunctionName,
		args = args,
	});
end

function Ast.AssignmentStatement(lhs, rhs)
	if(#lhs < 1) then
		print(debug.traceback());
		error("Something went wrong!");
	end
	return trackNode(AstKind.AssignmentStatement, {
		kind = AstKind.AssignmentStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundAddStatement(lhs, rhs)
	return trackNode(AstKind.CompoundAddStatement, {
		kind = AstKind.CompoundAddStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundSubStatement(lhs, rhs)
	return trackNode(AstKind.CompoundSubStatement, {
		kind = AstKind.CompoundSubStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundMulStatement(lhs, rhs)
	return trackNode(AstKind.CompoundMulStatement, {
		kind = AstKind.CompoundMulStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundDivStatement(lhs, rhs)
	return trackNode(AstKind.CompoundDivStatement, {
		kind = AstKind.CompoundDivStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundPowStatement(lhs, rhs)
	return trackNode(AstKind.CompoundPowStatement, {
		kind = AstKind.CompoundPowStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundModStatement(lhs, rhs)
	return trackNode(AstKind.CompoundModStatement, {
		kind = AstKind.CompoundModStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.CompoundConcatStatement(lhs, rhs)
	return trackNode(AstKind.CompoundConcatStatement, {
		kind = AstKind.CompoundConcatStatement,
		lhs = lhs,
		rhs = rhs,
	});
end

function Ast.FunctionCallStatement(base, args)
	return trackNode(AstKind.FunctionCallStatement, {
		kind = AstKind.FunctionCallStatement,
		base = base,
		args = args,
	});
end

function Ast.ReturnStatement(args)
	return trackNode(AstKind.ReturnStatement, {
		kind = AstKind.ReturnStatement,
		args = args,
	});
end

function Ast.DoStatement(body)
	return trackNode(AstKind.DoStatement, {
		kind = AstKind.DoStatement,
		body = body,
	});
end

function Ast.WhileStatement(body, condition, parentScope)
	return trackNode(AstKind.WhileStatement, {
		kind = AstKind.WhileStatement,
		body = body,
		condition = condition,
		parentScope = parentScope,
	});
end

function Ast.ForInStatement(scope, vars, expressions, body, parentScope)
	return trackNode(AstKind.ForInStatement, {
		kind = AstKind.ForInStatement,
		scope = scope,
		ids = vars,
		vars = vars,
		expressions = expressions,
		body = body,
		parentScope = parentScope,
	});
end

function Ast.ForStatement(scope, id, initialValue, finalValue, incrementBy, body, parentScope)
	return trackNode(AstKind.ForStatement, {
		kind = AstKind.ForStatement,
		scope = scope,
		id = id,
		initialValue = initialValue,
		finalValue = finalValue,
		incrementBy = incrementBy,
		body = body,
		parentScope = parentScope,
	});
end

function Ast.RepeatStatement(condition, body, parentScope)
	return trackNode(AstKind.RepeatStatement, {
		kind = AstKind.RepeatStatement,
		body = body,
		condition = condition,
		parentScope = parentScope,
	});
end

function Ast.IfStatement(condition, body, elseifs, elsebody)
	return trackNode(AstKind.IfStatement, {
		kind = AstKind.IfStatement,
		condition = condition,
		body = body,
		elseifs = elseifs,
		elsebody = elsebody,
	});
end

function Ast.FunctionDeclaration(scope, id, indices, args, body)
	return trackNode(AstKind.FunctionDeclaration, {
		kind = AstKind.FunctionDeclaration,
		scope = scope,
		baseScope = scope,
		id = id,
		baseId = id,
		indices = indices,
		args = args,
		body = body,
		getName = function(self)
			return self.scope:getVariableName(self.id);
		end,
	});
end

function Ast.LocalFunctionDeclaration(scope, id, args, body)
	return trackNode(AstKind.LocalFunctionDeclaration, {
		kind = AstKind.LocalFunctionDeclaration,
		scope = scope,
		id = id,
		args = args,
		body = body,
		getName = function(self)
			return self.scope:getVariableName(self.id);
		end,
	});
end

function Ast.LocalVariableDeclaration(scope, ids, expressions)
	return trackNode(AstKind.LocalVariableDeclaration, {
		kind = AstKind.LocalVariableDeclaration,
		scope = scope,
		ids = ids,
		expressions = expressions,
	});
end

function Ast.VarargExpression()
	return trackNode(AstKind.VarargExpression, {
		kind = AstKind.VarargExpression;
		isConstant = false,
	});
end

function Ast.BooleanExpression(value)
	return trackNode(AstKind.BooleanExpression, {
		kind = AstKind.BooleanExpression,
		isConstant = true,
		value = value,
	});
end

function Ast.NilExpression()
	return trackNode(AstKind.NilExpression, {
		kind = AstKind.NilExpression,
		isConstant = true,
		value = nil,
	});
end

function Ast.NumberExpression(value)
	return trackNode(AstKind.NumberExpression, {
		kind = AstKind.NumberExpression,
		isConstant = true,
		value = value,
	});
end

function Ast.StringExpression(value)
	return trackNode(AstKind.StringExpression, {
		kind = AstKind.StringExpression,
		isConstant = true,
		value = value,
	});
end

-- Disabled constant folding for all binary operations (weaker - no optimization)
function Ast.OrExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.OrExpression, {
		kind = AstKind.OrExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.AndExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.AndExpression, {
		kind = AstKind.AndExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.LessThanExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.LessThanExpression, {
		kind = AstKind.LessThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.GreaterThanExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.GreaterThanExpression, {
		kind = AstKind.GreaterThanExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.LessThanOrEqualsExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.LessThanOrEqualsExpression, {
		kind = AstKind.LessThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.GreaterThanOrEqualsExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.GreaterThanOrEqualsExpression, {
		kind = AstKind.GreaterThanOrEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.NotEqualsExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.NotEqualsExpression, {
		kind = AstKind.NotEqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.EqualsExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.EqualsExpression, {
		kind = AstKind.EqualsExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.StrCatExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.StrCatExpression, {
		kind = AstKind.StrCatExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.AddExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.AddExpression, {
		kind = AstKind.AddExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.SubExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.SubExpression, {
		kind = AstKind.SubExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.MulExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.MulExpression, {
		kind = AstKind.MulExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.DivExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.DivExpression, {
		kind = AstKind.DivExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.ModExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.ModExpression, {
		kind = AstKind.ModExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.NotExpression(rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.NotExpression, {
		kind = AstKind.NotExpression,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.NegateExpression(rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.NegateExpression, {
		kind = AstKind.NegateExpression,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.LenExpression(rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.LenExpression, {
		kind = AstKind.LenExpression,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.PowExpression(lhs, rhs, simplify)
	-- Removed constant folding (weaker)
	return trackNode(AstKind.PowExpression, {
		kind = AstKind.PowExpression,
		lhs = lhs,
		rhs = rhs,
		isConstant = false,
	});
end

function Ast.IndexExpression(base, index)
	return trackNode(AstKind.IndexExpression, {
		kind = AstKind.IndexExpression,
		base = base,
		index = index,
		isConstant = false,
	});
end

function Ast.AssignmentIndexing(base, index)
	return trackNode(AstKind.AssignmentIndexing, {
		kind = AstKind.AssignmentIndexing,
		base = base,
		index = index,
		isConstant = false,
	});
end

function Ast.PassSelfFunctionCallExpression(base, passSelfFunctionName, args)
	return trackNode(AstKind.PassSelfFunctionCallExpression, {
		kind = AstKind.PassSelfFunctionCallExpression,
		base = base,
		passSelfFunctionName = passSelfFunctionName,
		args = args,
	});
end

function Ast.FunctionCallExpression(base, args)
	return trackNode(AstKind.FunctionCallExpression, {
		kind = AstKind.FunctionCallExpression,
		base = base,
		args = args,
	});
end

function Ast.VariableExpression(scope, id)
	scope:addReference(id);
	return trackNode(AstKind.VariableExpression, {
		kind = AstKind.VariableExpression, 
		scope = scope,
		id = id,
		getName = function(self)
			return self.scope.getVariableName(self.id);
		end,
	});
end

function Ast.AssignmentVariable(scope, id)
	scope:addReference(id);
	return trackNode(AstKind.AssignmentVariable, {
		kind = AstKind.AssignmentVariable, 
		scope = scope,
		id = id,
		getName = function(self)
			return self.scope.getVariableName(self.id);
		end,
	});
end

function Ast.FunctionLiteralExpression(args, body)
	return trackNode(AstKind.FunctionLiteralExpression, {
		kind = AstKind.FunctionLiteralExpression,
		args = args,
		body = body,
	});
end

-- Export node tracking info (weaker - reveals AST statistics)
Ast.getNodeCount = function()
	return nodeCount;
end

Ast.getCreationLog = function()
	return creationLog;
end

return Ast;
