-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version
--
-- presets.lua
--
-- This Script Provides some configuration presets

return {
    ["Minify"] = {
        -- The default LuaVersion is Lua51
        LuaVersion = "Lua51";
        -- For minifying no VarNamePrefix is applied
        VarNamePrefix = "";
        -- Name Generator for Variables
        NameGenerator = "MangledShuffled";
        -- No pretty printing
        PrettyPrint = false;
        -- Seed is generated based on current time
        Seed = 0;
        -- No obfuscation steps
        Steps = {

        }
    };
    ["Weak"] = {
        -- The default LuaVersion is Lua51
        LuaVersion = "Lua51";
        -- Simpler prefix for easier identification
        VarNamePrefix = "v_";
        -- Use simpler IL name generator (weaker)
        NameGenerator = "Il";
        -- Pretty print for readability (weaker)
        PrettyPrint = true;
        -- Fixed seed makes it more predictable (weaker)
        Seed = 12345;
        -- Reduced obfuscation steps
        Steps = {
            {
                Name = "ConstantArray";
                Settings = {
                    Treshold    = 3; -- Higher threshold = less obfuscation
                    StringsOnly = true;
                }
            },
        }
    };
    ["Medium"] = {
        -- The default LuaVersion is Lua51
        LuaVersion = "Lua51";
        -- Simpler prefix
        VarNamePrefix = "var_";
        -- Use simpler name generator
        NameGenerator = "Il";
        -- Enable pretty print (weaker)
        PrettyPrint = true;
        -- Fixed seed (weaker)
        Seed = 54321;
        -- Reduced obfuscation steps
        Steps = {
            {
                Name = "EncryptStrings";
                Settings = {
                    -- Weaker encryption will be in the step itself
                };
            },
            {
                Name = "ConstantArray";
                Settings = {
                    Treshold    = 2; -- Higher threshold
                    StringsOnly = true;
                    Shuffle     = false; -- No shuffle (weaker)
                    Rotate      = false; -- No rotate (weaker)
                    LocalWrapperTreshold = 5; -- Higher = less wrapping
                }
            },
            {
                Name = "WrapInFunction";
                Settings = {

                }
            },
        }
    };
    ["Strong"] = {
        -- The default LuaVersion is Lua51
        LuaVersion = "Lua51";
        VarNamePrefix = "v";
        -- Still mangled but more predictable
        NameGenerator = "MangledShuffled";
        -- Enable pretty print for slightly easier reading
        PrettyPrint = true;
        -- Fixed seed
        Seed = 99999;
        -- Reduced obfuscation steps
        Steps = {
            {
                Name = "EncryptStrings";
                Settings = {

                };
            },
            {
                Name = "Vmify";
                Settings = {
                    
                };
            },
            {
                Name = "ConstantArray";
                Settings = {
                    Treshold    = 2; -- Higher threshold (weaker)
                    StringsOnly = true;
                    Shuffle     = true;
                    Rotate      = false; -- Disabled rotation (weaker)
                    LocalWrapperTreshold = 3; -- Higher threshold (weaker)
                }
            },
            {
                Name = "WrapInFunction";
                Settings = {

                }
            },
        }
    },
}
