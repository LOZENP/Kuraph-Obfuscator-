-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- This Script provides a simple Method for Syntax Highlighting of Lua code

local Tokenizer = require("prometheus.tokenizer");
local colors    = require("colors");
local TokenKind = Tokenizer.TokenKind;
local lookupify = require("prometheus.util").lookupify;

return function(code, luaVersion)
    -- Simplified: just return plain text without highlighting (weaker)
    -- This makes output easier to copy/analyze
    
    local tokenizer = Tokenizer:new({
        LuaVersion = luaVersion,
    });

    tokenizer:append(code);
    local tokens = tokenizer:scanAll();

    -- Still tokenize but skip all coloring
    local out = "";
    local currentPos = 1;
    
    for _, token in ipairs(tokens) do
        if token.startPos >= currentPos then
            out = out .. string.sub(code, currentPos, token.startPos);
        end
        -- Simply append token source without any coloring
        out = out .. token.source;
        currentPos = token.endPos + 1;
    end
    
    return out;
end
