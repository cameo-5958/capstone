--!strict

local endpoint = script.Parent:FindFirstChild("WeaponEndpoint")
if not endpoint then
	endpoint = Instance.new("RemoteEvent")
	endpoint.Name = "WeaponEndpoint"
	endpoint.Parent = script.Parent
end

local API = endpoint :: RemoteEvent

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapon = require(ReplicatedStorage.Classes.Weapon.Weapon)
local EntityTypes = require(ReplicatedStorage.Classes.Entity.EntityTypes)

type Entity = EntityTypes.Entity

local WeaponServiceServer = {}

local PlayerEntities: { [Player]: Entity } = {}

local function createStarterWeapon()
	return Weapon.new(
		"Starter Sword",
		12,
		{
			Strength = 4,
			PhysicalAttack = 6,
			Speed = 1,
		},
		function(_, entity: Entity)
			local restored = math.min(entity:GetStat("MaxHealth"), entity:GetStat("Health") + 15)
			entity:SetStat("Health", restored)
		end,
		"StarterSword"
	)
end

function WeaponServiceServer.RegisterEntity(player: Player, entity: Entity): ()
	PlayerEntities[player] = entity
end

function WeaponServiceServer.UnregisterEntity(player: Player): ()
	PlayerEntities[player] = nil
end

function WeaponServiceServer.CreateStarterWeapon()
	return createStarterWeapon()
end

API.OnServerEvent:Connect(function(player: Player, action: string, payload: { [string]: any }?)
	if action ~= "UseAbility" then
		return
	end

	local entity = PlayerEntities[player]
	if not entity then
		return
	end

	local equipped = entity:GetEquippedWeapon()
	if not equipped then
		return
	end

	equipped:UseRightClick(entity, payload or {})
end)

return table.freeze(WeaponServiceServer)
