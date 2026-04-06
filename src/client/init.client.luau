--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerUIServiceClient = require(ReplicatedStorage.Services.PlayerUI.PlayerUIServiceClient)
local _ProjectileServiceClient = require(ReplicatedStorage.Services.Projectile.ProjectileServiceClient)

PlayerUIServiceClient.init()
