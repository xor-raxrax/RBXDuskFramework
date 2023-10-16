local DuskObject = shared.DuskObject do
	
	function DuskObject:IsA(classOrName)
		if type(classOrName) == "string" then
			return self.__type == classOrName
		end
		
		return self.__index == classOrName
	end
	
	local function recursiveBaseTableClassSearch(t, name)
		for _, class in next, t do
			if class.__type == name then
				return class
			else
				local foundClass = recursiveBaseTableClassSearch(class.__base, name)
				if foundClass then
					return foundClass
				end
			end
		end
	end
	
	local expectclass = shared.expectclass
	local pureVirtualMethodCallError = shared.kernelSettings.PureVirtualMethodCallError
	function DuskObject:PureVirtualMethodError(name)
		name = name or debug.info(2, "ns")
		
		local message = string.format("attempt to call pure virtual method %s:%s()", self.__type, name)
		if pureVirtualMethodCallError then
			error(message)
		else
			warn(debug.traceback(message))
		end
	end
	
	function DuskObject.IsDerivedOf(what, class)
		local vtype = type(class)
		
		if vtype == "string" then
			return not not recursiveBaseTableClassSearch(what.__base, class)
		end
		
		expectclass(class)
		
		return not not recursiveBaseTableClassSearch(what.__base, class.__type)
	end
	
	function DuskObject.IsDerivedOfOrSameClass(what, class)
		expectclass(class)
		
		return what.__index == class.__index
			or DuskObject.IsDerivedOf(what, class)
	end
	
	local kernelSettings = shared.kernelSettings
	
	if kernelSettings.ClassInstanceCleanupInformer.Enabled then

		local useError = kernelSettings.ClassInstanceCleanupInformer.UseError

		local informAliveThread = kernelSettings.InformAliveThread
		local informAliveRBXScriptConnection = kernelSettings.InformAliveRBXScriptConnection
		local informRBXInstance = kernelSettings.InformRBXInstance
		
		local function inform(fieldSymbol, value, message)
			local formatted = string.format("%s = %s (%s)", tostring(fieldSymbol), tostring(value), message)
			if useError then
				error(formatted, 4)
			else
				warn(debug.traceback(formatted, 4))
			end
		end
		
		local function validate(name, value)
			local vtype = typeof(value)
			
			if vtype == "thread" and informAliveThread then
				if coroutine.status(value) ~= "dead" then
					inform(name, value, "alive thread; possible dangling thread")
				end
				
			elseif vtype == "RBXScriptConnection" and informAliveRBXScriptConnection then
				if not value.Connected then
					inform(name, value, "alive RBXScriptConnection; possible dangling connection")
				end
				
			elseif vtype == "Instance" and informRBXInstance then
				inform(name, value, "Intance reference; possible dangling Instance; non-gced reference from lua or any alive RBXScriptConnection associated with this instance will prevent RBXIntance cleanup (only Instance:Destroy() disconnects all alive RBXScriptConnections)")
				
			end
		end
		
		function DuskObject:Destroy()
			local classType = self.__type .. "."
			for field, item in next, self do
				validate(classType .. "<field>", field)
				validate(classType .. field, item)
			end
		end
		
	end
	
	shared.buildclass("DuskObject", DuskObject)
end

return DuskObject