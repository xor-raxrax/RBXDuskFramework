local Cache = shared.kernel:GetKernelClass("Cache")

local expecttype = shared.expecttype

local CCache = {} do
	
	function CCache.new(constructor, cleaner)
		expecttype(cleaner, "function")
		
		local self = setmetatable(Cache.new(constructor), CCache)
		
		self._Cleaner = cleaner
		
		return self
	end
	
	local override = {}
	
	local CacheStore = Cache.Store
	function override:Store(item)
		CacheStore(self, item)
		self._Cleaner(item)
	end
	
	shared.buildclassoverride("CCache", CCache, override, Cache)
end

return CCache