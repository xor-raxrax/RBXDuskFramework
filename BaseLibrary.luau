local kernelSettings = require(script.Parent.KernelSettings)
local debugModeEnabled = kernelSettings.DebugMode and kernelSettings.DebugMode.Enabled

-- reflection

local function islclosure(closure)
	return debug.info(closure, "s") ~= "[C]"
end

local function iscclosure(closure)
	return debug.info(closure, "s") == "[C]"
end

local function isprimitive(value)
	local vtype = type(value)
	return vtype == "string"
		or vtype == "number"
		or vtype == "boolean"
		or value == nil
end

local function compare<T>(what : T, t0 : T?, t1 : T?,
	t2 : T?, t3 : T?, t4 : T?, t5 : T?, ... : T?
)
	if what == t0 then
		return true
	end

	if t1 then
		if what == t1 then
			return true
		end

		if t2 then
			if what == t2 then
				return true
			end

			if t3 then
				if what == t3 then
					return true
				end

				if t4 then
					if what == t4 then
						return true
					end

					if t5 then
						if what == t5 then
							return true
						end
					end

					return compare(what, ...)
				end
			end
		end

	end

	return false
end

local function istype(value, ...)
	return compare(type(value), ...)
end

local function getcallstacksize(step)
	step = step or 1000
	local low = 2
	local high = low + step
	local mid

	while debug.info(high, "f") do
		low = high
		high += step
	end

	while low <= high do
		mid = math.ceil((low + high) / 2)
		if debug.info(mid, "f") then
			low = mid + 1
		else
			high = mid - 1
		end
	end

	return high - 1
end

local CLASS_OWN_MEMBERS = "__members"
local CLASS_BASE = "__base"
local CLASS_TYPENAME = "__type"
local CLASS_ID = "__id"
local CLASS_MEMBER_ATTRIBUTES = "__member_attriutes"
local CLASS_ATTRIBUTES = "__class_attriutes"

local CLASS_CONSTRUCTOR = "constructor"
local CLASS_DESTRUCTOR = "destructor"
local CLASS_OBJECT_CREATOR = "new"
local CLASS_OBJECT_DESTRUCTOR = "Destroy"

local INSTANCE_ID = "__instanceId"

local function getDebugInfo(method)
	local source, line = debug.info(method, "sl")
	return `{source}:{line}`
end

local function getFullDebugInfo(class, methodName)
	return `'{class.__type}.{methodName}' ({getDebugInfo(class[methodName])})`
end


local function isclasstyperaw(class, expectedType)
	return class[CLASS_TYPENAME] == expectedType
end

local function isclasstype(class, expectedType)
	return istype(class, "table") and isclasstyperaw(class, expectedType)
end

local function isclass(class)
	return istype(class, "table") and istype(class[CLASS_TYPENAME], "string")
end

-- output

local function printf(...)
	print(string.format(...))
end

local function warnf(...)
	warn(string.format(...))
end

local function errorf(...)
	error(string.format(...), 2)
end

-- utility

local function removeindex(array, item)
	local pos = table.find(array, item)
	if pos then
		return table.remove(array, pos)
	end
end

local function removeindexthrow(array, item)
	assert(select('#', removeindex(array, item)) > 0, "invalid item index")
	return item -- table.remove would return passed
end


local inext = ipairs({})

-- expanded output


local formatvalue
local layerOutput
local expandedOutput

