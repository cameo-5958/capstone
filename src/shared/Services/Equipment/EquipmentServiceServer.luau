--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Weapon = require(ReplicatedStorage.Classes.Weapon.Weapon)
local WeaponTypes = require(ReplicatedStorage.Classes.Weapon.WeaponTypes)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity
type WeaponType = WeaponTypes.Weapon

local WeaponsDatabase = ReplicatedStorage:WaitForChild("Database"):WaitForChild("Weapons")

local MANAGED_VISUAL_ATTRIBUTE = "ManagedByEquipmentService"

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

	for key, value in pairs(configuredProfile) do
		profile[key] = value
	end

	return profile
end

local function ResolveWeaponVisualTemplate(folder: Instance): Instance?
	local template = folder:FindFirstChild("Model")
	if template then
		return template
	end

	for _, child in ipairs(folder:GetChildren()) do
		if
			child.Name ~= "Data"
			and (child:IsA("Tool") or child:IsA("Model") or child:IsA("BasePart") or child:IsA("Folder"))
		then
			return child
		end
	end

	return nil
end

local function ResolveWeaponGripCFrame(visualTemplate: Instance?, data: { [string]: any }): CFrame
	if visualTemplate and visualTemplate:IsA("Tool") then
		return visualTemplate.Grip
	end

	local configuredGrip = data.GripCFrame or data.Grip
	if typeof(configuredGrip) == "CFrame" then
		return configuredGrip
	end

	return CFrame.new()
end

local function ClearLegacyManagedVisuals(entity: Entity)
	local character = entity.Character
	if character and character:IsA("Model") then
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:GetAttribute(MANAGED_VISUAL_ATTRIBUTE) == true then
				descendant:Destroy()
			end
		end
	end

	for slot = 1, 4 do
		local weapon = entity:GetToolbarWeapon(slot)
		if weapon then
			weapon:SetVisualInstance(nil)
		end
	end
end

local function FindRightHandPart(character: Model): BasePart?
	local names = { "RightHand", "Right Arm", "RightLowerArm", "RightUpperArm" }
	for _, name in ipairs(names) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function FindRightGripAttachment(handPart: BasePart): Attachment?
	local attachmentNames = { "RightGripAttachment", "RightGrip" }
	for _, name in ipairs(attachmentNames) do
		local attachment = handPart:FindFirstChild(name)
		if attachment and attachment:IsA("Attachment") then
			return attachment
		end
	end

	for _, child in ipairs(handPart:GetChildren()) do
		if child:IsA("Attachment") and string.find(child.Name, "Grip") then
			return child
		end
	end

	return nil
end

local function FindDisplayPart(instance: Instance): BasePart?
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Tool") then
		local handle = instance:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			return handle
		end
	end

	if instance:IsA("Model") then
		if instance.PrimaryPart and instance.PrimaryPart:IsA("BasePart") then
			return instance.PrimaryPart
		end

		for _, descendant in ipairs(instance:GetDescendants()) do
			if descendant:IsA("BasePart") then
				return descendant
			end
		end
	end

	return nil
end

local function MarkManagedVisual(instance: Instance)
	instance:SetAttribute(MANAGED_VISUAL_ATTRIBUTE, true)
	for _, descendant in ipairs(instance:GetDescendants()) do
		descendant:SetAttribute(MANAGED_VISUAL_ATTRIBUTE, true)
	end
end

local function ConvertToolVisualToModel(tool: Tool): Model
	local model = Instance.new("Model")
	model.Name = tool.Name

	local primaryPart = tool:FindFirstChild("Handle")

	for _, child in ipairs(tool:GetChildren()) do
		child.Parent = model
	end

	if primaryPart and primaryPart:IsA("BasePart") then
		model.PrimaryPart = primaryPart
	end

	tool:Destroy()
	return model
end

local function NormalizeEquippedVisualClone(template: Instance): Instance
	local visual = template:Clone()
	if visual:IsA("Tool") then
		return ConvertToolVisualToModel(visual)
	end

	return visual
end

