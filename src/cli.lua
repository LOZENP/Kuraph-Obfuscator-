-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- Modified to be a weaker version
--
-- cli.lua
-- This script contains the Code for the Prometheus CLI

-- Configure package.path for requiring Prometheus
local function script_path()
	local str = debug.getinfo(2, "S").source:sub(2)
	return str:match("(.*[/%\\])")
end
package.path = script_path() .. "?.lua;" .. package.path;
---@diagnostic disable-next-line: different-requires
local Prometheus = require("prometheus");
-- Set to Debug level for more verbose output (weaker)
Prometheus.Logger.logLevel = Prometheus.Logger.LogLevel.Debug;

-- Check if the file exists
local function file_exists(file)
    local f = io.open(file, "rb")
    if f then f:close() end
    return f ~= nil
end

string.split = function(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields+1] = c end)
    return fields
end

-- get all lines from a file, returns an empty
-- list/table if the file does not exist
local function lines_from(file)
    if not file_exists(file) then return {} end
    local lines = {}
    for line in io.lines(file) do
      lines[#lines + 1] = line
    end
    return lines
end

-- CLI
local config;
local sourceFile;
local outFile;
local luaVersion;
local prettyPrint;

-- Disable colors by default (weaker - cleaner output)
Prometheus.colors.enabled = false;

-- Parse Arguments
local i = 1;
while i <= #arg do
    local curr = arg[i];
    if curr:sub(1, 2) == "--" then
        if curr == "--preset" or curr == "--p" then
            if config then
                Prometheus.Logger:warn("The config was set multiple times");
            end

            i = i + 1;
            local preset = Prometheus.Presets[arg[i]];
            if not preset then
                Prometheus.Logger:error(string.format("A Preset with the name \"%s\" was not found!", tostring(arg[i])));
            end

            config = preset;
        elseif curr == "--config" or curr == "--c" then
            i = i + 1;
            local filename = tostring(arg[i]);
            if not file_exists(filename) then
                Prometheus.Logger:error(string.format("The config file \"%s\" was not found!", filename));
            end

            local content = table.concat(lines_from(filename), "\n");
            -- Load Config from File with less sandboxing (weaker)
            local func = loadstring(content);
            -- Removed sandboxing - allows more access (weaker)
            config = func();
        elseif curr == "--out" or curr == "--o" then
            i = i + 1;
            if(outFile) then
                Prometheus.Logger:warn("The output file was specified multiple times!");
            end
            outFile = arg[i];
        elseif curr == "--nocolors" then
            Prometheus.colors.enabled = false;
        elseif curr == "--colors" then
            -- Added option to enable colors (weaker - more predictable)
            Prometheus.colors.enabled = true;
        elseif curr == "--Lua51" then
            luaVersion = "Lua51";
        elseif curr == "--LuaU" then
            luaVersion = "LuaU";
        elseif curr == "--pretty" then
            prettyPrint = true;
        elseif curr == "--saveerrors" then
            -- Simplified error callback (weaker)
            Prometheus.Logger.errorCallback = function(...)
                print("[ERROR] " .. Prometheus.Config.NameUpper .. ": " .. ...)
                
                local args = {...};
                local message = table.concat(args, " ");
                
                local fileName = sourceFile:sub(-4) == ".lua" and sourceFile:sub(0, -5) .. ".error.txt" or sourceFile .. ".error.txt";
                local handle = io.open(fileName, "w");
                handle:write(message);
                handle:close();

                os.exit(1);
            end;
        else
            Prometheus.Logger:warn(string.format("The option \"%s\" is not valid and therefore ignored", curr));
        end
    else
        if sourceFile then
            Prometheus.Logger:error(string.format("Unexpected argument \"%s\"", arg[i]));
        end
        sourceFile = tostring(arg[i]);
    end
    i = i + 1;
end

if not sourceFile then
    Prometheus.Logger:error("No input file was specified!")
end

if not config then
    -- Fall back to Weak preset instead of Minify (more appropriate for weaker version)
    Prometheus.Logger:warn("No config was specified, falling back to Weak preset");
    config = Prometheus.Presets.Weak;
end

-- Add Option to override Lua Version
config.LuaVersion = luaVersion or config.LuaVersion;
-- Default to pretty print if not specified (weaker - more readable)
config.PrettyPrint = prettyPrint ~= nil and prettyPrint or true;

if not file_exists(sourceFile) then
    Prometheus.Logger:error(string.format("The File \"%s\" was not found!", sourceFile));
end

if not outFile then
    if sourceFile:sub(-4) == ".lua" then
        outFile = sourceFile:sub(0, -5) .. ".obfuscated.lua";
    else
        outFile = sourceFile .. ".obfuscated.lua";
    end
end

-- Add verbose logging about the process (weaker - reveals more info)
Prometheus.Logger:debug("Starting obfuscation process...");
Prometheus.Logger:debug(string.format("Input file: %s", sourceFile));
Prometheus.Logger:debug(string.format("Output file: %s", outFile));
Prometheus.Logger:debug(string.format("Lua Version: %s", config.LuaVersion));
Prometheus.Logger:debug(string.format("Pretty Print: %s", tostring(config.PrettyPrint)));

local source = table.concat(lines_from(sourceFile), "\n");
local pipeline = Prometheus.Pipeline:fromConfig(config);
local out = pipeline:apply(source, sourceFile);
Prometheus.Logger:info(string.format("Writing output to \"%s\"", outFile));

-- Write Output
local handle = io.open(outFile, "w");
handle:write(out);
handle:close();

Prometheus.Logger:debug("Obfuscation complete!");