do

	local outputSettings = {
		max_layer = 12,
		use_type_instead_tostring = true,
		ignore_tostring_metatable = true,
		add_instance_class_name = true,
		normalize_string = true,
		add_closure_type = true,
	}

	local escape = {
		['\\'] = '\\\\',
		['\a'] = '\\a',
		['\b'] = '\\b',
		['\f'] = '\\f',
		['\n'] = '\\n',
		['\r'] = '\\r',
		['\t'] = '\\t',
		['\v'] = '\\v',
		['\"'] = '\\"',
		['\''] = '\\\''
	}

	function formatvalue(v)
		local vtype = type(v)

		if vtype == "string" then
			v = string.format("\"%s\"", string.gsub(v, "[\\\a\b\f\n\r\t\v\"\']", escape))

			if outputSettings.normalize_string then
				local success, normalized = pcall(utf8.nfcnormalize, v)
				if success then
					return normalized
				end
			end

		elseif vtype == "table" then

			local metatable = getmetatable(v)
			if metatable then

				local __tostringValue = rawget(metatable, "__tostring")
				if __tostringValue then

					if outputSettings.ignore_tostring_metatable then
						return tostring(v)
					end

					rawset(metatable, "__tostring", nil)
					local result = tostring(v)
					rawset(metatable, "__tostring", __tostringValue)

					return result
				end

				return tostring(v)
			end

			if outputSettings.use_type_instead_tostring then
				return "<table>"
			end

		elseif vtype == "userdata" then
			vtype = typeof(v)
			if vtype == "Instance" then

				local className = ""
				if outputSettings.add_instance_class_name then
					className = v.ClassName .. ": "
				end

				v = string.format("Instance: %s\"%s\"", className, string.gsub(v:GetFullName(), "[\\\a\b\f\n\r\t\v\"\']", escape))

				if outputSettings.normalize_string then
					local success, normalized = pcall(utf8.nfcnormalize, v)
					if success then
						return normalized
					end
				end

			else
				if outputSettings.use_type_instead_tostring then
					return "<" .. vtype .. ">"
				end

				return string.format("%s(%s)", vtype, tostring(v))
			end
		elseif vtype == "vector" then
			return string.format("Vector3(%s)", tostring(v))
		elseif vtype == "function" then

			if outputSettings.use_type_instead_tostring then
				if outputSettings.add_closure_type then
					if islclosure(v) then
						return "<lclosure>"
					end
					return "<cclosure>"
				end
				return "<function>"
			end

		end

		return v
	end

	local printedTables = {}

	function expandedOutput(outputFunction, ...)
		local maxLayer = outputSettings.max_layer

		local layer = 0
		table.clear(printedTables)

		local function printl(t)
			if layer == maxLayer then return end

			local tab = string.rep('\t', layer)

			if table.find(printedTables, t) then
				outputFunction(tab, "*** already printed ***")
				return
			end

			table.insert(printedTables, t)

			for i, v in next, t do
				outputFunction(tab, i, formatvalue(v))
				if type(v) == "table" then
					layer = layer + 1
					printl(v)
					layer = layer - 1
				end
			end
		end

		for i = 1, select("#", ...) do
			local v = select(i, ...)
			if type(v) == "table" then
				printl(v)
			else
				outputFunction(v)
			end
		end
	end

	function layerOutput(outputFunction, t)
		for i, v in next, t do
			outputFunction(i, formatvalue(v))
		end
	end

end

local function printe(...)
	expandedOutput(print, ...)
end

local function warne(...)
	expandedOutput(warn, ...)
end

local function printl(...)
	layerOutput(print, ...)
end

local function warnl(...)
	layerOutput(warn, ...)
end

-- assertation

local function assertf(expression, ...)
	if not expression then
		error(string.format(...), 2)
	end
	return expression
end

local function expecttype(value, expectedType, ...)
	local myType = type(value)
	if not compare(myType, expectedType, ...) then
		errorf("'%s' expected, got '%s'", expectedType, myType)
	end
	return value
end

local function expectrbxtype(value, expectedType, ...)
	local myType = typeof(value)
	if not compare(myType, expectedType, ...) then
		errorf("'%s' expected, got '%s'", expectedType, myType)
	end
	return value
end

local function expectclass(class)
	expecttype(class, "table")
	assert(class[CLASS_TYPENAME], "passed value is not a class")
	return class
end

