local Collection = shared.kernel:GetKernelClass("Collection")
local Vector = shared.kernel:GetKernelClass("Vector")
local Stack = shared.kernel:GetKernelClass("Vector")
local Map = shared.kernel:GetKernelClass("Map")

local containers = {}

containers.Collection = Collection
containers.Vector = Vector
containers.Stack = Vector
containers.Map = Map

return containers