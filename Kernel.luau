local baseLibrary = require(script.Parent.BaseLibrary)
local kernelSettings = require(script.Parent.KernelSettings)

local buildclass = baseLibrary.buildclass
local errorf = baseLibrary.errorf
local assertf = baseLibrary.assertf
local expecttype = baseLibrary.expecttype
local expectrbxtype = baseLibrary.expectrbxtype

local ENUMS_MODULE_NAME = "Enums"

local IMPLEMENTATION_MODULE_EXTENSION = "impl"

local function createFullName(namePrefix : string, name : string)
	expecttype(namePrefix, "string")
	expecttype(name, "string")

	if namePrefix == "" then
		return name
	end

	return namePrefix .. '.' .. name
end

local Module = {} do

	function Module:constructor(module : ModuleScript)
		self.Name = module.Name
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
		self._IsInitialized = true
		return result
	end

	buildclass("Module", Module)
end

local ModuleCollector = {} do

	function ModuleCollector:constructor()
		self.CollectedModules = {}
	end

	ModuleCollector.__attr_purevirtual_Collect = true
	function ModuleCollector:Collect(root : Instance)

	end

	function ModuleCollector:AddModule(name : string, module)
		local existing = self.CollectedModules[name]
		if existing then
			errorf("cannot register files with the same name '%s':\nregistered: %s,n\new: %s",
				name,
				existing._Instance:GetFullName(),
				module:GetFullName()
			)
		end

		self.CollectedModules[name] = module
	end

	buildclass("ModuleCollector", ModuleCollector)
end

local LibraryCollector = {} do

	LibraryCollector.__base = { ModuleCollector }

	function LibraryCollector:constructor()
		ModuleCollector.constructor(self)
	end

	function LibraryCollector:Collect(rootFolder : Instance)
		for _, file in next, rootFolder:GetDescendants() do
			if not file:IsA("ModuleScript") then continue end

			self:AddModule(file.Name, Module.new(file))
		end
	end

	function LibraryCollector:GetLibrary(name : string)
		local module = self.CollectedModules[name]
		if not module then
			errorf("'%s' is invalid library name", name)
		end
		return module
	end

	buildclass("LibraryCollector", LibraryCollector)
end

local ClassModule = {} do

	ClassModule.__base = { Module }

	function ClassModule:constructor(module : ModuleScript, fullName : string)
		Module.constructor(self, module)
		expecttype(fullName, "string")
		self.FullName = fullName
	end

	function ClassModule:GetReturnValueAsClass()
		local class = self:GetReturnValue()
		if not class then return end

		if not class.__type then
			buildclass(self.Name, class)
		end

		return class
	end

	buildclass("ClassModule", ClassModule)
end

local Package = {} do

	Package.__base = { ModuleCollector }

	function Package:constructor(packageManager, folder, name, prefixName)
		local fullName = createFullName(prefixName, name)
		ModuleCollector.constructor(self)

		self.Name = name
		self.FullName = fullName
		self.Folder = folder
		self.Enums = nil

		self._PackageManager = packageManager
		self._EnumsModule = nil
		self._ModuleNameToImplementation = {}
		self._Packages = {}
	end

	function Package:GetClass(name)
		local module = self.CollectedModules[name]
		if not module then
			errorf("'%s' is invalid class name", name)
		end
		return module:GetReturnValueAsClass()
	end

	function Package:GetEnum(name)
		if not self.Enums then
			errorf("Package '%s' does not contain enums", self.Name)
		end

		local enum = self.Enums[name]
		if not enum then
			errorf("'%s' is invalid enum name", name)
		end

		return enum
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

	function Package:RegisterEnums(enumsModule)
		if self._EnumsModule then
			errorf("Duplicate enums in package '%s', registered: %s, new: %s",
				self.Name,
				self._EnumsModule:GetFullName(),
				enumsModule:GetFullName()
			)
		end

		local enums = expecttype(require(enumsModule), "table")
		initializeEnums(enums)
		self._PackageManager:RegisterEnumModule(self.FullName, enums)

		self.Enums = enums
		self._EnumsModule = enumsModule
	end

	function Package:RegisterClass(child)
		local fileName = child.Name
		local moduleName, extension = string.match(fileName, "(.+)%.([^%.]+)$")

		if extension == IMPLEMENTATION_MODULE_EXTENSION then
			self._ModuleNameToImplementation[moduleName] = child
		else
			local fullName = createFullName(self.FullName, fileName)
			local module = ClassModule.new(child, fullName)
			self:AddModule(fileName, module)
			self._PackageManager:RegisterClass(fullName, module)
		end
	end

	function Package:RegisterSubPackage(package)
		if self._Packages[package.Name] then
			errorf("Duplicate package '%s' in '%s', at '%s'",
				package.Name,
				self.Name,
				package.Folder:GetFullName()
			)
		end

		self._Packages[package.Name] = package
	end

	function Package:Collect(root)
		for _, child in next, root:GetChildren() do
			if child:IsA("Folder") then
				local package = self._PackageManager:BuildPackage(child, child.Name, self.FullName)
				package:Collect(child)
				self:RegisterSubPackage(package)
				continue
			end

			if child:IsA("ModuleScript") then

				local fileName = child.Name

				if child.Name == ENUMS_MODULE_NAME then
					self:RegisterEnums(child)
				else
					self:RegisterClass(child)
				end

				self:Collect(child)
			end

		end
	end

	buildclass("Package", Package)