local function expectclasstyperaw(class, expectedType)
	if class[CLASS_TYPENAME] ~= expectedType then
		errorf("'%s' expected, got '%s'", expectedType, class[CLASS_TYPENAME])
	end
	return class
end

local function expectclasstype(class, expectedType)
	expectclass(class)
	expectclasstyperaw(class, expectedType)
	return class
end


-- oop


local AttributeType do

	AttributeType = {
		Virtual = "virtual",
		PureVirtual = "purevirtual",
		NoFreeze = "nofreeze",
		Declaration = "decl",
	}

	local toAdd = {}

	for name, value in next, AttributeType do
		toAdd[value] = name
	end

	for value, name in next, toAdd do
		AttributeType[value] = name
	end
end

local function hasClassAttribute(class, name)
	return rawget(class, CLASS_ATTRIBUTES)[name]
end


local classToIdMap = {}
local classToNameMap = {}
do

	local invalidIndexHandler = {}
	function invalidIndexHandler:__index(class)
		errorf("Passed class '%s' is not registered in class map", tostring(rawget(class, CLASS_TYPENAME)))
	end

	setmetatable(classToIdMap, invalidIndexHandler)
	setmetatable(classToNameMap, invalidIndexHandler)
end


local function getclassof(instance)
	local class = getmetatable(instance)
	return class
end

local function getclassid(class)
	return classToIdMap[class]
end

local function getclassname(class)
	return classToNameMap[class]
end

local function getclassidof(instance)
	return getclassid(getclassof(instance))
end

local function getclassnameof(instance)
	return getclassname(getclassof(instance))
end

local function isclassof(class, instance)
	return class == getclassof(instance)
end

local DuskObject = {} do

	local informerSettings = kernelSettings.ClassInstanceCleanup

	if informerSettings.Enabled then

		local informUseErrorInsteadOfWarn = informerSettings.InformUseErrorInsteadOfWarn

		local informAliveThread = informerSettings.InformAliveThread
		local informAliveRBXScriptConnection = informerSettings.InformAliveRBXScriptConnection
		local informRBXInstance = informerSettings.InformRBXInstance

		local function inform(fieldSymbol, value, message)
			local formatted = string.format("%s = %s (%s)", tostring(fieldSymbol), tostring(value), message)
			if informUseErrorInsteadOfWarn then
				error(formatted, 4)
			else
				warn(debug.traceback(formatted, 4))
			end
		end

		local function validate(name, value)
			local vtype = typeof(value)

			if informAliveThread and vtype == "thread" then
				if coroutine.status(value) ~= "dead" then
					inform(name, value, "alive thread; possible dangling thread")
				end

			elseif informAliveRBXScriptConnection and vtype == "RBXScriptConnection" then
				if not value.Connected then
					inform(name, value, "alive RBXScriptConnection; possible dangling connection")
				end

			elseif informRBXInstance and vtype == "Instance" then
				inform(name, value, "Intance reference; possible dangling Instance")

			end
		end

		local actionBlocker = {} do

			function actionBlocker:__index(k)
				warn("object is deleted", self)
				errorf("attempt to index deleted object with '%s'", tostring(k))
			end

			function actionBlocker:__newindex(k, v)
				warn("object is deleted", self)
				errorf("attempt to assign to deleted object with index '%s'", tostring(k))
			end

			local function operationError(self)
				warn("object is deleted", self)
				error("attempt to perform operation with deleted object")
			end
		end

		local clearAndBlock = informerSettings.ClearAndBlock
		function DuskObject:destructor()
			local classType = self.__type .. "."
			for field, item in next, self do
				validate(classType .. "<field>", field)
				validate(classType .. field, item)
			end

			if clearAndBlock then
				local myClass = getmetatable(self)

				local copy = table.clone(self)
				table.clear(self)

				self.__info_objectCopy = copy
				self.__info_className = getclassname(myClass)
				self.__info_classId = getclassid(myClass)
				self.__info_class = myClass

				setmetatable(self, actionBlocker)
			end
		end

	end

end


