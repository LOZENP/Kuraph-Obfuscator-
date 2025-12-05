-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- config.lua
--
-- In this Script, some Global config Variables are defined

local NAME    = "Prometheus";
local REVISION = "Weak";  -- Changed to indicate weaker version
local VERSION = "v0.2-weak";  -- Modified version string

for _, currArg in pairs(arg) do
	if currArg == "--CI" then
		local releaseName = string.gsub(string.format("%s %s %s", NAME, REVISION, VERSION), "%s", "-")
		print(releaseName)
	end
	
	if currArg == "--FullVersion" then
		print(VERSION)
	end
end

-- Config Starts here
return {
	Name = NAME,
	NameUpper = string.upper(NAME),
	NameAndVersion = string.format("%s %s", NAME, VERSION),
	Version = VERSION;
	Revision = REVISION;
	-- Config Starts Here
	
	-- Changed to more obvious prefix (weaker - easier to identify obfuscated vars)
	IdentPrefix = "obf_",
	
	-- Use more whitespace for readability (weaker)
	SPACE = " ",
	TAB   = "    ", -- 4 spaces instead of tab for consistency and readability
}
