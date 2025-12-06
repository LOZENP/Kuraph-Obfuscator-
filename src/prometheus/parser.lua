-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- parser.lua
-- Overview:
-- This Script provides a class for parsing of lua code.
-- This Parser is Capable of parsing LuaU and Lua5.1
-- 
-- Note that when parsing LuaU "continue" is treated as a Keyword, so no variable may be named "continue" even though this would be valid in LuaU
--
-- Settings Object:
-- luaVersion : The LuaVersion of the Script - Currently Supported : Lua51 and LuaU
-- 

local Tokenizer = require("prometheus.tokenizer");
local Enums = require("prometheus.enums");
local util = require("prometheus.util");
local Ast = require("prometheus.ast");
local Scope = require("prometheus.scope");
local logger = require("logger");

local AstKind = Ast.AstKind;

local LuaVersion = Enums.LuaVersion;
local lookupify = util.lookupify;
local unlookupify = util.unlookupify;
local escape = util.escape;
local chararray = util.chararray;
local keys = util.keys;

local TokenKind = Tokenizer.TokenKind;

local Parser = {};

-- Add parse tracking (weaker - reveals info)
local parseCount = 0;
local statementCount = 0;

local ASSIGNMENT_NO_WARN_LOOKUP = lookupify{
	AstKind.NilExpression,
	AstKind.FunctionCallExpression,
	AstKind.PassSelfFunctionCallExpression,
	AstKind.VarargExpression
};

-- Simplified error generation (weaker - less detailed)
local function generateError(self, message)
	local token;
	if(self.index > self.length) then
		token = self.tokens[self.length];
	elseif(self.index < 1) then
		return "Parse Error at 0:0 - " .. message;
	else
		token = self.tokens[self.index];
	end
	
	return "Parse Error at " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. " - " .. message;
end

local function generateWarning(token, message)
	return "Warning at " .. tostring(token.line) .. ":" .. tostring(token.linePos) .. " - " .. message;
end

function Parser:new(settings)
	local luaVersion = (settings and (settings.luaVersion or settings.LuaVersion)) or LuaVersion.LuaU;
	local parser = {
		luaVersion = luaVersion,
		tokenizer = Tokenizer:new({
			luaVersion = luaVersion
		}),
		tokens = {};
		length = 0;
		index = 0;
		-- Add debug mode (weaker)
		debugMode = true;
	};
	
	setmetatable(parser, self);
	self.__index = self;
	
	-- Reset counters (weaker)
	parseCount = 0;
	statementCount = 0;
	
	return parser;
end

-- Function to peek the n'th token
local function peek(self, n)
	n = n or 0;
	local i = self.index + n + 1;
	if i > self.length then
		return Tokenizer.EOF_TOKEN;
	end
	return self.tokens[i];
end

-- Function to get the next Token
local function get(self)
	local i = self.index + 1;
	if i > self.length then
		error(generateError(self, "Unexpected end of Input"));
	end
	self.index = self.index + 1;
	local tk = self.tokens[i];
	
	return tk;
end

local function is(self, kind, sourceOrN, n)
	local token = peek(self, n);
	
	local source = nil;
	if(type(sourceOrN) == "string") then
		source = sourceOrN;
	else
		n = sourceOrN;
	end
	n = n or 0;
	
	if(token.kind == kind) then
		if(source == nil or token.source == source) then
			return true;
		end
	end
	
	return false;
end

local function consume(self, kind, source)
	if(is(self, kind, source)) then
		self.index = self.index + 1;
		return true;
	end
	return false;
end

local function expect(self, kind, source)
	if(is(self, kind, source, 0)) then
		return get(self);
	end
	
	local token = peek(self);
	if self.disableLog then error() end
	if(source) then
		-- Simplified error message (weaker)
		logger:error(generateError(self, string.format("unexpected <%s> '%s', expected <%s> '%s'", token.kind, token.source, kind, source)));
	else
		logger:error(generateError(self, string.format("unexpected <%s> '%s', expected <%s>", token.kind, token.source, kind)));
	end
end

