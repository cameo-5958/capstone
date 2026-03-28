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
	local attackContext = data.AttackContext
	if not attackContext then
		return nil
	end

	local swordRange = attackContext.SwingRange or 6
	local hitRange = swordRange + 1.5
	return {
		AnimationId = "",
		Windup = 0.12,
		ActiveDuration = 0.16,
		Recovery = 0.22,
		Cooldown = 0.55,
		HitReset = 0.12,
		HitboxSize = Vector3.new(3.25, 4.5, hitRange),
		HitboxOffset = CFrame.new(0, 0, -(hitRange * 0.5)),
	}
end

local function GetBackpack(entity: Entity): Backpack?
	local player = Players:GetPlayerFromCharacter(entity.Character)
	if not player then
		return nil
	end

	return player:FindFirstChildOfClass("Backpack")
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

	return Weapon.new(
		data.Name or weaponPath,
		data.BaseDamage or 0,
		data.__Stats or data.GrantedStats or {},
		data.Weight or 0,
		data.WeaponAbility or data.RightClickAbility,
		data.RightClickAbility,
		weaponPath,
		BuildAttackProfile(data),
		toolTemplate,
		data.Type or data.Family or "Sword",
		data.AttackContext or {},
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
		"Sword1",
		"Sword2",
		"Sword3",
		"TestWeapon",
	}

	for slot, weaponPath in ipairs(defaultWeapons) do
		EquipmentServiceServer.AssignToolbarWeapon(entity, weaponPath, slot)
	end

	entity:SetEquippedIndex(1)
end

return table.freeze(EquipmentServiceServer)



