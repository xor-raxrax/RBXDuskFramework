-- solution to manage classes that use runtime type information
-- for code that is expected to be transpiled

-- example of usage:
--[[
function MyBaseClass:constructor(rttiId : number, ...)
	RttiObject.constructor(self, rttiId)
end

-- getclassid must be at the end of chain
function MyClass:constructor(...)
	MyBaseClass.constructor(self, getclassid(MyClass))
end
--]]

local RttiObject = {} do

	function RttiObject:constructor(rttiId : number)
		self.RttiId = rttiId
	end

	function RttiObject:Is(rttiId : number) : boolean
		return self.RttiId == rttiId
	end

	function RttiObject:As<T>(rttiId : number) : T?
		if self.RttiId == rttiId then
			return (self :: T)
		else
			return nil
		end
	end

	function RttiObject:To<T>() : T
		return (self :: T)
	end

end