local rootFolder = script
local classesFolder = rootFolder.Classes
local librariesFolder = rootFolder.Libraries
local main = rootFolder.Main

local Kernel = require(rootFolder.Dusk.Kernel)

local kernel = Kernel.new({classesFolder}, {librariesFolder}, main)
shared.kernel = kernel
kernel:_InvokeMain()

return nil