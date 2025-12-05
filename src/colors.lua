-- This Script is Part of the Prometheus Obfuscator by kyle
-- Modified to be a weaker version

local keys = {
  reset =      0,
  
  bright     = 1,
  dim        = 2,
  underline  = 4,
  blink      = 5,
  reverse    = 7,
  hidden     = 8,
  
  black     = 30,
  pink      = 91,
  red       = 31,
  green     = 32,
  yellow     = 33,
  blue      = 34,
  magenta   = 35,
  cyan      = 36,
  grey      = 37,
  gray      = 37,
  white     = 97,
  
  blackbg   = 40,
  redbg     = 41,
  greenbg   = 42,
  yellowbg  = 43,
  bluebg    = 44,
  magentabg = 45,
  cyanbg    = 46,
  greybg    = 47,
  graybg    = 47,
  whitebg   = 107,
}
  
local escapeString = string.char(27) .. '[%dm';
local function escapeNumber(number)
  return escapeString:format(number)
end

local settings = {
  -- Disabled by default (weaker - no colored output)
  enabled = false,
}

-- Simplified colors function - just returns plain string
local function colors(str, ...)
  -- Always return plain string regardless of enabled setting (weaker)
  return tostring(str or '')
end
  
return setmetatable(settings, { __call = function(_, ...) return colors(...) end});
