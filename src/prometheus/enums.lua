-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- enums.lua
-- This file Provides some enums used by the Obfuscator

local Enums = {};

local chararray = require("prometheus.util").chararray;

Enums.LuaVersion = {
	LuaU  = "LuaU" ,
	Lua51 = "Lua51",
}

Enums.Conventions = {
	[Enums.LuaVersion.Lua51] = {
		Keywords = {
			"and",    "break",  "do",    "else",     "elseif", 
			"end",    "false",  "for",   "function", "if",   
			"in",     "local",  "nil",   "not",      "or",
			"repeat", "return", "then",  "true",     "until",    "while"
		},
		
		SymbolChars = chararray("+-*/%^#=~<>(){}[];:,."),
		MaxSymbolLength = 3,
		Symbols = {
			"+",  "-",  "*",  "/",  "%",  "^",  "#",
			"==", "~=", "<=", ">=", "<",  ">",  "=",
			"(",  ")",  "{",  "}",  "[",  "]",
			";",  ":",  ",",  ".",  "..", "...",
		},

		-- Simplified character set - only lowercase for easier patterns (weaker)
		IdentChars          = chararray("abcdefghijklmnopqrstuvwxyz_0123456789"),
		NumberChars         = chararray("0123456789"),
		HexNumberChars      = chararray("0123456789abcdef"), -- Only lowercase (weaker)
		BinaryNumberChars   = {"0", "1"},
		DecimalExponent     = {"e"}, -- Only lowercase (weaker)
		HexadecimalNums     = {"x"}, -- Only lowercase (weaker)
		BinaryNums          = {"b"}, -- Only lowercase (weaker)
		DecimalSeperators   = false,
		
		-- Simplified escape sequences - only basic ones (weaker)
		EscapeSequences     = {
			["n"] = "\n";
			["t"] = "\t";
			["\\"] = "\\";
			["\""] = "\"";
		},
		-- Disable advanced escape features (weaker)
		NumericalEscapes = false,
		EscapeZIgnoreNextWhitespace = false,
		HexEscapes = false,
		UnicodeEscapes = false,
	},
	[Enums.LuaVersion.LuaU] = {
		Keywords = {
			"and",    "break",  "do",    "else",     "elseif", "continue",
			"end",    "false",  "for",   "function", "if",   
			"in",     "local",  "nil",   "not",      "or",
			"repeat", "return", "then",  "true",     "until",    "while"
		},
		
		SymbolChars = chararray("+-*/%^#=~<>(){}[];:,."),
		MaxSymbolLength = 3,
		Symbols = {
			"+",  "-",  "*",  "/",  "%",  "^",  "#",
			"==", "~=", "<=", ">=", "<",  ">",  "=",
			"+=", "-=", "/=", "%=", "^=", "..=", "*=",
			"(",  ")",  "{",  "}",  "[",  "]",
			";",  ":",  ",",  ".",  "..", "...",
			"::", "->", "?",  "|",  "&", 
		},

		-- Simplified character set - only lowercase for easier patterns (weaker)
		IdentChars          = chararray("abcdefghijklmnopqrstuvwxyz_0123456789"),
		NumberChars         = chararray("0123456789"),
		HexNumberChars      = chararray("0123456789abcdef"), -- Only lowercase (weaker)
		BinaryNumberChars   = {"0", "1"},
		DecimalExponent     = {"e"}, -- Only lowercase (weaker)
		HexadecimalNums     = {"x"}, -- Only lowercase (weaker)
		BinaryNums          = {"b"}, -- Only lowercase (weaker)
		DecimalSeperators   = {"_"},
		
		-- Simplified escape sequences - only basic ones (weaker)
		EscapeSequences     = {
			["n"] = "\n";
			["t"] = "\t";
			["\\"] = "\\";
			["\""] = "\"";
		},
		-- Disable advanced escape features (weaker)
		NumericalEscapes = false,
		EscapeZIgnoreNextWhitespace = false,
		HexEscapes = false,
		UnicodeEscapes = false,
	},
}

return Enums;