local function iterateClassMethods(class)
	local function iterator(class, memberName, member)
		local nextKey, nextValue = next(class, memberName)

		while nextKey do
			if type(nextValue) == "function" and string.sub(nextKey, 1, 2) ~= "__" then
				return nextKey, nextValue
			end

			nextKey, nextValue = next(class, nextKey)
		end

		return nil
	end

	return iterator, class, nil
end

local emptyFunction = function()end

local classBuilder

local methodLinker do

	local MethodLinker = {} do
		MethodLinker.__index = MethodLinker

		function MethodLinker.new()
			local self = setmetatable({}, MethodLinker)

			self.Classes = {}
			self.MethodToImplementation = {}
			self.DidFinalize = false
			
			return self
		end

		function MethodLinker:RegisterClass(class)
			table.insert(self.Classes, class)
		end

		function MethodLinker:RegisterDeclaration(method)
			self.MethodToImplementation[method] = emptyFunction
		end

		function MethodLinker:RegisterImplementation(method, implementation)
			self.MethodToImplementation[method] = implementation
		end

		function MethodLinker:Finalize()
			local methodToImplementation = self.MethodToImplementation

			local unresolvedMethodImplementation = false
			
			for _, class in next, self.Classes do

				for methodName, method in iterateClassMethods(class) do
					if methodName == CLASS_OBJECT_CREATOR
						or methodName == CLASS_OBJECT_DESTRUCTOR
					then
						continue
					end

					local implementation = methodToImplementation[method]
					if not implementation then continue end
					
					local isPureVirtual = classBuilder.HasMemberAttribute(class, methodName, AttributeType.PureVirtual)

					if implementation == emptyFunction and
						not isPureVirtual
					then
						unresolvedMethodImplementation = true

						warnf("unresolved method implementation of %s",
							getFullDebugInfo(class, methodName))

						continue
					end

					rawset(class, methodName, implementation)
				end

				local hasNoFreeze = hasClassAttribute(class, AttributeType.NoFreeze)

				if not debugModeEnabled then
					classBuilder.RemoveBuildInfo(class)
				end

				if not hasNoFreeze then
					table.freeze(class)
				end
			end

			if unresolvedMethodImplementation then
				error("unresolved method implementation")
			end
			
			self.DidFinalize = true
		end

		function MethodLinker:RegisterClassImplementation(originalClass, implementationClass)
			for methodName, method in next, implementationClass do
				local declaredMethod = rawget(originalClass, methodName)
				self:RegisterImplementation(declaredMethod, method)
			end
		end

	end

	methodLinker = MethodLinker.new()
end

