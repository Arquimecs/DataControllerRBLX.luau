local DataController = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Server = ServerStorage:FindFirstChild("Server")
local Data = Server:FindFirstChild("Data")
local Components = Server:FindFirstChild("Components")

local ProfileStore = require(Data.ProfileStore)
local Template = require(Data.Template)

local PlayerDataFolder = ServerStorage:FindFirstChild("PlayerData")
local DataTemplate = PlayerDataFolder:FindFirstChild("Template")


function DataController._GetStoreName()
	return RunService:IsStudio() and "Test" or "Live"
end

DataController.Profiles = {}

local PlayerStore = ProfileStore.New(DataController._GetStoreName(), Template)

function DataController:BootStats(player, profile)
	
	player:SetAttribute("CurrentLinker", "None")
	player:SetAttribute("Link", "None")

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local Coins = Instance.new("StringValue")
	Coins.Name = "Coins"
	Coins.Value = profile.Data.Coins
	Coins.Parent = leaderstats
	
	print(DataController.Profiles[player])
	
	
end

function DataController:UpdateFolder(player: Player, profile: typeof(PlayerStore:StartSessionAsync()))
	if not profile then
		warn("No profile found for", player.Name)
		return
	end

	local Folder = PlayerDataFolder:FindFirstChild(player.Name)
	if not Folder then
		warn("Player data folder not found for", player.Name)
		return
	end

	local Data = Folder:FindFirstChild("Data")
	if not Data then
		warn("Data container not found for", player.Name)
		return
	end

	local containers = {
		Settings = Data:FindFirstChild("Settings"),
		UnlockedWorlds = Data:FindFirstChild("UnlockedWorlds"),
		OwnedGamepasses = Data:FindFirstChild("OwnedGamepasses"),
		OwnedTrails = Data:FindFirstChild("OwnedTrails"),
		OwnedSkins = Data:FindFirstChild("OwnedSkins"),
		OwnedFolds = Data:FindFirstChild("OwnedFolds"),
		Potions = Data:FindFirstChild("Potions")
	}

	if containers.Settings then
		for setting, value in pairs(profile.Data.Settings) do
			local settingObj = containers.Settings:FindFirstChild(setting)
			if settingObj then
				settingObj.Value = value
			else
				warn("Missing setting:", setting, "for", player.Name)
			end
		end
	end

	if containers.UnlockedWorlds then
		for world, value in pairs(profile.Data.UnlockedWorlds) do
			local worldObj = containers.UnlockedWorlds:FindFirstChild(world)
			if worldObj then
				worldObj.Value = value
			else
				warn("Missing world entry:", world, "for", player.Name)
			end
		end
	end

	local updateMap = {
		OwnedGamepasses = "gamepass",
		OwnedTrails = "trail",
		OwnedSkins = "skin",
		OwnedFolds = "fold",
		Potions = "potion"
	}

	for containerName, entryType in pairs(updateMap) do
		local container = containers[containerName]
		if container then
			for entry, value in pairs(profile.Data[containerName]) do
				local entryObj = container:FindFirstChild(entry)
				if entryObj then
					entryObj.Value = value
				else
					warn("Missing "..entryType..":", entry, "for", player.Name)
				end
			end
		end
	end
end

function DataController:Initialize()
	Players.PlayerAdded:Connect(function(player)
		local profile = PlayerStore:StartSessionAsync("Player_"..player.UserId, {
			Cancel = function()
				return player.Parent ~= Players
			end
		})
		local PlayerFolders = {}
		if not profile then
			player:Kick("Data Error Occurred. Please Rejoin.")
			return
		end

		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			DataController.Profiles[player] = nil
		end)
		
		if player.Parent == Players then
			
			PlayerFolders[player.Name] = DataTemplate:Clone()
			PlayerFolders[player.Name].Parent = PlayerDataFolder
			PlayerFolders[player.Name].Name = player.Name
			print(PlayerFolders[player.Name]:GetChildren())
			DataController.Profiles[player] = profile
			
			DataController:UpdateFolder(player, profile)
			
			DataController:BootStats(player, profile)
		else
			profile:EndSession()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local profile = DataController.Profiles[player]
		if not profile then return end

		local Folder = PlayerDataFolder:FindFirstChild(player.Name)
		if not Folder then return end

		local Data = Folder:FindFirstChild("Data")
		local leaderstats = Folder:FindFirstChild("leaderstats")
		if not Data then return end

		profile.Data.Coins = leaderstats.Coins.Value
		profile.Data.EquippedFold = Data.EquippedFold.Value
		profile.Data.EquippedSkin = Data.EquippedSkin.Value
		profile.Data.EquippedTrail = Data.EquippedTrail.Value


		local containers = {
			Settings = Data.Settings,
			UnlockedWorlds = Data.UnlockedWorlds,
			OwnedFolds = Data.OwnedFolds,
			OwnedSkins = Data.OwnedSkins,
			OwnedTrails = Data.OwnedTrails,
			OwnedGamepasses = Data.OwnedGamepasses,
			Potions = Data.Potions
		}

		for containerName, container in pairs(containers) do
			if container then
				for entry, _ in pairs(profile.Data[containerName]) do
					local entryObj = container:FindFirstChild(entry)
					if entryObj then
						profile.Data[containerName][entry] = entryObj.Value
					else
						warn("Missing entry:", entry, "in", containerName, "for", player.Name)
					end
				end
			end
		end

		profile:EndSession() 
		print("Session ended for", player.Name)
	end)
end

return DataController
