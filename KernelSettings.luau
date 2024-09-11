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
}

return kernelSettings