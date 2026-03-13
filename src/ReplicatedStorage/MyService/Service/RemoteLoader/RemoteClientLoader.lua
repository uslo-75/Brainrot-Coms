local RemoteClientLoader = {}
local Loader = {}

local Players = game:GetService("Players")
local RP = game:GetService("ReplicatedStorage")

local ClientFolder = RP:WaitForChild("Client")
local EventsFolder = RP:WaitForChild("Events")

local function InitLoader()
	for _, module in ipairs(ClientFolder:GetDescendants()) do
		if module:IsA("ModuleScript") then

			local success, result = pcall(function()
				return require(module)
			end)

			if success then
				Loader[module.Name] = result
			else
				warn("[Loader Error] Module:", module.Name, "->", result)
			end

		end
	end
end

local function InitModule(remote, remoteType, player)
	local module = Loader[remote.Name]
	if not module then return end

	if remoteType == "RemoteEvents" then
		remote.OnClientEvent:Connect(function(...)--OnClientEvent
			if module.Init then
				module:Init(player, ...)
			end
		end)
	else
		remote.OnClientInvoke = function(...)
			if module.Init then--OnClientInvoke
				return module:Init(player, ...)
			end
		end
	end
end

function RemoteClientLoader:Init()
	local player = Players.LocalPlayer

	InitLoader()

	for _, remote in ipairs(EventsFolder:GetDescendants()) do
		if remote:IsA("RemoteEvent") and remote.Parent.Name == "RemoteEvents" then
			InitModule(remote, "RemoteEvents", player)
		elseif remote:IsA("RemoteFunction") and remote.Parent.Name == "RemoteFonction" then
			InitModule(remote, "RemoteFonction", player)
		end
	end

	return true
end

return RemoteClientLoader
