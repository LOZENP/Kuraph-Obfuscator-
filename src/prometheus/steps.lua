-- This Script is Part of the Prometheus Obfuscator by Levno_710
-- Modified to be a weaker version
--
-- steps/init.lua
-- This module exports all available obfuscation steps

return {
	WrapInFunction       = require("prometheus.steps.WrapInFunction");
	SplitStrings         = require("prometheus.steps.SplitStrings");
	Vmify                = require("prometheus.steps.Vmify");
	ConstantArray        = require("prometheus.steps.ConstantArray");
	ProxifyLocals        = require("prometheus.steps.ProxifyLocals");
	-- Removed AntiTamper (weaker - no tamper detection)
	-- AntiTamper         = require("prometheus.steps.AntiTamper");
	EncryptStrings       = require("prometheus.steps.EncryptStrings");
	NumbersToExpressions = require("prometheus.steps.NumbersToExpressions");
	AddVararg            = require("prometheus.steps.AddVararg");
	-- Removed WatermarkCheck (weaker - no watermark verification)
	-- WatermarkCheck     = require("prometheus.steps.WatermarkCheck");
}
