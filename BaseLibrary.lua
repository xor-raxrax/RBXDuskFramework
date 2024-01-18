local kernelSettings = shared.kernelSettings
local debugModeEnabled = kernelSettings.DebugMode.Enabled

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

local function istype(value, t)
	return type(value) == t
end

local function istype2(value, t1, t2)
	local vtype = type(value)
	return vtype == t1
		or vtype == t2
end

local function istype3(value, t1, t2, t3)
	local vtype = type(value)
	return vtype == t1
		or vtype == t2
		or vtype == t3
end

local function istype4(value, t1, t2, t3, t4)
	local vtype = type(value)
	return vtype == t1
		or vtype == t2
		or vtype == t3
		or vtype == t4
end

local function istype5(value, t1, t2, t3, t4, t5)
	local vtype = type(value)
	return vtype == t1
		or vtype == t2
		or vtype == t3
		or vtype == t4
		or vtype == t5
end

local function getcallstacksize()
	local size = 2

	while debug.info(size, "f") do
		size += 1
	end

	return size - 2
end

local CLASS_OWN_MEMBERS = "__members"
local CLASS_VTMEMBER_OVERRIDES = "__override_members"
local CLASS_BASE = "__base"
local CLASS_TYPENAME = "__type"
local CLASS_ID = "__id"
local CLASS_MEMBER_ATTRIBUTES = "__member_attriutes"
local CLASS_ATTRIBUTES = "__class_attriutes"

local CLASS_CONSTRUCTOR = "constructor"
local CLASS_DESTRUCTOR = "Destroy"
local CLASS_OBJECT_CREATOR = "new"

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

local function removeindex(table_, item)
	table.remove(table_, assert(table.find(table_, item), "invalid item index"))
end

local inext = ipairs({})

-- expanded output

