local kernelFolder = script.Parent

local buildclass = shared.buildclass
local buildsingleton = shared.buildsingleton

local kernelVariables = {} do
	local rootFolder = shared.rootFolder
	
	kernelVariables.KernelFolder = kernelFolder
	kernelVariables.KernelLibraries = kernelFolder.Libraries
	kernelVariables.KernelClasses = kernelFolder.Classes
	
	kernelVariables.RootFolder = rootFolder
	kernelVariables.Libraries = rootFolder.Libraries
	kernelVariables.Classes = rootFolder.Classes
	kernelVariables.Enums = rootFolder.Enums
end

local Module = {} do
	
	function Module.new(module : Instance)
		local self = setmetatable({}, Module)
		
		self._Instance = module
		self._IsInitialized = false
		self._ReturnValue = nil
		
		return self
	end
	
	function Module:GetReturnValue()
		if self._IsInitialized then
			return self._ReturnValue
		end
		
		local result = require(self._Instance)
		self._ReturnValue = result
		return result
	end
	
	buildclass("Module", Module)
end

local errorf = shared.errorf
local expecttype = shared.expecttype

local ModuleCollector = {} do
	
	function ModuleCollector.new(folder, fileTypeName)
		local self = setmetatable({}, ModuleCollector)
		
		self.RootFolder = folder
		self.Modules = {}
		self.ModulesTypeName = fileTypeName
		
		return self
	end
	
	function ModuleCollector:_Collect()
		for _, file in next, self.RootFolder:GetDescendants() do
			if not file:IsA("ModuleScript") then continue end
			
			self:_AddModule(file)
		end
	end
	
	function ModuleCollector:_AddModule(file)
		local name = file.Name
		self:_ThrowOnNameConflict(name, file)
		self.Modules[name] = Module.new(file)
	end
	
	function ModuleCollector:_ThrowOnNameConflict(name, newFile)
		local existingFile = self.Modules[name]
		if existingFile then
			errorf("cannot register files with the same name '%s', registered: %s, new: %s",
				name,
				existingFile:GetFullName(),
				newFile:GetFullName()
			)
		end
	end
	
	function ModuleCollector:_GetModule(name, noThrow)
		expecttype(name, "string")
		
		local module = self.Modules[name]
		if module then
			return module
		end
		
		if not noThrow then
			errorf("'%s' is invalid %s name", name, self.ModulesTypeName)
		end
	end
	
	function ModuleCollector:_GetModuleReturnValue(name, noThrow)
		local module = self:_GetModule(name, noThrow)
		if module then
			return module:GetReturnValue()
		end
	end
	
	buildclass("ModuleCollector", ModuleCollector)
end


local Package = {} do
	
	function Package.new(manager, rootFolder)
		local self = setmetatable(ModuleCollector.new(rootFolder, "class"), Package)
		
		self.Name = rootFolder.Name
		self._ModuleToName = {}
		self._PackageManager = manager
		
		return self
	end
	
	function Package:GetClass(name)
		return self:_GetModuleReturnValue(name)
	end
	
	local override = {}
	
	function override:_Collect(root)
		for _, child in next, root:GetChildren() do
			if child:IsA("ModuleScript") then
				self:_AddModule(child)
				self:_Collect(child)
			elseif child:IsA("Folder") then
				self._PackageManager:BuildPackage(child)
			end
		end
	end
	
	shared.buildclassoverride("Package", Package, override, ModuleCollector)
end

local PackageManager = {} do
	
	function PackageManager.new(root)
		local self = setmetatable({}, PackageManager)
		
		self.Packages = {}
		self.Root = root
		self.RootPackage = self:BuildPackage(root, "_Root")
		
		return self
	end
	
	function PackageManager:BuildPackage(folder, name)
		local package = Package.new(self, folder)
		package:_Collect(folder)
		name = name or package.Name
		self.Packages[name] = package
		return package
	end
	
	function PackageManager:GetPackage(name, noThrow)
		local package = self.Packages[name]
		if package then
			return package
		end
		
		if not noThrow then
			errorf("'%s' is invalid package name", name)
		end
	end
	
	function PackageManager:GetClass(name, localClassTraceOffset)
		local localClass = self:GetLocalClass(name, localClassTraceOffset + 1, true)
		if localClass then
			return localClass
		end
		
		for _, package in next, self.Packages do
			local module = package:_GetModule(name, true)
			if module then
				return module:GetReturnValue()
			end
		end
		
		errorf("'%s' is invalid class name", name)
	end
	
	function PackageManager:GetLocalClass(name, localClassTraceOffset, noThrow)
		expecttype(name, "string")
		expecttype(localClassTraceOffset, "number")
		
		local success, packageOrTrace = self:_GetLocalPackage(localClassTraceOffset)
		if not success then
			if not noThrow then
				errorf("cannot extract package name from trace '%s'", packageOrTrace)
			end
			return
		end
		
		local module = packageOrTrace:_GetModule(name, noThrow)

		if module then
			return module:GetReturnValue()
		end
	end
	
	function PackageManager:_GetLocalPackage(localClassTraceOffset)
		local trace = debug.traceback("", 2 + localClassTraceOffset)
		
		local lastLine = string.match(trace, "[^\n]+%s*$")
		lastLine = string.gsub(lastLine, "\n", "")
		
		local names = {}
		for substring in string.gmatch(lastLine, "[^.]+") do
			table.insert(names, substring)
		end
		
		-- last line is running class
		table.remove(names)

		for i = #names, 1, -1 do
			local potentialPackageName = names[i]
			
			-- special case for root package since it does not have associated folder
			if potentialPackageName == kernelVariables.Classes.Name
				and names[i - 1]
				and names[i - 1] == kernelVariables.RootFolder.Name then
				
				return true, self.RootPackage
			end
			
			local package = self:GetPackage(potentialPackageName, true)
			if package then
				return true, package
			end
		end
		
		return false, lastLine
	end
	
	buildclass("PackageManager", PackageManager)
