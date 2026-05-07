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

	trail = Instance.new("Trail") :: Trail
	trail.Name = "WeaponTrail"
	trail.Attachment0 = attachment0
	trail.Attachment1 = attachment1
	trail.FaceCamera = false
	trail.Lifetime = if weaponClass == "Spear" then 0.07 else 0.09
	trail.MinLength = if weaponClass == "Spear" then 0.06 else 0.08
	trail.Brightness = 0
	trail.LightEmission = 0
	trail.LightInfluence = 1
	trail.Transparency = if weaponClass == "Spear"
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.4, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.35, 0.58),
			NumberSequenceKeypoint.new(1, 1),
		})
	trail.WidthScale = if weaponClass == "Spear"
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.45, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.65),
			NumberSequenceKeypoint.new(0.4, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
	trail.Color = if weaponClass == "Spear"
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(215, 220, 230)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 178, 195)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(125, 135, 155)),
		})
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 220, 225)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(175, 180, 190)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 125, 135)),
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

local function ClearManagedToolForSlot(entity: Entity, toolbarSlot: number)
	local existingWeapon = entity:GetToolbarWeapon(toolbarSlot)
	if existingWeapon and existingWeapon.ToolInstance then
		existingWeapon.ToolInstance:Destroy()
		existingWeapon:SetToolInstance(nil)
	end

	local backpack = GetBackpack(entity)
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:GetAttribute("ManagedByEquipmentService") and child:GetAttribute("ToolbarSlot") == toolbarSlot then
				child:Destroy()
			end
		end
	end

	for _, child in ipairs(entity.Character:GetChildren()) do
		if child:IsA("Tool") and child:GetAttribute("ManagedByEquipmentService") and child:GetAttribute("ToolbarSlot") == toolbarSlot then
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

local function BuildWeaponFromData(weaponPath: string, overrideData: { [string]: any }?): WeaponType
	local folder = ResolveWeaponFolder(weaponPath)
	local data = require(folder:WaitForChild("Data"))
	local toolTemplate = folder:FindFirstChild("Model") :: Tool?
	local weaponClass = if overrideData and type(overrideData.Class) == "string"
		then overrideData.Class
		elseif overrideData and type(overrideData.Type) == "string"
			then overrideData.Type
			else data.Type or data.Family or "Sword"
	local attackContext = if overrideData and type(overrideData.AttackContext) == "table"
		then overrideData.AttackContext
		else data.AttackContext or {}
	local attackProfile = BuildAttackProfile(data)
	if weaponClass == "Sword" or weaponClass == "Claymore" or weaponClass == "Spear" then
		attackContext = {}
		attackProfile = nil
	end

	local grantedStats = if overrideData and type(overrideData.GrantedStats) == "table"
		then overrideData.GrantedStats
		else data.__Stats or data.GrantedStats or {}
	local passiveDetails = if overrideData and type(overrideData.PassiveDetails) == "table"
		then overrideData.PassiveDetails
		elseif type(data.PassiveDetails) == "table"
			then data.PassiveDetails
			else nil

	return Weapon.new(
		if overrideData and type(overrideData.Name) == "string" then overrideData.Name else data.Name or weaponPath,
		if overrideData and type(overrideData.BaseDamage) == "number" then overrideData.BaseDamage else data.BaseDamage or 0,
		grantedStats :: any,
		if overrideData and type(overrideData.Weight) == "number" then overrideData.Weight else data.Weight or 0,
		data.WeaponAbility or data.RightClickAbility,
		data.RightClickAbility,
		weaponPath,
		attackProfile,
		toolTemplate,
		weaponClass,
		attackContext,
		data.WeaponPassive,
		if overrideData and type(overrideData.Rarity) == "string" then overrideData.Rarity else data.Rarity,
		passiveDetails
	)
end

function EquipmentServiceServer.CreateWeaponFromDatabase(weaponPath: string): WeaponType
	return BuildWeaponFromData(weaponPath, nil)
end

function EquipmentServiceServer.CreateWeaponFromSerialized(serializedWeapon: { [string]: any }): WeaponType
	local weaponPath = serializedWeapon.WeaponId
	assert(type(weaponPath) == "string" and weaponPath ~= "", "Serialized weapon is missing WeaponId")

	local weapon = BuildWeaponFromData(weaponPath, serializedWeapon)
	if type(serializedWeapon.InstanceId) == "string" and serializedWeapon.InstanceId ~= "" then
		weapon.UUID = serializedWeapon.InstanceId
	end

	return weapon
end

function EquipmentServiceServer.AssignToolbarWeapon(entity: Entity, weaponPath: string, slot: number): WeaponType
	local weapon = EquipmentServiceServer.CreateWeaponFromDatabase(weaponPath)
	weapon:SetOwner(entity)
	ClearManagedToolForSlot(entity, slot)
	entity:SetToolbarWeapon(slot, weapon)
	GiveToolClone(entity, weapon, slot)
	return weapon
end

function EquipmentServiceServer.AssignSerializedToolbarWeapon(entity: Entity, serializedWeapon: { [string]: any }, slot: number): WeaponType
	local weapon = EquipmentServiceServer.CreateWeaponFromSerialized(serializedWeapon)
	weapon:SetOwner(entity)
	ClearManagedToolForSlot(entity, slot)
	entity:SetToolbarWeapon(slot, weapon)
	GiveToolClone(entity, weapon, slot)
	return weapon
end

function EquipmentServiceServer.ClearToolbarSlot(entity: Entity, slot: number): ()
	ClearManagedToolForSlot(entity, slot)
	entity:SetToolbarWeapon(slot, nil)
end

function EquipmentServiceServer.SwapToolbarSlots(entity: Entity, firstSlot: number, secondSlot: number): ()
	if firstSlot == secondSlot then
		return
	end

	local firstWeapon = entity:GetToolbarWeapon(firstSlot)
	local secondWeapon = entity:GetToolbarWeapon(secondSlot)

	ClearManagedToolForSlot(entity, firstSlot)
	ClearManagedToolForSlot(entity, secondSlot)

	entity:SetToolbarWeapon(firstSlot, secondWeapon)
	entity:SetToolbarWeapon(secondSlot, firstWeapon)

	if secondWeapon then
		secondWeapon:SetOwner(entity)
		secondWeapon:SetToolInstance(nil)
		GiveToolClone(entity, secondWeapon, firstSlot)
	end

	if firstWeapon then
		firstWeapon:SetOwner(entity)
		firstWeapon:SetToolInstance(nil)
		GiveToolClone(entity, firstWeapon, secondSlot)
	end
end

function EquipmentServiceServer.RestoreToolbarTools(entity: Entity): ()
	ClearManagedTools(entity)

	for slot, weapon in ipairs(entity:GetToolbarWeapons()) do
		if weapon then
			weapon:SetOwner(entity)
			weapon:SetToolInstance(nil)
			GiveToolClone(entity, weapon, slot)
		end
	end
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

function EquipmentServiceServer.ApplyLoadout(entity: Entity, weaponPaths: { string })
	ClearManagedTools(entity)
	entity:SetEquippedIndex(nil)

	for slot, weaponPath in ipairs(weaponPaths) do
		EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, slot)
	end

	if #weaponPaths > 0 then
		entity:SetEquippedIndex(1)
	end
end

return table.freeze(EquipmentServiceServer)
