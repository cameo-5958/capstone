--!strict

-- Import the modifier from ModifierType
local __mod_type = require(script.Parent.ModifierType)
type Modifier = __mod_type.Modifier

-- Create the Modifier class
local Modifier = {}
Modifier.__index = Modifier

function Modifier.new(

): Modifier
    local self = setmetatable({}, Modifier)

    

    return self
end

return Modifier