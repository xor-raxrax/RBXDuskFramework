local shared = shared

shared.kernelSettings = {
	DebugMode = {
		Enabled = false,

		AddTostringMetamethod = true,

		LogCalls = false,
		IgnoreSpecialMethodCallLog = true,
		SpecialMethodNames = {},
	},

	LocalPackageLookupUseGetfenv = false,

	GenerateDefaultDestructor = true,
	AlwaysInheritDuskObject = true,

	LogClassBuildingProcess = false,

	WarnOverrideOnMissingOverrideAttribute = true,

	PureVirtualMethodCallError = false,

	ClassInstanceCleanupInformer = {
		Enabled = true,
		UseError = false,
		InformAliveThread = false,
		InformAliveRBXScriptConnection = false,
		InformRBXInstance = false,
	},
}

local rootFodler = script
local kernelFolder = rootFodler.Dusk

shared.rootFolder = rootFodler

local baseLibrary do
	baseLibrary = require(kernelFolder.BaseLibrary)

	shared.baseLibrary = baseLibrary

	for k, v in next, baseLibrary do
		shared[k] = v
	end
end

shared.kernel = require(kernelFolder.Kernel)

-- intended only for use by main framework components and kernel
shared.kernelSettings = nil
shared.rootFolder = nil

require(rootFodler.Main)

return nil