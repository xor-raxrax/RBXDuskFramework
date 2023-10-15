local shared = shared

shared.kernelSettings = {
	PrintKernelLog = false,
	PrintKernelWarnings = true,
	
	DebugMode = {
		Enabled = false,
		
		AddTostringMetamethod = true,
		
		LogCalls = false,
		IgnoreSpecialMethodCallLog = true,
		SpecialMethodNames = {},
	},
	
	GenerateDefaultDestructor = true,
	AlwaysInheritDuskObject = true,
	
	WarnExplicitDuskObjectInheritance = true,
	WarnImplicitDuskObjectInheritance = false,
	
	LogClassBuildingProcess = false,
	
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

-- predefinition
shared.DuskObject = {}

local baseLibrary do
	baseLibrary = require(kernelFolder.BaseLibrary)
	
	shared.baseLibrary = baseLibrary
	
	for k, v in next, baseLibrary do
		shared[k] = v
	end
end

require(kernelFolder.DuskObject)
shared.kernel = require(kernelFolder.Kernel)

-- intended only for use by main framework components and kernel
shared.kernelSettings = nil
shared.rootFolder = nil

require(rootFodler.Main)

return nil