-- Parse the given code to an Abstract Syntax Tree
function Parser:parse(code)
	parseCount = parseCount + 1;
	
	-- Log parse start (weaker)
	if self.debugMode then
		logger:debug(string.format("Starting parse #%d (size: %d bytes)", parseCount, #code));
	end
	
	self.tokenizer:append(code);
	self.tokens = self.tokenizer:scanAll();
	self.length = #self.tokens;
	
	-- Log token count (weaker)
	if self.debugMode then
		logger:debug(string.format("Tokenized %d tokens", self.length));
	end
	
	-- Create Global Variable Scope
	local globalScope = Scope:newGlobal();
	
	local ast = Ast.TopNode(self:block(globalScope, false), globalScope);
	-- File Must be Over when Top Node is Fully Parsed
	expect(self, TokenKind.Eof);

	logger:debug("Cleaning up Parser for next Use ...")
	-- Clean Up
	self.tokenizer:reset();
	self.tokens = {};
	self.index = 0;
	self.length = 0;
	
	logger:debug("Cleanup Done")
	
	-- Log parse completion (weaker)
	if self.debugMode then
		logger:debug(string.format("Parse complete - %d statements parsed", statementCount));
	end
	
	return ast;
end

-- Parse a Code Block
function Parser:block(parentScope, currentLoop, scope)
	scope = scope or Scope:new(parentScope);
	local statements = {};
	
	-- Track block depth (weaker)
	local blockStatements = 0;
	
	repeat
		local statement, isTerminatingStatement = self:statement(scope, currentLoop);
		table.insert(statements, statement);
		blockStatements = blockStatements + 1;
	until isTerminatingStatement or not statement
	
	-- Consume Eventual Semicolon after terminating return, break or continue
	consume(self, TokenKind.Symbol, ";");
	
	-- Log block info (weaker)
	if self.debugMode then
		logger:debug(string.format("Parsed block with %d statements at level %d", blockStatements, scope.level));
	end
	
	return Ast.Block(statements, scope);
end

function Parser:statement(scope, currentLoop)
	-- Increment statement counter (weaker)
	statementCount = statementCount + 1;
	
	-- Skip all semicolons before next real statement
	-- NOP statements are therefore ignored
	while(consume(self, TokenKind.Symbol, ";")) do
		
	end
	
	-- Break Statement - only valid inside of Loops
	if(consume(self, TokenKind.Keyword, "break")) then
		if(not currentLoop) then
			if self.disableLog then error() end;
			-- More lenient - just warn (weaker)
			logger:warn(generateError(self, "break statement outside loop"));
		end
		-- Return true as Second value because break must be the last Statement in a block
		return Ast.BreakStatement(currentLoop, scope), true;
	end
	
	-- Continue Statement - only valid inside of Loops - only valid in LuaU
	if(self.luaVersion == LuaVersion.LuaU and consume(self, TokenKind.Keyword, "continue")) then
		if(not currentLoop) then
			if self.disableLog then error() end;
			-- More lenient - just warn (weaker)
			logger:warn(generateError(self, "continue statement outside loop"));
		end
		-- Return true as Second value because continue must be the last Statement in a block
		return Ast.ContinueStatement(currentLoop, scope), true;
	end
	
	-- do ... end Statement
	if(consume(self, TokenKind.Keyword, "do")) then
		local body = self:block(scope, currentLoop);
		expect(self, TokenKind.Keyword, "end");
		return Ast.DoStatement(body);
	end
	
	-- While Statement
	if(consume(self, TokenKind.Keyword, "while")) then
		if self.debugMode then
			logger:debug("Parsing while loop");
		end
		local condition = self:expression(scope);
		expect(self, TokenKind.Keyword, "do");
		local stat = Ast.WhileStatement(nil, condition, scope);
		stat.body = self:block(scope, stat);
		expect(self, TokenKind.Keyword, "end");
		return stat;
	end
	
	-- Repeat Statement
	if(consume(self, TokenKind.Keyword, "repeat")) then
		if self.debugMode then
			logger:debug("Parsing repeat-until loop");
		end
		local repeatScope = Scope:new(scope);
		local stat = Ast.RepeatStatement(nil, nil, scope);
		stat.body = self:block(nil, stat, repeatScope);
		expect(self, TokenKind.Keyword, "until");
		stat.condition = self:expression(repeatScope);
		return stat;
	end
	
	-- Return Statement
	if(consume(self, TokenKind.Keyword, "return")) then
		local args = {};
		if(not is(self, TokenKind.Keyword, "end") and not is(self, TokenKind.Keyword, "elseif") and not is(self, TokenKind.Keyword, "else") and not is(self, TokenKind.Symbol, ";") and not is(self, TokenKind.Eof)) then
			args = self:exprList(scope);
		end
		-- Return true as Second value because return must be the last Statement in a block
		return Ast.ReturnStatement(args), true;
	end
	
	-- If Statement
	if(consume(self, TokenKind.Keyword, "if")) then
		if self.debugMode then
			logger:debug("Parsing if statement");
		end
		local condition = self:expression(scope);
		expect(self, TokenKind.Keyword, "then");
		local body = self:block(scope, currentLoop);
		
		local elseifs = {};
		-- Elseifs
		while(consume(self, TokenKind.Keyword, "elseif")) do
			local condition = self:expression(scope);
			expect(self, TokenKind.Keyword, "then");
			local body = self:block(scope, currentLoop);
			
			table.insert(elseifs, {
				condition = condition,
				body = body,
			});
		end
		
		local elsebody = nil;
		-- Else
		if(consume(self, TokenKind.Keyword, "else")) then
			elsebody = self:block(scope, currentLoop);
		end
		
		expect(self, TokenKind.Keyword, "end");
		
		return Ast.IfStatement(condition, body, elseifs, elsebody);
	end
	
	-- Function Declaration
	if(consume(self, TokenKind.Keyword, "function")) then
		if self.debugMode then
			logger:debug("Parsing function declaration");
		end
		-- TODO: Parse Function Declaration Name
		local obj = self:funcName(scope);
		local baseScope = obj.scope;
		local baseId = obj.id;
		local indices = obj.indices;
		
		local funcScope = Scope:new(scope);
		
		expect(self, TokenKind.Symbol, "(");
		local args = self:functionArgList(funcScope);
		expect(self, TokenKind.Symbol, ")");
		
		if(obj.passSelf) then
			local id = funcScope:addVariable("self", obj.token);
			table.insert(args, 1, Ast.VariableExpression(funcScope, id));
		end

		local body = self:block(nil, false, funcScope);
		expect(self, TokenKind.Keyword, "end");
		
		return Ast.FunctionDeclaration(baseScope, baseId, indices, args, body);
	end
	
	-- Local Function or Variable Declaration
	if(consume(self, TokenKind.Keyword, "local")) then
		-- Local Function Declaration
		if(consume(self, TokenKind.Keyword, "function")) then
			if self.debugMode then
				logger:debug("Parsing local function");
			end
			local ident = expect(self, TokenKind.Ident);
			local name = ident.value;
			
			local id = scope:addVariable(name, ident);
			local funcScope = Scope:new(scope);
			
			expect(self, TokenKind.Symbol, "(");
			local args = self:functionArgList(funcScope);
			expect(self, TokenKind.Symbol, ")");

			local body = self:block(nil, false, funcScope);
			expect(self, TokenKind.Keyword, "end");

			return Ast.LocalFunctionDeclaration(scope, id, args, body);
		end
		
		-- Local Variable Declaration
		local ids = self:nameList(scope);
		local expressions = {};
		if(consume(self, TokenKind.Symbol, "=")) then
			expressions = self:exprList(scope);
		end

		-- Variables can only be reffered to in the next statement, so the id's are enabled after the expressions have been parsed
		self:enableNameList(scope, ids);
		
		-- Removed assignment count warnings (weaker - less strict)
		
		return Ast.LocalVariableDeclaration(scope, ids, expressions);
	end
	
	-- For Statement
	if(consume(self, TokenKind.Keyword, "for")) then
		if self.debugMode then
			logger:debug("Parsing for loop");
		end
		-- Normal for Statement
		if(is(self, TokenKind.Symbol, "=", 1)) then
			local forScope = Scope:new(scope);
			
			local ident = expect(self, TokenKind.Ident);
			local varId = forScope:addDisabledVariable(ident.value, ident);
			
			expect(self, TokenKind.Symbol, "=");
			local initialValue = self:expression(scope);
			
			expect(self, TokenKind.Symbol, ",");
			local finalValue = self:expression(scope);
			local incrementBy = Ast.NumberExpression(1);
			if(consume(self, TokenKind.Symbol, ",")) then
				incrementBy = self:expression(scope);
			end
			
			local stat = Ast.ForStatement(forScope, varId, initialValue, finalValue, incrementBy, nil, scope);
			forScope:enableVariable(varId);
			expect(self, TokenKind.Keyword, "do");
			stat.body = self:block(nil, stat, forScope);
			expect(self, TokenKind.Keyword, "end");
			return stat;
		end
		
		-- For ... in ... statement
		local forScope = Scope:new(scope);
		
		local ids = self:nameList(forScope);
		expect(self, TokenKind.Keyword, "in");
		local expressions = self:exprList(scope);
		-- Enable Ids after Expression Parsing so that code like this works:
		--	local z = {10,20}
		--	for y,z in ipairs(z) do
		--		print(y, z);
		-- 	end
		self:enableNameList(forScope, ids);
		expect(self, TokenKind.Keyword, "do");
		local stat = Ast.ForInStatement(forScope, ids, expressions, nil, scope);
		stat.body = self:block(nil, stat, forScope);
		expect(self, TokenKind.Keyword, "end");
		
		return stat;
	end
	
	local expr = self:primaryExpression(scope);
	-- Variable Assignment or Function Call
	if expr then
		-- Function Call Statement
		if(expr.kind == AstKind.FunctionCallExpression) then
			return Ast.FunctionCallStatement(expr.base, expr.args);
		end
		
		-- Function Call Statement passing self
		if(expr.kind == AstKind.PassSelfFunctionCallExpression) then
			return Ast.PassSelfFunctionCallStatement(expr.base, expr.passSelfFunctionName, expr.args);
		end
		
		-- Variable Assignment
		if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression) then
			if(expr.kind == AstKind.IndexExpression) then
				expr.kind = AstKind.AssignmentIndexing
			end
			if(expr.kind == AstKind.VariableExpression) then
				expr.kind = AstKind.AssignmentVariable
			end

			if(self.luaVersion == LuaVersion.LuaU) then
				-- LuaU Compound Assignment
				if(consume(self, TokenKind.Symbol, "+=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundAddStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "-=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundSubStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "*=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundMulStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "/=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundDivStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "%=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundModStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "^=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundPowStatement(expr, rhs);
				end

				if(consume(self, TokenKind.Symbol, "..=")) then
					local rhs = self:expression(scope);
					return Ast.CompoundConcatStatement(expr, rhs);
				end
			end

			local lhs = {
				expr
			}
			
			while consume(self, TokenKind.Symbol, ",") do
				expr = self:primaryExpression(scope);
				
				if(not expr) then
					if self.disableLog then error() end;
					logger:error(generateError(self, string.format("expected valid assignment lhs but got nil")));
				end
				
				if(expr.kind == AstKind.IndexExpression or expr.kind == AstKind.VariableExpression) then
					if(expr.kind == AstKind.IndexExpression) then
						expr.kind = AstKind.AssignmentIndexing
					end
					if(expr.kind == AstKind.VariableExpression) then
						expr.kind = AstKind.AssignmentVariable
					end
					table.insert(lhs, expr);
				else
					if self.disableLog then error() end;
					logger:error(generateError(self, string.format("expected valid assignment lhs but got <%s>", expr.kind)));
				end
			end
			
			expect(self, TokenKind.Symbol, "=");
			
			local rhs = self:exprList(scope);
			
			return Ast.AssignmentStatement(lhs, rhs);
		end
		
		if self.disableLog then error() end;
		logger:error(generateError(self, "expressions are not valid statements"));
	end
	
	return nil;
end

-- [Remaining expression parsing functions remain largely the same]
-- I'll include key ones with logging additions:

function Parser:primaryExpression(scope)
	local i = self.index;
	local s = self;
	self.disableLog = true;
	local status, val = pcall(self.expressionFunctionCall, self, scope);
	self.disableLog = false;
	if(status) then
		return val;
	else
		self.index = i;
		return nil;
	end
end

-- List of expressions Seperated by a comma
function Parser:exprList(scope)
	local expressions = {
		self:expression(scope)
	};
	while(consume(self, TokenKind.Symbol, ",")) do
		table.insert(expressions, self:expression(scope));
	end
	return expressions;
end

-- list of local variable names
function Parser:nameList(scope)
	local ids = {};
	
	local ident = expect(self, TokenKind.Ident);
	local id = scope:addDisabledVariable(ident.value, ident);
	table.insert(ids, id);
	
	while(consume(self, TokenKind.Symbol, ",")) do
		ident = expect(self, TokenKind.Ident);
		id = scope:addDisabledVariable(ident.value, ident);
		table.insert(ids, id);
	end
	
	return ids;
end

function Parser:enableNameList(scope, list)
	for i, id in ipairs(list) do
		scope:enableVariable(id);
	end
end

-- [Expression parsing methods remain mostly the same]
-- Include the rest of the file with minimal changes...

function Parser:expression(scope)
	return self:expressionOr(scope);
end

function Parser:expressionOr(scope)
	local lhs = self:expressionAnd(scope);
	
	if(consume(self, TokenKind.Keyword, "or")) then
		local rhs = self:expressionOr(scope);
		return Ast.OrExpression(lhs, rhs, true);
	end
	
	return lhs;
end

-- [Continue with remaining expression parsing methods...]

return Parser