end

local kernelSettings = assert(shared.kernelSettings)

local KernelObject = {}
buildclass("KernelObject", KernelObject)

local kernelAuditor do
	
	local KernelAuditor = {} do
		
		function KernelAuditor.new()
			local self = setmetatable({}, KernelAuditor)
			
			return self
		end
		
		function KernelAuditor:Log(content)
			if kernelSettings.PrintKernelLog then
				print(content)
			end
		end
		
		function KernelAuditor:Warn(content)
			if kernelSettings.PrintKernelWarnings then
				warn(content)
			end
		end
		
		buildsingleton("KernelAuditor", KernelAuditor, KernelObject)
	end
	
	kernelAuditor = KernelAuditor.new()
end

local Kernel = {} do
	
	function Kernel.new()
		local self = setmetatable({}, Kernel)
		
		self._LibrariesCollector = ModuleCollector.new(kernelVariables.Libraries, "library")
		self._KLibrariesCollector = ModuleCollector.new(kernelVariables.KernelLibraries, "library")
		self._KClassCollector = ModuleCollector.new(kernelVariables.KernelClasses, "class")
		
		self._PackageManager = PackageManager.new(kernelVariables.Classes)
		
		self._LibrariesCollector:_Collect()
		self._KLibrariesCollector:_Collect()
		self._KClassCollector:_Collect()
		
		local enums = require(kernelVariables.Enums)
		
		local invalidIndexHandler = {}
		function invalidIndexHandler:__index(name)
			errorf("Enum '%s' has no '%s' member", self.__Name, name)
		end
		
		for enumName, enum in next, enums do
			for name, value in next, enum do
				enum[value] = name
			end
			enum.__Name = enumName
			setmetatable(enum, invalidIndexHandler)
			table.freeze(enum)
		end
		
		self._Enums = enums
		
		return self
	end
	
	local function toMessage(...)
		local message = ""
		
		local size = select("#", ...)
		for i = 1, size do
			message ..= tostring(select(i, ...))
			if i < size then
				message ..= " "
			end
		end
		
		return message
	end
	
	function Kernel:Log(...)
		kernelAuditor:Log(toMessage(...))
	end
	
	function Kernel:Warn(...)
		kernelAuditor:Warn(toMessage(...))
	end
	
	function Kernel:GetLibrary(name)
		return self._LibrariesCollector:_GetModuleReturnValue(name)
			or self._KLibrariesCollector:Get(name)
	end
	
	function Kernel:GetKernelLibrary(name)
		return self._KLibrariesCollector:_GetModuleReturnValue(name)
	end
	
	local expectclasstype = shared.expectclasstype
	
	function Kernel:GetClass(name)
		return expectclasstype(
			self._PackageManager:GetClass(name, 1) or self._KClassCollector:_GetModuleReturnValue(name),
			name
		)
	end
	
	-- uses debug.traceback() instead of getfenv() to prevent disabling Table::safeenv
	function Kernel:GetLocalClass(name)
		return expectclasstype(self._PackageManager:GetLocalClass(name, 1), name)
	end
	
	function Kernel:GetPackage(name, noThrow)
		return self._PackageManager:GetPackage(name, if noThrow == nil then false else noThrow)
	end
	
	function Kernel:GetKernelClass(name)
		return expectclasstype(self._KClassCollector:_GetModuleReturnValue(name), name)
	end
	
	function Kernel:GetEnum(name)
		local enum = self._Enums[name]
		if enum then
			return enum
		end
		errorf("'%s' is invalid enum name", name)
	end
	
	buildsingleton("Kernel", Kernel, KernelObject)
end


kernel = Kernel.new()

kernel:Log("kernel loaded")

return kernel