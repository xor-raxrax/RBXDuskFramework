local rootFolder = script

local Kernel = require(rootFolder.Dusk.Kernel)
shared.kernel = Kernel.new(rootFolder)

require(rootFolder.Main)

return nil