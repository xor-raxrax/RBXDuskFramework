local Collection = shared.kernel:GetKernelClass("Collection")

local Map = {} do
	
	function Map:constructor()
		Collection.constructor(self)
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
	
	function Map:Find(value)
		for key, pairValue in next, self.Items do
			if pairValue == value then
				return key
			end
		end
	end
	
	function Map:Remove(key)
		self:Set(key, nil)
	end
	
	shared.buildclass("Map", Map, Collection)
end

return Map