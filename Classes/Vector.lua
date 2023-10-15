local Collection = shared.kernel:GetKernelClass("Collection")

local Vector = {} do
	
	function Vector.new()
		local self = setmetatable(Collection.new(), Vector)
		
		return self
	end
	
	function Vector:PushBack(item)
		local size = self.Size + 1
		self.Items[size] = item
		self.Size = size
	end
	
	function Vector:PopBack()
		local size = self.Size
		self.Items[size] = nil
		self.Size = size - 1
	end
	
	function Vector:Front(item)
		return self.Items[1]
	end
	
	function Vector:Back()
		return self.Items[self.Size]
	end
	
	shared.buildclass("Vector", Vector, Collection)
end

return Vector