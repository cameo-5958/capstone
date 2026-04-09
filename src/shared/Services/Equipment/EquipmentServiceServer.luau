--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapon = require(ReplicatedStorage.Classes.Weapon.Weapon)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type WeaponType = WeaponTypes.Weapon

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

local EquipmentServiceServer = {}

local function ResolveWeaponFolder(weaponPath: string): Instance
	local current: Instance = WeaponsDatabase
	for _, part in ipairs(weaponPath:split(".")) do
		current = current:WaitForChild(part)
	end

	return current
end

local function BuildAttackProfile(data): WeaponTypes.AttackProfile?
	local configuredProfile = data.AttackProfile
	if not configuredProfile then
		return nil
	end

	local profile = {
		AnimationId = "",
		Windup = 0.12,
		ActiveDuration = 0.16,
		Recovery = 0.22,
		Cooldown = 0.55,
		HitReset = 0.12,
		HitboxSize = Vector3.new(3.25, 4.5, 7.5),
		HitboxOffset = CFrame.new(0, 0, -3.75),
	}

	if configuredProfile then
		for key, value in pairs(configuredProfile) do
			profile[key] = value
		end
	end

	return profile
end

local function GetBackpack(entity: Entity): Backpack?
	local player = Players:GetPlayerFromCharacter(entity.Character)
	if not player then
		return nil
	end

	return player:FindFirstChildOfClass("Backpack")
end

local function EnsureTrailAttachment(handle: BasePart, name: string, position: Vector3): Attachment
	local attachment = handle:FindFirstChild(name)
	if attachment and attachment:IsA("Attachment") then
		attachment.Position = position
		return attachment
	end

	attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = position
	attachment.Parent = handle
	return attachment
end

local function GetTrailEndpoints(handle: BasePart): (Vector3, Vector3)
	local size = handle.Size
	local mesh = handle:FindFirstChildWhichIsA("DataModelMesh")
	if mesh then
		size = Vector3.new(
			math.max(size.X, math.abs(mesh.Scale.X)),
			math.max(size.Y, math.abs(mesh.Scale.Y)),
			math.max(size.Z, math.abs(mesh.Scale.Z))
		)
	end

	local xExtent = size.X * 0.48
	local yExtent = size.Y * 0.48
	local zExtent = size.Z * 0.48
	local axes = {
		{ Name = "X", Size = size.X, Extent = xExtent },
		{ Name = "Y", Size = size.Y, Extent = yExtent },
		{ Name = "Z", Size = size.Z, Extent = zExtent },
	}
	table.sort(axes, function(left, right)
		return left.Size > right.Size
	end)

	local primaryAxis = axes[1]
	local secondaryAxis = axes[2]
	local tertiaryAxis = axes[3]

	-- For flat, elongated blades, the trail looks better spanning the blade face
	-- instead of the full blade length.
	local chosenAxis = primaryAxis
	if primaryAxis.Size >= (secondaryAxis.Size * 1.2) and tertiaryAxis.Size <= (secondaryAxis.Size * 0.6) then
		chosenAxis = secondaryAxis
	end

	if chosenAxis.Name == "Z" then
		return Vector3.new(0, 0, -chosenAxis.Extent), Vector3.new(0, 0, chosenAxis.Extent)
	elseif chosenAxis.Name == "Y" then
		return Vector3.new(0, -chosenAxis.Extent, 0), Vector3.new(0, chosenAxis.Extent, 0)
	else
		return Vector3.new(-chosenAxis.Extent, 0, 0), Vector3.new(chosenAxis.Extent, 0, 0)
	end
end

