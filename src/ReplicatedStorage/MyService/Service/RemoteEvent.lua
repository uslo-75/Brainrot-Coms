local RemoteEvent = {}
RemoteEvent.Remotes = {}

local RP = game:GetService("ReplicatedStorage")
local RS = game:GetService("RunService")
local EventsFolder = RP:WaitForChild("Events")

local function findRemote(folder, path)
	if not folder then return nil end

	if path:find("/") then
		local current = folder
		for part in path:gmatch("[^/]+") do
			current = current:FindFirstChild(part)
			if not current then return nil end
		end
		return current
	end

	local found = folder:FindFirstChild(path, true)
	return found
end

function RemoteEvent:FireServer(name, ...)
	if not RS:IsClient() then return end
	local remote = findRemote(EventsFolder:WaitForChild("RemoteEvents"), name)
	if remote then
		remote:FireServer(...)
	else
		warn("FireServer '" .. name .. "' not found on client")
	end
end

function RemoteEvent:FireClient(name, player, ...)
	if not RS:IsServer() then return end
	local remote = findRemote(EventsFolder:WaitForChild("RemoteEvents"), name)
	if remote then
		remote:FireClient(player, ...)
	else
		warn("FireClient '" .. name .. "' not found on server")
	end
end

function RemoteEvent:FireAllClients(name, ...)
	if not RS:IsServer() then return end
	local remote = findRemote(EventsFolder:WaitForChild("RemoteEvents"), name)
	if remote then
		remote:FireAllClients(...)
	else
		warn("FireAllClients '" .. name .. "' not found on server")
	end
end

function RemoteEvent:InvokeServer(name, ...)
	if not RS:IsClient() then return end
	if name and type(name) ~= "string" then return end
	local remote = findRemote(EventsFolder:WaitForChild("RemoteFonction"), name)
	

	
	if remote then
		return remote:InvokeServer(...)
	else
		warn("InvokeServer '" .. name .. "' not found on server")
	end
end

function RemoteEvent:InvokeClient(name, ...)
	if not RS:IsServer() then 
		return {}
	end

	local remote = findRemote(EventsFolder:WaitForChild("RemoteFonction"), name)

	if not remote then
		warn("InvokeClient '" .. name .. "' not found on server")
		return {}
	end

	local success, result = pcall(remote.InvokeClient, remote, ...)

	if not success then
		print(...)
		warn("InvokeClient error:", result)
		return {}
	end

	if typeof(result) ~= "table" then
		return {}
	end

	return result
end

return RemoteEvent
