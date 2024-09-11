local kernelSettings = {
	
	AlwaysInheritDuskObject = true,

	LogClassBuildingProcess = false,

	PureVirtualMethodCallError = true,
	SelfArgumentValidationInConstructors = true,

	-- works when inherited from DuskObject
	ClassInstanceCleanup = {
		Enabled = true,
		ClearAndBlock = true,
		
		InformUseError = false,
		InformAliveThread = false,
		InformAliveRBXScriptConnection = false,
		InformRBXInstance = false,
	},

	DebugMode = {
		Enabled = false,

		AddTostringMetamethod = true,

		LogCalls = false,
		IgnoreSpecialMethodCallLog = true,
		SpecialMethodNames = {},
	},
}

return kernelSettings