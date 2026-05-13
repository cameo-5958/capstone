--!strict

-- Import the server loader
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerLoader = require(ReplicatedStorage.Services.Loader.ServerLoader)

-- Call the server loader's load method
ServerLoader.load()
