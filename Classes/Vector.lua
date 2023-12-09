local Collection = shared.kernel:GetKernelClass("Collection")

local Vector = {} do
	
	Vector.__base = {Collection}
	
	function Vector:constructor()
		Collection.constructor(self)
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
	
end

return Vector