local settings = {
	max_layer = 12,
	tab_string = "  ", -- console shortens \t to single space
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

local function formatvalue(v)
	local vtype = type(v)

	if vtype == "string" then
		v = string.format("\"%s\"", string.gsub(v, "[\\\a\b\f\n\r\t\v\"\']", escape))

		if settings.normalize_string then
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

				if settings.ignore_tostring_metatable then
					return tostring(v)
				end

				rawset(metatable, "__tostring", nil)
				local result = tostring(v)
				rawset(metatable, "__tostring", __tostringValue)

				return result
			end

			return tostring(v)
		end

		if settings.use_type_instead_tostring then
			return "<table>"
		end

	elseif vtype == "userdata" then
		vtype = typeof(v)
		if vtype == "Instance" then

			local className = ""
			if settings.add_instance_class_name then
				className = v.ClassName .. ": "
			end

			v = string.format("Instance: %s\"%s\"", className, string.gsub(v:GetFullName(), "[\\\a\b\f\n\r\t\v\"\']", escape))

			if settings.normalize_string then
				local success, normalized = pcall(utf8.nfcnormalize, v)
				if success then
					return normalized
				end
			end

		else
			if settings.use_type_instead_tostring then
				return "<" .. vtype .. ">"
			end

			return string.format("%s(%s)", vtype, tostring(v))
		end
	elseif vtype == "vector" then
		return string.format("Vector3(%s)", tostring(v))
	elseif vtype == "function" then

		if settings.use_type_instead_tostring then
			if settings.add_closure_type then
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

local function expandedOutput(outputFunction, ...)
	local tab = settings.tab_string
	local maxLayer = settings.max_layer

	local layer = 0
	table.clear(printedTables)

	local function printl(t)
		if layer == maxLayer then return end

		local tab = string.rep(tab, layer)

		if table.find(printedTables, t) then
			outputFunction(tab, "*** already printed ***")
			return
		end

		table.insert(printedTables, t)

		for i, v in pairs(t) do
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

local function layerOutput(outputFunction, t)
	for i, v in pairs(t) do
		outputFunction(i, formatvalue(v))
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

local function expecttype(value, t)
	if type(value) == t then
		return value
	end

	errorf("<%s> expected, got <%s>", t, type(value))
end

local function expecttype2(value, t1, t2)
	local vtype = type(value)

	if vtype == t1
		or vtype == t2
	then
		return value
	end

	errorf("<%s> expected, got <%s>", t1, vtype)
end

local function expecttype3(value, t1, t2, t3)
	local vtype = type(value)

	if vtype == t1
		or vtype == t2
		or vtype == t3
	then
		return value
	end

	errorf("<%s> expected, got <%s>", t1, vtype)
end

local function expecttype4(value, t1, t2, t3, t4)
	local vtype = type(value)

	if vtype == t1
		or vtype == t2
		or vtype == t3
		or vtype == t4
	then
		return value
	end

	errorf("<%s> expected, got <%s>", t1, vtype)
end

local function expecttype5(value, t1, t2, t3, t4, t5)
	local vtype = type(value)

	if vtype == t1
		or vtype == t2
		or vtype == t3
		or vtype == t4
		or vtype == t5
	then
		return value
	end

	errorf("<%s> expected, got <%s>", t1, vtype)
end

local function expectrbxtype(value, expectedType)
	if typeof(value) ~= expectedType then
		errorf("<%s> expected, got <%s>", expectedType, typeof(value))
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
		errorf("<%s> expected, got <%s>", expectedType, class[CLASS_TYPENAME])
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
		Singleton = "singleton",
		NoFreeze = "nofreeze",
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

local DuskObject = {} do

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

			if informAliveThread and vtype == "thread" then
				if coroutine.status(value) ~= "dead" then
					inform(name, value, "alive thread; possible dangling thread")
				end

			elseif informAliveRBXScriptConnection and vtype == "RBXScriptConnection" then
				if not value.Connected then
					inform(name, value, "alive RBXScriptConnection; possible dangling connection")
				end

			elseif informRBXInstance and vtype == "Instance" then
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

end

local classBuilder do

	local alwaysInheritDuskObject = kernelSettings.AlwaysInheritDuskObject
	local logClassBuildingProcess = kernelSettings.LogClassBuildingProcess

	local pureVirtualMethodCallError = kernelSettings.PureVirtualMethodCallError

	local function pureVirtualMethodHandler(self)
		local name = debug.info(2, "ns")
		local message = string.format("attempt to call pure virtual method %s:%s()", self.__type, name)
		if pureVirtualMethodCallError then
			error(message)
		else
			warn(debug.traceback(message))
		end
	end

	local attributePrefix = "__attr_"
	local function isAttribute(name)
		return string.sub(name, 1, #attributePrefix) == attributePrefix
	end

	local classId = 0

	local instanceIndex = 0
	local emptyFunction = function()end

	local ClassBuilder = {} do
		ClassBuilder.__index = ClassBuilder

		function ClassBuilder.new()
			local self = setmetatable({}, ClassBuilder)

			self.Class = nil
			self.ClassName = nil

			self.MemberAttributes = nil
			self.ClassAttributes = nil
			self.VtMembers = nil

			return self
		end

		function ClassBuilder.IsMemberVirtual(class, memberName)
			local attributes = rawget(class, CLASS_MEMBER_ATTRIBUTES)
			local memberAttributes = attributes[memberName]

			if not memberAttributes then
				return false
			end

			return memberAttributes[AttributeType.Virtual]
		end

		function ClassBuilder.HasClassAttribute(class, name)
			return rawget(class, CLASS_ATTRIBUTES)[name]
		end

		function ClassBuilder:SetIndex()
			local class = self.Class
			local index = rawget(class, "__index")
			if index == nil or type(index) == "table" and index ~= class then
				rawset(class, "__index", class)
			end
		end

		local function collectInherited(result, currentClass)
			for _, baseClass in next, currentClass[CLASS_BASE] do
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
					table.insert(allInheritedClasses, DuskObject)
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
						or memberName == CLASS_CONSTRUCTOR
						or string.sub(memberName, 1, 2) == "__" then
						continue
					end

					if memberName == CLASS_DESTRUCTOR then
						table.insert(self.Destructors, member)
						continue
					end

					if self.IsMemberVirtual(baseClass, memberName) then
						inheritedVirtualMethods[memberName] = true
					end

					if class[memberName] and not inheritedVirtualMethods[memberName] then
						print("inheritedVirtualMethods", inheritedVirtualMethods)
						print("class", class)
						print("baseClass", baseClass)
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

			for memberName, member in next, rawget(class, CLASS_OWN_MEMBERS) do
				if inheritedVirtualMethods[memberName] then
					if logClassBuildingProcess then
						warn(`\t overriding {memberName}`)
					end
					rawset(class, memberName, member)
				end
			end
		end

		function ClassBuilder:HandleDebugAndInitialObjectCreators()
			local class = self.Class
			local className = self.ClassName

			local constructor = class[CLASS_CONSTRUCTOR]
			if not constructor then
				class[CLASS_CONSTRUCTOR] = emptyFunction
			end

			local debugModeSettings = kernelSettings.DebugMode

			if debugModeEnabled then

				if constructor then
					class[CLASS_CONSTRUCTOR] = function(...)
						assert(isclass(...), "class expected")
						assertf(constructor(...) == nil, "constructor of '%s' cannot return value", className)
					end
				end

				if debugModeSettings.AddTostringMetamethod then
					local index = rawget(class, "__tostring")
					if index == nil then
						rawset(class, "__tostring", function(self)
							return tostring(self[CLASS_ID]) .. "_" .. self[CLASS_TYPENAME]
						end)
					end
				end

				for memberName, memberFunction in next, class do
					if type(memberFunction) ~= "function" then continue end
					if string.sub(memberName, 1, 2) == "__" then continue end

					local finalMemberFunction = memberFunction

					if debugModeSettings.LogCalls then
						local ignoreSpecialMethodCallLog = debugModeSettings.IgnoreSpecialMethodCallLog

						if not ignoreSpecialMethodCallLog
							or (ignoreSpecialMethodCallLog and not table.find(debugModeSettings.SpecialMethodNames, memberName)) then

							local lastFunction = finalMemberFunction
							finalMemberFunction = function(...)
								local arguments = ""

								local isMethod = false

								local first = ...
								if type(first) == "table" and first[CLASS_TYPENAME] == className then
									isMethod = true
								end

								local argSize = select("#", ...)
								for i = isMethod and 2 or 1, argSize do
									local separator = ""

									if i < argSize then
										separator ..= ", "
									end

									arguments ..= tostring(select(i, ...)) .. separator
								end

								warnf("%s%s%s%s(%s)",
									string.rep("  ", getcallstacksize()),
									isMethod and tostring(first) or className,
									isMethod and ":" or ".",
									memberName,
									arguments
								)

								return lastFunction(...)
							end

						end

					end

					if memberName == CLASS_OBJECT_CREATOR then
						class[memberName] = function(...)
							local instance = finalMemberFunction(...)
							instance[CLASS_ID] = instanceIndex
							instanceIndex += 1
							return instance
						end
					else
						class[memberName] = finalMemberFunction
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
			if #destructors > 1 then

				-- destructor call order is reversed
				-- derived -> base

				if logClassBuildingProcess then
					print(self.ClassName, "destructors:")
					for _, destructor in next, destructors do
						warn("\t", debug.info(destructor, "sn"))
					end
				end

				finalDestructor = function(self)
					for _, destructor in next, destructors do
						destructor(self)
					end
				end
			else
				finalDestructor = emptyFunction
			end
			
			rawset(class, CLASS_DESTRUCTOR, finalDestructor)
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

			local pureVirtualHandler = function(builder, memberName)
				builder.VtMembers[memberName] = pureVirtualMethodHandler
				builder:HandleAttribute({AttributeType.Virtual, memberName}, memberName)
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

				[AttributeType.Singleton] = {
					ApplyType = AttributeApplyType.Class,
					Handler = nil,
				},

				[AttributeType.NoFreeze] = {
					ApplyType = AttributeApplyType.Class,
					Handler = nil,
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
					error(`invalid attribute type '{attributeType}' of '{self.ClassName}::{memberName}'`)
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

			-- TODO: may be unsafe
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
			local vtmembers = self.VtMembers

			for name, memberOrValue in next, self.Class do
				if isAttribute(name) then
					self:HandleAttributeField(name, memberOrValue)
				else
					vtmembers[name] = memberOrValue
				end
			end
		end

		function ClassBuilder:AssignClassCoreComponents()
			local class = self.Class
			rawset(class, CLASS_OWN_MEMBERS, self.VtMembers)
			rawset(class, CLASS_VTMEMBER_OVERRIDES, {})
			rawset(class, CLASS_TYPENAME, self.ClassName)
			rawset(class, CLASS_ID, classId)
			rawset(class, CLASS_MEMBER_ATTRIBUTES, self.MemberAttributes)
			rawset(class, CLASS_ATTRIBUTES, self.ClassAttributes)
		end

		function ClassBuilder:HandleSingleton()
			if self.HasClassAttribute(self.Class, AttributeType.Singleton) then
				local instance
				local creator = self.ObjectCreator
				self.ObjectCreator = function(...)
					if instance then
						return instance
					end

					instance = creator(...)
					return instance
				end
			end
		end

		function ClassBuilder:Build(className, class, ...)
			self.Class = class
			self.ClassName = className

			self.MemberAttributes = {}
			self.ClassAttributes = {}
			self.VtMembers = {}
			self.Destructors = {}

			self.ObjectCreator = emptyFunction

			self:HandleMembers()
			self:AssignClassCoreComponents()
			self:InitAndValidateInheritance(...)
			self:SetIndex()
			self:ProcessInheritance()
			self:HandleDebugAndInitialObjectCreators()
			self:BuildDestructor()
			self:HandleSingleton()

			class[CLASS_OBJECT_CREATOR] = self.ObjectCreator
		end
	end

	classBuilder = ClassBuilder.new()
end

local function buildclass(className, class, ...)
	classBuilder:Build(className, class, ...)

	if not hasClassAttribute(class, AttributeType.NoFreeze) then
		table.freeze(class)
	end

	return class
end

local function readbit(n, index)
	return bit32.extract(n, index, 1)
end

local function writebit(n, index, bit)
	return bit32.replace(n, bit, index, 1)
end

local function getallnodesize(t)
	local size = 0
	for _ in next, t do
		size += 1
	end
	return size
end

buildclass("DuskObject", DuskObject)

local library = {}

library.printf = printf
library.warnf = warnf
library.errorf = errorf

library.formatvalue = formatvalue
library.printe = printe
library.printl = printl
library.warne = warne
library.warnl = warnl

library.getallnodesize = getallnodesize
library.removeindex = removeindex
library.inext = inext

library.readbit = readbit
library.writebit = writebit

library.assertf = assertf
library.expecttype = expecttype
library.expecttype2 = expecttype2
library.expecttype3 = expecttype3
library.expecttype4 = expecttype4
library.expecttype5 = expecttype5
library.expectrbxtype = expectrbxtype
library.expectclass = expectclass
library.expectclasstyperaw = expectclasstyperaw
library.expectclasstype = expectclasstype

library.istype = istype
library.istype2 = istype2
library.istype3 = istype3
library.istype4 = istype4
library.istype5 = istype5
library.isprimitive = isprimitive
library.iscclosure = iscclosure
library.islclosure = islclosure
library.getcallstacksize = getcallstacksize
library.isclasstyperaw = isclasstyperaw
library.isclasstype = isclasstype
library.isclass = isclass

library.buildclass = buildclass

return library