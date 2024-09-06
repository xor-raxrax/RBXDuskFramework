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

	WarnOverrideOnMissingOverrideAttribute = true,

	PureVirtualMethodCallError = false,
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