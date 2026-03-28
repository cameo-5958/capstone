--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerUIServiceClient = require(ReplicatedStorage.Services.PlayerUI.PlayerUIServiceClient)

PlayerUIServiceClient.init()
