--!strict

local PrefabTypes = require(script.Parent.PrefabTypes)
local PrefabRegistry = require(script.Parent.PrefabRegistry)

type PrefabBuildContext = PrefabTypes.PrefabBuildContext

local PrefabRenderer = {}

function PrefabRenderer.Render(tag: string, parent: Instance, context: PrefabBuildContext): Model?
	local definition = PrefabRegistry.GetById(tag)
	if not definition then
		return nil
	end

	local ok, result = pcall(function()
		return definition.Build(parent, context)
	end)
	if not ok then
		warn(string.format("[PrefabRenderer] Failed to render '%s': %s", tag, tostring(result)))
		return nil
	end

	local model = result :: Model
	model:SetAttribute("StructureTag", tag)
	return model
end

return table.freeze(PrefabRenderer)
