local rootFolder = script
local classesFolder = rootFolder.Classes
local librariesFolder = rootFolder.Libraries
local main = rootFolder.Main

local Kernel = require(rootFolder.Dusk.Kernel)

shared.kernel = Kernel.new(classesFolder, librariesFolder, main)

require(main)

return nil