do -- classBuilder

	local alwaysInheritDuskObject = kernelSettings.AlwaysInheritDuskObject
	local logClassBuildingProcess = kernelSettings.LogClassBuildingProcess

	local pureVirtualMethodCallError = kernelSettings.PureVirtualMethodCallError

	local function createPureVirtualMethodHandler(class, memberName)
		local function pureVirtualMethodHandler(self)
			local message = string.format("attempt to call pure virtual method %s for class '%s'",
				getFullDebugInfo(class, memberName), self.__type)

			if pureVirtualMethodCallError then
				error(message)
			else
				warn(debug.traceback(message))
			end
		end
		return pureVirtualMethodHandler
	end

	local attributePrefix = "__attr_"
	local function isAttribute(name)
		return string.sub(name, 1, #attributePrefix) == attributePrefix
	end

	local ClassBuilder = {} do
		ClassBuilder.__index = ClassBuilder

		function ClassBuilder.new()
			local self = setmetatable({}, ClassBuilder)

			self.Class = nil
			self.ClassName = nil

			self.MemberAttributes = nil
			self.ClassAttributes = nil
			self.OwnMembers = nil
			self.ClassIdCounter = 0

			self.ClassesWithDeclarations = {}

			return self
		end

		function ClassBuilder.HasClassAttribute(class, name)
			return rawget(class, CLASS_ATTRIBUTES)[name]
		end

		function ClassBuilder.HasMemberAttribute_attributes(attributes, memberName, type)
			local memberAttributes = attributes[memberName]

			if not memberAttributes then
				return false
			end

			return not not memberAttributes[type]
		end

		function ClassBuilder.HasMemberAttribute(class, memberName, type)
			local attributes = rawget(class, CLASS_MEMBER_ATTRIBUTES)
			if not attributes then
				return false
			end

			return ClassBuilder.HasMemberAttribute_attributes(attributes, memberName, type)
		end

		function ClassBuilder:SetIndex()
			local class = self.Class
			local index = rawget(class, "__index")
			if index == nil or type(index) == "table" and index ~= class then
				rawset(class, "__index", class)
			end
		end

		local function collectInherited(result, currentClass)
			for _, baseClass in next, rawget(currentClass, CLASS_BASE) do
				if table.find(result, baseClass) then continue end
				collectInherited(result, baseClass)
				table.insert(result, baseClass)
			end
		end

		function ClassBuilder:CollectInheritedClasses()
			local class = self.Class
			local allInheritedClasses = {}
			collectInherited(allInheritedClasses, class)

			if alwaysInheritDuskObject and class ~= DuskObject then
				local hasDuskObject = false

				for _, baseClass in next, allInheritedClasses do
					if baseClass == DuskObject then
						hasDuskObject = true
						break
					end
				end

				if not hasDuskObject then
					table.insert(allInheritedClasses, 1, DuskObject)
				end
			end

			return allInheritedClasses
		end

		function ClassBuilder:ProcessInheritance()
			local class = self.Class
			local allInheritedClasses = self:CollectInheritedClasses()

			local inheritedVirtualMethods = {}

			if logClassBuildingProcess then
				print(self.ClassName, "inheritance:")
			end

			-- move inherited methods to vtable and collect destructors
			for _, baseClass in next, allInheritedClasses do

				if logClassBuildingProcess then
					print("\t inheriting", rawget(baseClass, CLASS_TYPENAME))
				end

				for memberName, member in next, rawget(baseClass, CLASS_OWN_MEMBERS) do

					if memberName == CLASS_OBJECT_CREATOR
						or memberName == CLASS_OBJECT_DESTRUCTOR
					then
						print("declaration at", getFullDebugInfo(baseClass, memberName), baseClass)
						error(`cannot define reserved '{memberName}()'`)
					end

					if memberName == CLASS_CONSTRUCTOR
						or string.sub(memberName, 1, 2) == "__"
					then
						continue
					end

					if memberName == CLASS_DESTRUCTOR then
						table.insert(self.Destructors, member)
						continue
					end

					if self.HasMemberAttribute(baseClass, memberName, AttributeType.Virtual) then
						inheritedVirtualMethods[memberName] = true
					end

					if class[memberName] and not inheritedVirtualMethods[memberName] then
						print("inheritedVirtualMethods", inheritedVirtualMethods)
						print("attempted to override", getFullDebugInfo(baseClass, memberName), baseClass)
						print("attempted to override with", getFullDebugInfo(class, memberName), class)
						error(`cannot override non-virtual method '{memberName}'`)
					end

					if logClassBuildingProcess then
						local name = debug.info(member, "n")
						if memberName ~= name then
							warn(`\t added {memberName} ({name})`)
						else
							warn("\t added", memberName)
						end
					end

					rawset(class, memberName, member)
				end

			end

			for memberName, member in next, self.OwnMembers do
				if inheritedVirtualMethods[memberName] then
					if logClassBuildingProcess then
						warn(`\t overriding {memberName}`)
					end
					rawset(class, memberName, member)
				end
			end
		end

		local instanceIndex = 0
		function ClassBuilder:HandleObjectCreators()
			local class = self.Class

			local constructor = class[CLASS_CONSTRUCTOR] or emptyFunction

			if debugModeEnabled or kernelSettings.SelfArgumentValidationInConstructors then

				local function baseTableClassSearch(baseClasses, classToFind)
					for _, baseClass in next, baseClasses do
						if baseClass == classToFind then
							return baseClass
						else
							local foundClass = baseTableClassSearch(rawget(baseClass, CLASS_BASE), classToFind)
							if foundClass then
								return foundClass
							end
						end
					end
				end

				local originalConstructor = constructor
				constructor = function(self, ...)
					expectclass(self)

					-- check if we are calling constructor with self of it's own class or derived one
					local myClass = getmetatable(self)
					if getmetatable(self) == class
						or baseTableClassSearch(rawget(myClass, CLASS_BASE), class)
					then
						originalConstructor(self, ...)
					else
						print("passed class:", myClass)
						print("expected class:", class)
						error("'self' class is unrelated to the class of the calling constructor")
					end
				end
			end

			if constructor then
				self.ObjectCreator = function(...)
					local object = setmetatable({}, class)
					constructor(object, ...)
					return object
				end
			else
				self.ObjectCreator = function()
					return setmetatable({}, class)
				end
			end

			class[CLASS_CONSTRUCTOR] = constructor
		end

		function ClassBuilder:HandleDebug()
			if not debugModeEnabled then return end

			local class = self.Class

			local debugModeSettings = kernelSettings.DebugMode

			if debugModeSettings.AddTostringMetamethod then
				local currentTostring = rawget(class, "__tostring")
				if currentTostring == nil then
					local function __tostring(self)
						return tostring(rawget(self, INSTANCE_ID) .. "_" .. rawget(self, CLASS_TYPENAME))
					end
					rawset(class, "__tostring", __tostring)
				end
			end

			for memberName, memberFunction in iterateClassMethods(class) do

				local finalMemberFunction = memberFunction

				if memberName == CLASS_OBJECT_CREATOR then
					class[memberName] = function(...)
						local instance = finalMemberFunction(...)
						rawset(instance, INSTANCE_ID, instanceIndex)
						instanceIndex += 1
						return instance
					end
				else
					rawset(class, memberName, finalMemberFunction)
				end
			end

		end

		function ClassBuilder:InitAndValidateInheritance(...)
			local class = self.Class
			local baseClasses = rawget(class, CLASS_BASE)

			if not baseClasses then
				baseClasses = {...}
				rawset(class, CLASS_BASE, baseClasses)

				for _, baseClass in next, baseClasses do
					if baseClass == class then
						error("recursive inheritance is not allowed")
					end
				end
			end
		end

		function ClassBuilder:BuildDestructor()
			local class = self.Class

			local thisDestructor = rawget(class, CLASS_DESTRUCTOR)
			if thisDestructor then
				table.insert(self.Destructors, thisDestructor)
			end

			local finalDestructor

			local destructors = self.Destructors
			if #destructors > 0 then

				if logClassBuildingProcess then
					print(self.ClassName, "destructors:")
					for _, destructor in next, destructors do
						warn("\t", debug.info(destructor, "sn"))
					end
				end

				-- destructor call order is reversed
				-- derived -> base

				finalDestructor = function(self)
					for i = #destructors, 1, -1 do
						destructors[i](self)
					end
				end
			else
				finalDestructor = emptyFunction
			end

			rawset(class, CLASS_OBJECT_DESTRUCTOR, finalDestructor)
		end

		local function parseAttributeString(attributeString)
			local parts = {}
			local partStartPos, pos = 1, 1

			attributeString = string.sub(attributeString, #attributePrefix + 1)

			local isNewPart = true
			while pos <= #attributeString do
				local char = string.sub(attributeString, pos, pos)

				if char == "_" then
					if isNewPart then
						table.insert(parts, string.sub(attributeString, partStartPos, pos - 1))
						partStartPos = pos + 1
						isNewPart = false
					end
				else
					isNewPart = true
				end

				pos += 1
			end

			-- Add the last part after the last underscore (or the whole string if no underscore is found)
			table.insert(parts, string.sub(attributeString, partStartPos))

			return parts
		end

		local AttributeApplyType = {
			Class = 1,
			Member = 2,
		}

		local attributeInfo do

			local function pureVirtualHandler(classBuilder, memberName)
				local handler = createPureVirtualMethodHandler(classBuilder.Class, memberName)
				classBuilder:AddOwnMember(memberName, handler)
				classBuilder:HandleAttribute({AttributeType.Virtual, memberName}, true)
				methodLinker:RegisterDeclaration(classBuilder.Class[memberName])
			end

			local function declarationHandler(classBuilder, memberName)
				methodLinker:RegisterDeclaration(classBuilder.Class[memberName])
			end

			attributeInfo = {

				[AttributeType.Virtual] = {
					ApplyType = AttributeApplyType.Member,
					Handler = nil,
				},

				[AttributeType.PureVirtual] = {
					ApplyType = AttributeApplyType.Member,
					Handler = pureVirtualHandler,
				},

				[AttributeType.NoFreeze] = {
					ApplyType = AttributeApplyType.Class,
					Handler = nil,
				},

				[AttributeType.Declaration] = {
					ApplyType = AttributeApplyType.Member,
					Handler = declarationHandler,
				},

			}

		end

		function ClassBuilder:HandleAttribute(attributeArgs, value)
			local attributeType = attributeArgs[1]

			local info = attributeInfo[attributeType]

			if not info then
				local memberName = attributeArgs[2]
				if memberName then
					error(`invalid attribute type '{attributeType}' of '{self.ClassName}'`)
				else
					error(`invalid attribute type '{attributeType}' of '{self.ClassName}.{memberName}'`)
				end
			end

			local handler = info.Handler
			if handler then
				handler(self, unpack(attributeArgs, 2))
			end

			if info.ApplyType == AttributeApplyType.Class then
				self:AddClassAttribute(attributeType, value)
			else
				local memberName = attributeArgs[2]
				self:AddMemberAttribute(memberName, attributeType, value)
			end
		end

		function ClassBuilder:HandleAttributeField(fieldName, value)
			local attributeArgs = parseAttributeString(fieldName)

			if #attributeArgs == 0 then
				error(`unable to parse attribute '{fieldName}' of '{self.ClassName}'`)
			end

			self:HandleAttribute(attributeArgs, value)

			rawset(self.Class, fieldName, nil)
		end

		function ClassBuilder:AddMemberAttribute(memberName, type, value)
			local attributes = self.MemberAttributes[memberName]
			if not attributes then
				attributes = {}
				self.MemberAttributes[memberName] = attributes
			end

			if attributes[type] then
				warn(`duplicate attribute {self.ClassName}::{memberName}`, type)
			end

			attributes[type] = value
		end

		function ClassBuilder:AddClassAttribute(type, value)
			self.ClassAttributes[type] = value
		end

		function ClassBuilder:HandleMembers(name)
			local class = self.Class

			if logClassBuildingProcess then
				print(self.ClassName, "own members:")
			end

			local scratch = table.clone(class)
			for name, methodOrValue in next, scratch do
				if name == CLASS_BASE then continue end

				if isAttribute(name) then
					self:HandleAttributeField(name, methodOrValue)
				else

					if not self.HasMemberAttribute_attributes(self.MemberAttributes,
						name, AttributeType.PureVirtualVirtual)
					then
						self:AddOwnMember(name, methodOrValue)
					end

				end
			end
		end

		function ClassBuilder:AddOwnMember(name, methodOrValue)
			if logClassBuildingProcess then
				print("\t own member", name)
			end
			self.OwnMembers[name] = methodOrValue
		end
		
		function ClassBuilder:AssignClassBuildInfo()
			local class = self.Class
			rawset(class, CLASS_OWN_MEMBERS, self.OwnMembers)
			rawset(class, CLASS_TYPENAME, self.ClassName)
			rawset(class, CLASS_ID, self.ClassIdCounter)
			rawset(class, CLASS_MEMBER_ATTRIBUTES, self.MemberAttributes)
			rawset(class, CLASS_ATTRIBUTES, self.ClassAttributes)
		end

		function ClassBuilder.RemoveBuildInfo(class)
			if not (debugModeEnabled or kernelSettings.SelfArgumentValidationInConstructors) then
				rawset(class, CLASS_BASE, nil)
			end

			rawset(class, CLASS_OWN_MEMBERS, nil)
			rawset(class, CLASS_MEMBER_ATTRIBUTES, nil)
			rawset(class, CLASS_ATTRIBUTES, nil)
		end

		function ClassBuilder:Build(className, class, ...)
			self.Class = class
			self.ClassName = className

			self.MemberAttributes = {}
			self.ClassAttributes = {}
			self.OwnMembers = {}
			self.Destructors = {}

			self.ObjectCreator = emptyFunction

			self:HandleMembers()
			self:AssignClassBuildInfo()
			self:InitAndValidateInheritance(...)
			self:SetIndex()
			self:ProcessInheritance()
			self:HandleObjectCreators()
			self:HandleDebug()
			self:BuildDestructor()

			class[CLASS_OBJECT_CREATOR] = self.ObjectCreator

			self:RegisterBuiltClass()
		end

		function ClassBuilder:RegisterBuiltClass()
			classToIdMap[self.Class] = self.ClassIdCounter
			classToNameMap[self.Class] = self.ClassName
			self.ClassIdCounter += 1
			methodLinker:RegisterClass(self.Class)
		end
	end

	classBuilder = ClassBuilder.new()
end


local function buildclass(className, class, ...)
	assert(not methodLinker.DidFinalize, "cannot build class after class finalization phase")
	classBuilder:Build(className, class, ...)
	return class
end

local function __linkimplementations()
	methodLinker:Finalize()
end

local function __registerimplementation(originalClass, implementationClass)
	methodLinker:RegisterClassImplementation(originalClass, implementationClass)
end

local function readbit(n, index)
	return bit32.extract(n, index, 1)
end

local function writebit(n, index, bit)
	return bit32.replace(n, bit, index, 1)
end

local function lerp(min : number, max : number, alpha : number)
	return min + alpha * (max - min)
end

local function getalpha(min : number, max : number, num : number)
	return (num - min) / (max - min)
end

buildclass("DuskObject", DuskObject)

local badIndexGuard = {}
function badIndexGuard:__index(k)
	warn("base library content:", self)
	errorf("base library does not have item '%s'", k)
end

local library = setmetatable({}, badIndexGuard)

library.__linkimplementations = __linkimplementations
library.__registerimplementation = __registerimplementation

library.printf = printf
library.warnf = warnf
library.errorf = errorf

library.formatvalue = formatvalue
library.printe = printe
library.printl = printl
library.warne = warne
library.warnl = warnl

library.removeindex = removeindex
library.removeindexthrow = removeindexthrow
library.inext = inext

library.readbit = readbit
library.writebit = writebit

library.lerp = lerp
library.getalpha = getalpha

library.assertf = assertf
library.expecttype = expecttype
library.expectrbxtype = expectrbxtype
library.expectclass = expectclass
library.expectclasstyperaw = expectclasstyperaw
library.expectclasstype = expectclasstype

library.istype = istype
library.isprimitive = isprimitive
library.iscclosure = iscclosure
library.islclosure = islclosure
library.getcallstacksize = getcallstacksize
library.isclasstyperaw = isclasstyperaw
library.isclasstype = isclasstype
library.isclass = isclass

library.buildclass = buildclass

library.getclassof = getclassof
library.getclassid = getclassid
library.getclassname = getclassname
library.getclassidof = getclassidof
library.getclassnameof = getclassnameof
library.isclassof = isclassof

table.freeze(library)

return library