local function AttachVisualToHand(character: Model, visual: Instance, gripCFrame: CFrame)
	local handPart = FindRightHandPart(character)
	if not handPart then
		return
	end

	local displayPart = FindDisplayPart(visual)
	if not displayPart then
		return
	end

	if visual:IsA("Model") and not visual.PrimaryPart then
		visual.PrimaryPart = displayPart
	end

	local gripAttachment = FindRightGripAttachment(handPart)
	local handGripOffset = if gripAttachment then gripAttachment.CFrame else CFrame.new()
	local toolGripOffset = gripCFrame
	local handleCFrame = handPart.CFrame * handGripOffset * toolGripOffset:Inverse()

	displayPart.CFrame = handleCFrame

	for _, descendant in ipairs(visual:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		end
	end

	if displayPart:IsA("BasePart") then
		local weld = Instance.new("Weld")
		weld.Name = "EquippedWeaponWeld"
		weld.Part0 = handPart
		weld.Part1 = displayPart
		weld.C0 = handGripOffset
		weld.C1 = toolGripOffset
		weld.Parent = handPart
	end
end

local function BuildWeaponFromData(weaponPath: string, overrideData: { [string]: any }?): WeaponType
	local folder = ResolveWeaponFolder(weaponPath)
	local data = require(folder:WaitForChild("Data"))
	local visualTemplate = ResolveWeaponVisualTemplate(folder)
	local gripCFrame = ResolveWeaponGripCFrame(visualTemplate, data)
	local weaponClass = if overrideData and type(overrideData.Class) == "string"
		then overrideData.Class
		elseif overrideData and type(overrideData.Type) == "string" then overrideData.Type
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
		elseif type(data.PassiveDetails) == "table" then data.PassiveDetails
		else nil

	return Weapon.new(
		if overrideData and type(overrideData.Name) == "string" then overrideData.Name else data.Name or weaponPath,
		if overrideData and type(overrideData.BaseDamage) == "number"
			then overrideData.BaseDamage
			else data.BaseDamage or 0,
		grantedStats :: any,
		if overrideData and type(overrideData.Weight) == "number" then overrideData.Weight else data.Weight or 0,
		data.WeaponAbility or data.RightClickAbility,
		data.RightClickAbility,
		weaponPath,
		attackProfile,
		visualTemplate,
		gripCFrame,
		weaponClass,
		attackContext,
		data.WeaponPassive,
		if overrideData and type(overrideData.Rarity) == "string" then overrideData.Rarity else data.Rarity,
		passiveDetails,
		data.Cooldown
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
	entity:SetToolbarWeapon(slot, weapon)
	return weapon
end

function EquipmentServiceServer.AssignSerializedToolbarWeapon(
	entity: Entity,
	serializedWeapon: { [string]: any },
	slot: number
): WeaponType
	local weapon = EquipmentServiceServer.CreateWeaponFromSerialized(serializedWeapon)
	weapon:SetOwner(entity)
	entity:SetToolbarWeapon(slot, weapon)
	return weapon
end

function EquipmentServiceServer.ClearToolbarSlot(entity: Entity, slot: number): ()
	ClearLegacyManagedVisuals(entity)
	entity:SetToolbarWeapon(slot, nil)
end

function EquipmentServiceServer.SwapToolbarSlots(entity: Entity, firstSlot: number, secondSlot: number): ()
	if firstSlot == secondSlot then
		return
	end

	local firstWeapon = entity:GetToolbarWeapon(firstSlot)
	local secondWeapon = entity:GetToolbarWeapon(secondSlot)

	entity:SetToolbarWeapon(firstSlot, secondWeapon)
	entity:SetToolbarWeapon(secondSlot, firstWeapon)

	if secondWeapon then
		secondWeapon:SetOwner(entity)
	end

	if firstWeapon then
		firstWeapon:SetOwner(entity)
	end
end

function EquipmentServiceServer.RestoreEquippedWeaponVisual(entity: Entity): ()
	ClearLegacyManagedVisuals(entity)

	local equippedWeapon = entity:GetEquippedWeapon()
	if not equippedWeapon then
		return
	end

	local template = equippedWeapon.VisualTemplate
	if not template then
		return
	end

	local character = entity.Character
	if not character or not character:IsA("Model") then
		return
	end

	local visual = NormalizeEquippedVisualClone(template)
	visual.Parent = character
	MarkManagedVisual(visual)
	equippedWeapon:SetVisualInstance(visual)

	AttachVisualToHand(character, visual, equippedWeapon.GripCFrame or CFrame.new())
end

function EquipmentServiceServer.AssignEquippedWeapon(entity: Entity, weaponPath: string): WeaponType
	for slot = 1, 4 do
		local weapon = entity:GetToolbarWeapon(slot)
		if weapon and weapon.WeaponId == weaponPath then
			entity:SetEquippedIndex(slot)
			ClearLegacyManagedVisuals(entity)
			return weapon
		end
	end

	local weapon = EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, 1)
	entity:SetEquippedIndex(1)
	ClearLegacyManagedVisuals(entity)
	return weapon
end

function EquipmentServiceServer.ApplyLoadout(entity: Entity, weaponPaths: { string })
	ClearLegacyManagedVisuals(entity)
	entity:SetEquippedIndex(nil)

	for slot, weaponPath in ipairs(weaponPaths) do
		EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, slot)
	end

	if #weaponPaths > 0 then
		entity:SetEquippedIndex(1)
	end
end

return table.freeze(EquipmentServiceServer)
