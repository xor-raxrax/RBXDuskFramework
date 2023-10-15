local Collection = shared.kernel:GetKernelClass("Collection")

local Stack = {} do
	
	function Stack.new()
		local self = setmetatable(Collection.new(), Stack)
		
		return self
	end
	
	function Stack:Push(value)
		local size = self.Size
		size += 1
		self.Items[size] = value
		self.Size = size
	end
	
	function Stack:Pop()
		local size = self.Size
		local items = self.Items
		
		local topValue = items[size]
		self.Size = size - 1
		
		return topValue
	end
	
	shared.buildclass("Stack", Stack, Collection)
end

return Stack