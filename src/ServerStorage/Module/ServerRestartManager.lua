local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

local MessageModule = require(game.ReplicatedStorage.Module.MessageModule)

local ServerRestartManager = {}

ServerRestartManager.GLOBAL_TOPIC = "GlobalServerRestartEvent"

local RETRY_DELAY = 2
local MAX_RETRY_COUNT = 3
local RESTART_MESSAGE = "Server restarting, reconnecting..."
local RESTART_KICK_MESSAGE = "Server restarted. Please rejoin."
local RESTART_COLOR = Color3.fromRGB(255, 120, 120)

local restartState = {
	Active = false,
	ExecutorName = nil,
	Scope = "Local",
	RetryCounts = {},
	PendingTeleport = {},
	Connections = {},
}

local function clearConnections()
	for _, connection in ipairs(restartState.Connections) do
		connection:Disconnect()
	end

	table.clear(restartState.Connections)
end

local function resetState()
	restartState.Active = false
	restartState.ExecutorName = nil
	restartState.Scope = "Local"
	table.clear(restartState.RetryCounts)
	table.clear(restartState.PendingTeleport)
	clearConnections()
	Workspace:SetAttribute("ServerRestarting", false)
end

local function createTeleportOptions()
	local teleportOptions = Instance.new("TeleportOptions")
	teleportOptions:SetTeleportData({
		ServerRestart = true,
		RequestedAt = os.time(),
		Scope = restartState.Scope,
		ExecutorName = restartState.ExecutorName or "Console",
	})

	return teleportOptions
end

local function announceRestart()
	local scopeLabel = restartState.Scope == "Global" and "global" or "local"
	local executorName = restartState.ExecutorName or "Console"
	local message = `{executorName} started a {scopeLabel} server restart.`

	for _, player in ipairs(Players:GetPlayers()) do
		MessageModule:SendMessage(player, message, 4, RESTART_COLOR)
	end
end

local function kickPlayer(player)
	if player and player.Parent == Players then
		player:Kick(RESTART_KICK_MESSAGE)
	end
end

local function scheduleTeleport(player)
	if not restartState.Active or not (player and player.Parent == Players) then
		return
	end

	if restartState.PendingTeleport[player] then
		return
	end

	restartState.PendingTeleport[player] = true

	task.spawn(function()
		task.wait(0.25)

		if not restartState.Active or not (player and player.Parent == Players) then
			restartState.PendingTeleport[player] = nil
			return
		end

		local retryCount = (restartState.RetryCounts[player] or 0) + 1
		restartState.RetryCounts[player] = retryCount

		local success = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, createTeleportOptions())
		end)

		restartState.PendingTeleport[player] = nil

		if success then
			return
		end

		if retryCount >= MAX_RETRY_COUNT then
			kickPlayer(player)
			return
		end

		task.delay(RETRY_DELAY, function()
			scheduleTeleport(player)
		end)
	end)
end

local function teleportPlayers(playersToTeleport)
	local batch = {}

	for _, player in ipairs(playersToTeleport or {}) do
		if player and player.Parent == Players then
			table.insert(batch, player)
		end
	end

	if #batch == 0 then
		return true
	end

	local success = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, batch, createTeleportOptions())
	end)

	if success then
		return true
	end

	for _, player in ipairs(batch) do
		scheduleTeleport(player)
	end

	return false
end

local function watchRestartState()
	table.insert(restartState.Connections, Players.PlayerAdded:Connect(function(player)
		MessageModule:SendMessage(player, RESTART_MESSAGE, 3, RESTART_COLOR)
		scheduleTeleport(player)
	end))

	table.insert(restartState.Connections, Players.PlayerRemoving:Connect(function(player)
		restartState.RetryCounts[player] = nil
		restartState.PendingTeleport[player] = nil

		task.defer(function()
			if restartState.Active and #Players:GetPlayers() == 0 then
				resetState()
			end
		end)
	end))

	table.insert(restartState.Connections, TeleportService.TeleportInitFailed:Connect(function(player)
		if restartState.Active then
			scheduleTeleport(player)
		end
	end))
end

function ServerRestartManager:IsRestarting()
	return restartState.Active
end

function ServerRestartManager:RestartLocal(executorName, scope)
	if restartState.Active then
		return false, "A server restart is already in progress."
	end

	if RunService:IsStudio() then
		return false, "Server restart cannot be tested in Roblox Studio."
	end

	restartState.Active = true
	restartState.ExecutorName = executorName or "Console"
	restartState.Scope = scope == "Global" and "Global" or "Local"
	Workspace:SetAttribute("ServerRestarting", true)

	watchRestartState()
	announceRestart()
	teleportPlayers(Players:GetPlayers())

	return true, `Server restart started ({restartState.Scope}).`
end

return ServerRestartManager
