local Cache = shared.kernel:GetKernelClass("Cache")

local expecttype = shared.expecttype

local CCache = {} do
	
	function CCache:constructor(constructor, cleaner)
		expecttype(cleaner, "function")
		
		Cache.constructor(self, constructor)
		
		self._Cleaner = cleaner
	end
	
	local CacheStore = Cache.Store
	function CCache:Store(item)
		CacheStore(self, item)
		self._Cleaner(item)
	end
	
	shared.buildclass("CCache", CCache, Cache)
end

return CCache