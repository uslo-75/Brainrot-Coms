local RemoteServerLoader = {}
local Loader = {}

local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EventsFolder = RP:WaitForChild("Events")
local ServerFolder = ServerStorage:WaitForChild("Server")

local function InitLoader()
	for _, module in ipairs(ServerFolder:GetDescendants()) do
		if module:IsA("ModuleScript") then
			if Loader[module.Name] then
				warn("[RemoteServerLoader] Duplicate module name detected:", module.Name, module:GetFullName())
			end

			local success, result = pcall(function()
				return require(module)
			end)

			if success then
				Loader[module.Name] = result
			else
				warn("[RemoteServerLoader] Failed to require module:", module:GetFullName(), result)
			end
		end
	end
end

local function IsValidPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

local function SafeInitModule(module, player, ...)
	if not IsValidPlayer(player) then
		return false, "Invalid player"
	end

	if type(module) ~= "table" or type(module.Init) ~= "function" then
		return false, "Missing Init"
	end

	return pcall(function(...)
		return table.pack(module:Init(player, ...))
	end, ...)
end

local function InitModule(remote, remoteType)
	local module = Loader[remote.Name]
	if not module then return end

	if remoteType == "RemoteEvents" then
		remote.OnServerEvent:Connect(function(player, ...)
			local success, result = SafeInitModule(module, player, ...)
			if not success then
				warn("[RemoteServerLoader] RemoteEvent failed:", remote:GetFullName(), result)
			end
		end)
	else
		remote.OnServerInvoke = function(player, ...)
			local success, result = SafeInitModule(module, player, ...)
			if not success then
				warn("[RemoteServerLoader] RemoteFunction failed:", remote:GetFullName(), result)
				return false, "Server error"
			end

			return table.unpack(result, 1, result.n)
		end
	end
end

function RemoteServerLoader:Init()
	InitLoader()

	for _, remote in ipairs(EventsFolder:GetDescendants()) do
		if remote:IsA("RemoteEvent") and remote.Parent.Name == "RemoteEvents" then
			InitModule(remote, "RemoteEvents")
		elseif remote:IsA("RemoteFunction") and remote.Parent.Name == "RemoteFonction" then
			InitModule(remote, "RemoteFonction")
		end
	end

	return true
end

return RemoteServerLoader
