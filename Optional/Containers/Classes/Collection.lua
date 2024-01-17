local Collection = {} do
	
	function Collection:constructor()
		self.Items = {}
		self.Size = 0
	end
	
	function Collection:Destroy()
		table.clear(self.Items)
	end
	
	function Collection:Clear()
		table.clear(self.Items)
		self.Size = 0
	end
	
	function Collection:GetSize()
		return self.Size
	end
	
	function Collection:IsEmpty()
		return self.Size == 0
	end
	
	function Collection:ForEach(callback)
		for i, item in next, self.Items do
			callback(i, item)
		end
	end
	
	function Collection:ForEachCallMethod(name, ...)
		for _, item in next, self.Items do
			item[name](item, ...)
		end
	end
	
	function Collection:ForEachCallCachedMethod(name, ...)
		local items = self.Items
		
		local firstItem = next(items)
		if not firstItem then return end
		
		local method = firstItem[name]
		
		for _, item in next, items do
			method(item, ...)
		end
	end
	
	Collection.__attr_virtual_Find = true
	function Collection:Find(item)
		return table.find(self.Items, item)
	end
	
	local errorf = shared.errorf
	
	Collection.__attr_virtual_Remove = true
	function Collection:Remove(item)
		local pos = self:Find(item)
		if not pos then
			errorf("item '%s' does not belong to collection '%s'", tostring(item), tostring(self))
		end
		
		self.Size -= 1
		
		return table.remove(self.Items, pos)
	end
	
end

return Collection