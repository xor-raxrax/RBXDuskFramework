local expecttype = shared.expecttype

local Cache = {} do
	
	function Cache.new(constructor, defaultArguments, expansionSize)
		expecttype(constructor, "function")
		
		local self = setmetatable({}, Cache)
		
		self._Constructor = constructor
		self._DefaultArguments = defaultArguments or {}
		self._ExpansionSize = expansionSize or 10
		
		self._Stored = {}
		self._GetNextPosition = self:_Expand()
		
		self._InUse = {}
		self._InUseNextPosition = 0
		
		return self
	end
	
	function Cache:Destroy()
		for _, item in next, self._Stored do
			item:Destroy()
		end
		
		for _, item in next, self._InUse do
			item:Destroy()
		end
		
		table.clear(self._Stored)
		table.clear(self._InUse)
		self._DefaultArguments = nil
		self._Constructor = nil
	end
	
	function Cache:Get()
		local getPosition = self._GetNextPosition
		if getPosition == 0 then
			getPosition = self:_Expand()
		end
		
		local stored = self._Stored
		local item = stored[getPosition]
		stored[getPosition] = nil
		getPosition -= 1
		
		self._GetNextPosition = getPosition
		
		self._InUseNextPosition += 1
		self._InUse[self._InUseNextPosition] = item
		
		return item
	end
	
	Cache.__attr_virtual_Store = true
	function Cache:Store(item)
		local inUse = self._InUse
		local index = table.find(inUse, item)
		if not index then
			error("item does not belong to this cache")
		end
		
		table.remove(inUse, index)
		
		self._InUseNextPosition -= 1
		
		self._GetNextPosition += 1
		self._Stored[self._GetNextPosition] = item
	end
	
	function Cache:IterateStored(i)
		local stored = self._Stored
		return stored, next(stored, i)
	end
	
	function Cache:IterateInUse(i)
		local inUse = self._InUse
		return inUse, next(inUse, i)
	end
	
	function Cache:ForEachStored(callback)
		for i, part in next, self._Stored do
			callback(i, part)
		end
	end
	
	function Cache:ForEachInUse(callback)
		for i, part in next, self._Stored do
			callback(i, part)
		end
	end
	
	function Cache:ForEach(callback)
		self:ForEachStored(callback)
		self:ForEachInUse(callback)
	end
	
	function Cache:_Expand()
		local expansionSize = self._ExpansionSize
		
		local stored = self._Stored
		local constructor = self._Constructor
		local arguments = self._DefaultArguments
		for i = 1, expansionSize do
			stored[i] = constructor(unpack(arguments))
		end
		
		return expansionSize
	end
	
	shared.buildclass("Cache", Cache)
end

return Cache