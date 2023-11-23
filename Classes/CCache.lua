local Cache = shared.kernel:GetKernelClass("Cache")

local expecttype = shared.expecttype

local CCache = {} do
	
	function CCache.new(constructor, cleaner)
		expecttype(cleaner, "function")
		
		local self = setmetatable(Cache.new(constructor), CCache)
		
		self._Cleaner = cleaner
		
		return self
	end
	
	local CacheStore = Cache.Store
	function CCache:Store(item)
		CacheStore(self, item)
		self._Cleaner(item)
	end
	
	shared.buildclass("CCache", CCache, Cache)
end

return CCache