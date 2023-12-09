local Cache = shared.kernel:GetKernelClass("Cache")

local expecttype = shared.expecttype

local CCache = {} do
	
	CCache.__base = {Cache}
	
	function CCache:constructor(constructor, cleaner)
		Cache.constructor(self, constructor)
		
		self._Cleaner = expecttype(cleaner, "function")
	end
	
	local CacheStore = Cache.Store
	function CCache:Store(item)
		CacheStore(self, item)
		self._Cleaner(item)
	end
	
end

return CCache