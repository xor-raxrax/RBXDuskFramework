local kernelSettings = {
	DebugMode = {
		Enabled = false,

		AddTostringMetamethod = true,

		LogCalls = false,
		IgnoreSpecialMethodCallLog = true,
		SpecialMethodNames = {},
	},

	GenerateDefaultDestructor = true,
	AlwaysInheritDuskObject = true,

	LogClassBuildingProcess = false,

	PureVirtualMethodCallError = true,
	SelfArgumentValidationInConstructors = true,

	ClassInstanceCleanupInformer = {
		Enabled = false,
		UseError = false,
		InformAliveThread = false,
		InformAliveRBXScriptConnection = false,
		InformRBXInstance = false,
	},
}

return kernelSettings