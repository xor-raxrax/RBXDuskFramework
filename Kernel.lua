local shared = shared
local buildclass = shared.buildclass
local kernelSettings = shared.kernelSettings

local ENUMS_MODULE_NAME = "Enums"
local CLASSES_FODLER_NAME = "Classes"
local LIBRARIES_FOLDER_NAME = "Libraries"

local Module = {} do

	function Module:constructor(module : Instance)
		self._Instance = module
		self._IsInitialized = false
		self._ReturnValue = nil
	end

	function Module:GetReturnValue()
		if self._IsInitialized then
			return self._ReturnValue
		end

		local result = require(self._Instance)
		self._ReturnValue = result
		return result
	end

	function Module:GetReturnValueAsClass(name)
		local class = self:GetReturnValue()
		if not class then return end

		if not class.__type then
			buildclass(name, class)
		end

		return class
	end

	buildclass("Module", Module)
end

local errorf = shared.errorf
local expecttype = shared.expecttype

local ModuleCollector = {} do

	function ModuleCollector:constructor(folder, fileTypeName)
		self.RootFolder = folder
		self.Modules = {}
		self.ModulesTypeName = fileTypeName
	end

	ModuleCollector.__attr_virtual__Collect = true
	function ModuleCollector:_Collect()
		for _, file in next, self.RootFolder:GetDescendants() do
			if not file:IsA("ModuleScript") then continue end

			self:_AddModule(file)
		end
	end

	function ModuleCollector:_AddModule(file)
		local name = file.Name
		self:_CheckNameConflict(name, file)
		self.Modules[name] = Module.new(file)
	end

	function ModuleCollector:_CheckNameConflict(name, newFile)
		local existingFile = self.Modules[name]
		if existingFile then
			errorf("cannot register files with the same name '%s', registered: %s,n\new: %s",
				name,
				existingFile._Instance:GetFullName(),
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

	function ModuleCollector:_GetModuleReturnValueAsClass(name, noThrow)
		local module = self:_GetModule(name, noThrow)
		if module then
			return module:GetReturnValueAsClass(name)
		end
	end

	buildclass("ModuleCollector", ModuleCollector)
end

local Package = {} do

	function Package:constructor(manager, rootFolder)
		ModuleCollector.constructor(self, rootFolder, "class")

		self.Name = rootFolder.Name
		self._ModuleToName = {}
		self._PackageManager = manager
		self.Enums = nil
		self._EnumsModule = nil
	end

	function Package:GetClass(name, noThrow)
		return self:_GetModuleReturnValueAsClass(name, noThrow)
	end

	local initializeEnums do
		local invalidIndexHandler = {}
		function invalidIndexHandler:__index(name)
			errorf("Enum '%s' has no '%s' member", self.__Name, tostring(name))
		end

		function initializeEnums(enums)
			for enumName, enum in next, enums do
				local toAdd = {}
				for name, value in next, enum do
					toAdd[value] = name
				end
				for value, name in next, toAdd do
					enum[value] = name
				end
				enum.__Name = enumName
				setmetatable(enum, invalidIndexHandler)
				table.freeze(enum)
			end
		end
	end

	function Package:_RegisterEnums(enumsModule)
		if self._EnumsModule then
			errorf("Duplicate enums in package '%s', registered: %s, new: %s",
				self.Name,
				self._EnumsModule:GetFullName(),
				enumsModule:GetFullName()
			)
		end

		local enums = expecttype(require(enumsModule), "table")
		initializeEnums(enums)

		self.Enums = enums
		self._EnumsModule = enumsModule
	end

	function Package:GetEnum(name)
		if not self.Enums then
			errorf("Package '%s' does not contain enums", self.Name)
		end

		local enum = self.Enums[name]
		if enum then
			return enum
		end
		errorf("'%s' is invalid enum name", name)
	end

	function Package:_Collect(root)
		for _, child in next, root:GetChildren() do
			if child:IsA("ModuleScript") then
				if child.Name == ENUMS_MODULE_NAME then
					self:_RegisterEnums(child)
				else
					self:_AddModule(child)
					self._PackageManager:AssociatedModuleWithPackage(child, self)
				end

				self:_Collect(child)
			elseif child:IsA("Folder") then
				self._PackageManager:BuildPackage(child)
			end
		end
	end

	buildclass("Package", Package, ModuleCollector)
end

local PackageManager = {} do

	function PackageManager:constructor(root)
		self.Packages = {}
		self.Root = root
		self.LocalPackageLookupUseGetfenv = kernelSettings.LocalPackageLookupUseGetfenv
		self.ModuleToPackage = {}

		self.RootPackage = self:BuildPackage(root, "_Root")
	end

	function PackageManager:BuildPackage(folder, name)
		local package = Package.new(self, folder)
		package:_Collect(folder)
		name = name or package.Name
		self.Packages[name] = package
		return package
	end

	function PackageManager:AssociatedModuleWithPackage(module, package)
		self.ModuleToPackage[module] = package
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
			local class = package:GetClass(name, true)
			if class then
				return class
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

		local class = packageOrTrace:GetClass(name, noThrow)
		if class then
			return class
		end
	end

	function PackageManager:GetEnum(name, localClassTraceOffset)
		if self.RootPackage.Enums then
			return self.RootPackage:GetEnum(name)
		end
		return self.RootPackage:GetLocalEnum(name, localClassTraceOffset + 1)
	end

	function PackageManager:GetLocalEnum(name, localClassTraceOffset)
		expecttype(name, "string")
		expecttype(localClassTraceOffset, "number")

		local success, packageOrTrace = self:_GetLocalPackage(localClassTraceOffset + 1)
		if not success then
			errorf("cannot extract package name from trace '%s'", packageOrTrace)
		end

		return packageOrTrace:GetEnum(name)
	end

	local rootFolder = shared.rootFolder
	local rootFolderName = rootFolder.Name
	local rootFolderParentName = rootFolder.Parent.Name

	function PackageManager:_GetLocalPackage_Traceback(localClassTraceOffset)
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

			local isRootFolder = potentialPackageName == rootFolderName
				and names[i - 1] and names[i - 1] == rootFolderParentName

			if isRootFolder then
				return true, self.RootPackage
			end

			local package = self:GetPackage(potentialPackageName, true)
			if package then
				return true, package
			end
		end

		return false, lastLine
	end

	function PackageManager:_GetLocalPackage_Getfenv(localClassTraceOffset)
		while true do
			localClassTraceOffset += 1
			local otherScript = getfenv(localClassTraceOffset).script
			if otherScript == script then break end

			local package = self.ModuleToPackage[otherScript]
			if package then
				return true, package
			end
		end

		return true, self.RootPackage
	end

	function PackageManager:_GetLocalPackage(localClassTraceOffset)
		if self.LocalPackageLookupUseGetfenv then
			return self:_GetLocalPackage_Getfenv(localClassTraceOffset + 1)
		else
			return self:_GetLocalPackage_Traceback(localClassTraceOffset + 1)
		end
	end

	buildclass("PackageManager", PackageManager)
end

local Kernel = {} do

	Kernel.__attr_singleton = true

	function Kernel:constructor()
		local rootFolder = shared.rootFolder
		self._PackageManager = PackageManager.new(rootFolder[CLASSES_FODLER_NAME])
		self._LibrariesCollector = ModuleCollector.new(rootFolder[LIBRARIES_FOLDER_NAME], "library")

		self._LibrariesCollector:_Collect()
	end

	function Kernel:GetPackage(name, noThrow)
		return self._PackageManager:GetPackage(name, if noThrow == nil then false else expecttype(noThrow, "boolean"))
	end

	function Kernel:GetLocalPackage()
		local _, package = self._PackageManager:_GetLocalPackage(1)
		return package
	end

	local expectclasstype = shared.expectclasstype

	function Kernel:GetClass(name)
		return expectclasstype(self._PackageManager:GetClass(name, 1), name)
	end
	
	function Kernel:GetLocalClass(name)
		return expectclasstype(self._PackageManager:GetLocalClass(name, 1), name)
	end

	function Kernel:GetLibrary(name)
		return self._LibrariesCollector:_GetModuleReturnValue(name)
			or self._KLibrariesCollector:Get(name)
	end

	function Kernel:GetEnum(name)
		return self._PackageManager:GetEnum(name, 1)
	end

	function Kernel:GetLocalEnum(name)
		return self._PackageManager:GetLocalEnum(name, 1)
	end

	buildclass("Kernel", Kernel)
end

kernel = Kernel.new()

return kernel