local function EnsureWeaponTrail(tool: Tool, weaponClass: string?)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	if weaponClass == "Staff" then
		local existingTrail = handle:FindFirstChild("WeaponTrail")
		if existingTrail and existingTrail:IsA("Trail") then
			existingTrail.Enabled = false
		end
		return
	end

	local endpoint0, endpoint1 = GetTrailEndpoints(handle)
	local attachment0 = EnsureTrailAttachment(handle, "TrailAttachment0", endpoint0)
	local attachment1 = EnsureTrailAttachment(handle, "TrailAttachment1", endpoint1)

	local trail = handle:FindFirstChild("WeaponTrail")
	if trail and trail:IsA("Trail") then
		trail.Attachment0 = attachment0
		trail.Attachment1 = attachment1
		return
	end

	trail = Instance.new("Trail")
	trail.Name = "WeaponTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.FaceCamera = false
	trail.Lifetime = if weaponClass == "Spear" then 0.09 else 0.14
	trail.MinLength = if weaponClass == "Spear" then 0.08 else 0.12
	trail.Brightness = if weaponClass == "Spear" then 1.75 else 3
	trail.LightEmission = if weaponClass == "Spear" then 0.65 else 1
	trail.LightInfluence = 0
	trail.Transparency = if weaponClass == "Spear"
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.12),
			NumberSequenceKeypoint.new(0.45, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.02),
			NumberSequenceKeypoint.new(0.35, 0.08),
			NumberSequenceKeypoint.new(1, 1),
		})
	trail.WidthScale = if weaponClass == "Spear"
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.1),
			NumberSequenceKeypoint.new(0.45, 0.75),
			NumberSequenceKeypoint.new(1, 0.2),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.8),
			NumberSequenceKeypoint.new(0.45, 1.1),
			NumberSequenceKeypoint.new(1, 0.3),
		})
	trail.Color = if weaponClass == "Spear"
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 245, 245)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 225, 235)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 180, 200)),
		})
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 245, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 120, 90)),
		})
	trail.Enabled = true
	trail.Parent = handle
end

local function ClearManagedTools(entity: Entity)
	local backpack = GetBackpack(entity)
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ManagedByEquipmentService") then
				child:Destroy()
			end
		end
	end

	for _, child in ipairs(entity.Character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("ManagedByEquipmentService") then
			child:Destroy()
		end
	end
end

local function GiveToolClone(entity: Entity, weapon: WeaponType, toolbarSlot: number?)
	local tool = weapon:CloneTool()
	if not tool then
		return nil
	end

	EnsureWeaponTrail(tool, weapon.Class)

	tool:SetAttribute("ManagedByEquipmentService", true)
	tool:SetAttribute("WeaponId", weapon.WeaponId)
	if toolbarSlot then
		tool:SetAttribute("ToolbarSlot", toolbarSlot)
	end

	local backpack = GetBackpack(entity)
	if backpack then
		tool.Parent = backpack
	else
		tool.Parent = entity.Character
	end

	weapon:SetToolInstance(tool)
	return tool
end

function EquipmentServiceServer.CreateWeaponFromDatabase(weaponPath: string): WeaponType
	local folder = ResolveWeaponFolder(weaponPath)
	local data = require(folder:WaitForChild("Data"))
	local toolTemplate = folder:FindFirstChild("Model") :: Tool?
	local weaponClass = data.Type or data.Family or "Sword"
	local attackContext = data.AttackContext or {}
	local attackProfile = BuildAttackProfile(data)
	if weaponClass == "Sword" or weaponClass == "Claymore" or weaponClass == "Spear" then
		attackContext = {}
		attackProfile = nil
	end

	return Weapon.new(
		data.Name or weaponPath,
		data.BaseDamage or 0,
		data.__Stats or data.GrantedStats or {},
		data.Weight or 0,
		data.WeaponAbility or data.RightClickAbility,
		data.RightClickAbility,
		weaponPath,
		attackProfile,
		toolTemplate,
		weaponClass,
		attackContext,
		data.WeaponPassive
	)
end

function EquipmentServiceServer.AssignToolbarWeapon(entity: Entity, weaponPath: string, slot: number): WeaponType
	local weapon = EquipmentServiceServer.CreateWeaponFromDatabase(weaponPath)
	weapon:SetOwner(entity)
	entity:SetToolbarWeapon(slot, weapon)
	GiveToolClone(entity, weapon, slot)
	return weapon
end

function EquipmentServiceServer.AssignEquippedWeapon(entity: Entity, weaponPath: string): WeaponType
	for slot = 1, 4 do
		local weapon = entity:GetToolbarWeapon(slot)
		if weapon and weapon.WeaponId == weaponPath then
			entity:SetEquippedIndex(slot)
			return weapon
		end
	end

	local weapon = EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, 1)
	entity:SetEquippedIndex(1)
	return weapon
end

function EquipmentServiceServer.GiveDefaultLoadout(entity: Entity)
	ClearManagedTools(entity)
	entity:SetEquippedIndex(nil)

	local defaultWeapons = {
		"Bone.Sword.Bone_Sword_1",
		"Bow1",
		"Skeletal.Lance",
		"TestWeapon",
	}

	for slot, weaponPath in ipairs(defaultWeapons) do
		EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, slot)
	end

	entity:SetEquippedIndex(1)
end

return table.freeze(EquipmentServiceServer)