end

local findSimilarFields do
	
	local THRESHOLD = 2
	local PRIMARY_RESULTS_SIZE = 5
	
	local function longestCommonSubstring(a: string, b: string)
		local maxLength = 0
		local endPos = 0
		local commonSubstringMatrix = table.create(#a)

		-- Initialize the matrix
		for i = 0, #a do
			commonSubstringMatrix[i] = {}
		end

		-- Populate the matrix and track the longest common substring
		for i = 1, #a do
			for j = 1, #b do
				if string.sub(a, i, i) == string.sub(b, j, j) then
					commonSubstringMatrix[i][j] = (commonSubstringMatrix[i - 1] and commonSubstringMatrix[i - 1][j - 1] or 0) + 1
					if commonSubstringMatrix[i][j] > maxLength then
						maxLength = commonSubstringMatrix[i][j]
						endPos = i
					end
				else
					commonSubstringMatrix[i][j] = 0
				end
			end
		end

		return string.sub(a, endPos - maxLength + 1, endPos), maxLength
	end

	function findSimilarFields(fullName: string, tableWithFieldsToFind: { [string]: any })
		local candidates = {}

		for className in next, tableWithFieldsToFind do
			local commonSubstring, length = longestCommonSubstring(fullName, className)
			if length > 0 then
				table.insert(candidates, {
					name = className,
					substring = commonSubstring,
					length = length
				})
			end
		end

		table.sort(candidates, function(a, b)
			return a.length > b.length
		end)

		local primary = {}
		local secondary = {}
		for index, candidate in next, candidates do
			if candidate.length >= THRESHOLD then
				if #primary < PRIMARY_RESULTS_SIZE then
					table.insert(primary, candidate.name)
				end
			end
		end

		return primary, secondary
	end
	
end

local PackageManager = {} do

	function PackageManager:constructor(classesFolders, mainScript)
		self.Packages = {}
		self.Classes = {}
		self.Enums = {}
		
		local rootFolderNames = {}
		for _, folder in next, classesFolders do
			rootFolderNames[folder.Name] = 1
		end
		
		self.RootFolderNames = rootFolderNames
		self.MainScriptName = mainScript.Name
		self.RootPackage = nil
	end

	function PackageManager:RegisterClass(fullName : string, module)
		self.Classes[fullName] = module
	end

	function PackageManager:RegisterEnumModule(packageName : string, enumModule)
		for enumName, enum in next, enumModule do
			self.Enums[createFullName(packageName, enumName)] = enum
		end
	end
	
	-- ".class" aka "relative path" syntax support
	function PackageManager:PathToFullName(path : string, localClassTraceOffset)
		if string.sub(path, 1, 1) ~= '.' then
			return path
		end
		
		local package = self:_GetLocalPackage(localClassTraceOffset + 1)
		if package == self.RootPackage then
			-- cannot have dot as first symbol in root
			return string.sub(path, 2, -1)
		end
		
		return package.FullName .. path
	end
	
	function PackageManager:GetClass(path : string, localClassTraceOffset)
		local fullName = self:PathToFullName(path, localClassTraceOffset + 1)
		
		local classModule = self.Classes[fullName]
		if not classModule then
			local suggestions = findSimilarFields(fullName, self.Classes)
			if #suggestions > 0 then
				errorf("'%s' is invalid class module full name. Did you mean one of these?\n%s", 
					fullName, table.concat(suggestions, ",\n"))
			else
				errorf("'%s' is invalid class module full name", fullName)
			end
		end
		return classModule:GetReturnValueAsClass()
	end

	function PackageManager:GetEnum(path : string, localClassTraceOffset)
		local fullName = self:PathToFullName(path, localClassTraceOffset + 1)
		
		local enums = self.Enums[fullName]
		if not enums then
			local suggestions = findSimilarFields(fullName, self.Enums)
			if #suggestions > 0 then
				errorf("'%s' is invalid enums full name. Did you mean one of these?\n%s", 
					fullName, table.concat(suggestions, ",\n"))
			else
				errorf("'%s' is invalid enums full name", fullName)
			end
		end
		return enums
	end

	function PackageManager:BuildPackage(folder, name, prefixName)
		expectrbxtype(folder, "Instance")
		expecttype(name, "string")
		expecttype(prefixName, "string")
		local package = Package.new(self, folder, name, prefixName)
		self.Packages[name] = package
		return package
	end
	
	function PackageManager:BuildRootPackage(folder)
		local root = self:BuildPackage(folder, "", "")
		self.RootPackage = root
		return root
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
	
	function PackageManager:_GetLocalPackage(localClassTraceOffset)
		local rootFolderNames = self.RootFolderNames

		local trace = debug.traceback("", 2 + localClassTraceOffset)

		local lastLine = string.match(trace, "[^\n]+%s*$")
		lastLine = string.gsub(lastLine, "\n", "")

		local names = {}
		for substring in string.gmatch(lastLine, "[^.]+") do
			table.insert(names, substring)
		end

		local scriptName = string.match(names[#names], "(.*):%d+$")
		if scriptName and scriptName == self.MainScriptName then
			return self.RootPackage
		end

		-- last line is running class
		table.remove(names)

		for i = #names, 1, -1 do
			local potentialPackageName = names[i]
			
			for rootName in next, rootFolderNames do
				if potentialPackageName == rootName then
					return self.RootPackage
				end 
			end

			local package = self:GetPackage(potentialPackageName, true)
			if package then
				return package
			end
		end
		
		errorf("cannot extract package name from trace '%s'", lastLine)
	end
	
	buildclass("PackageManager", PackageManager)
end

local Kernel = {} do

	function Kernel:constructor(
		classesFolders : {Instance},
		librariesFolders : {Instance},
		mainScript : ModuleScript
	)
		expectrbxtype(classesFolders, "table")
		expectrbxtype(librariesFolders, "table")
		expectrbxtype(mainScript, "Instance")
		
		local libraryCollector = LibraryCollector.new()
		local packageManager = PackageManager.new(classesFolders, mainScript)
		
		self._MainScript = mainScript
		self._AreClassesFinalized = false
		self._PackageManager = packageManager
		self._LibrariesCollector = libraryCollector

		local _, firstRootPackageContainer = next(classesFolders)
		expectrbxtype(firstRootPackageContainer, "Instance")

		local rootPackage = packageManager:BuildRootPackage(firstRootPackageContainer)

		for _, classFolder in next, classesFolders do
			expectrbxtype(classFolder, "Instance")
			rootPackage:Collect(classFolder)
		end
		
		for _, libraryFolder in next, librariesFolders do
			expectrbxtype(libraryFolder, "Instance")
			libraryCollector:Collect(libraryFolder)
		end
	end
	
	function Kernel:_InvokeMain()
		require(self._MainScript)

		if not self._AreClassesFinalized then
			warn("classes are not finalized after running 'Main' module\nwrite 'shared.kernel:FinalizeClasses()' after all your imports")
		end
	end
	
	local expectclasstype = baseLibrary.expectclasstype

	function Kernel:GetClass(path : string)
		expecttype(path, "string")
		return self._PackageManager:GetClass(path, 1)
	end

	function Kernel:GetLibrary(name : string)
		expecttype(name, "string")
		return self._LibrariesCollector:GetLibrary(name):GetReturnValue()
	end

	function Kernel:GetEnum(path : string)
		expecttype(path, "string")
		return self._PackageManager:GetEnum(path, 1)
	end

	function Kernel:FinalizeClasses()
		if self._AreClassesFinalized then
			error("classes are already finalized")
		end
		
		self._AreClassesFinalized = true
		for packageName, package in next, self._PackageManager.Packages do

			for moduleName, implementationModule in next, package._ModuleNameToImplementation do
				local class = package:GetClass(moduleName)
				baseLibrary.__registerimplementation(class, require(implementationModule))
			end
		end

		baseLibrary.__linkimplementations()
	end

	function Kernel:GetBaseLibrary()
		return baseLibrary
	end

	buildclass("Kernel", Kernel)
end

return Kernel