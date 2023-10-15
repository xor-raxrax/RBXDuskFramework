local Collection = shared.kernel:GetKernelClass("Collection")

local Map = {} do
	
	function Map.new()
		local self = setmetatable(Collection.new(), Map)
		
		return self
	end
	
	function Map:Get(key)
		return self.Items[key]
	end
	
	function Map:Set(key, value)
		local items = self.Items
		
		local currentValue = items[key]
		
		if value == nil then
			if currentValue ~= nil then
				self.Size -= 1
			end
		else
			if currentValue == nil then
				self.Size += 1
			end
		end
		
		items[key] = value
	end
	
	local override = {}
	
	function override:Find(value)
		for key, pairValue in next, self.Items do
			if pairValue == value then
				return key
			end
		end
	end
	
	function override:Remove(key)
		self:Set(key, nil)
	end
	
	shared.buildclassoverride("Map", Map, override, Collection)
end

return Map