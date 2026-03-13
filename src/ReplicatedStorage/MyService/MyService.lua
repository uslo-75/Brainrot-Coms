local myServiceFolder = script.Parent
local ServiceFolder = myServiceFolder:WaitForChild("Service")

local RS = game:GetService("RunService")

local myservices = {}
myservices.Services = {}
myservices.InitializedServices = {}

local servicesLoaded = false

local SERVICE_LOAD_PRIORITY = {
	RemoteEvent = 0,
	RemoteLoader = 1,
	Gui = 2,
}

local DEFAULT_RUN_TYPES = {
	Gui = "Client",
	InputService = "Client",
	MarketPlaceService = "Client",
	RemoteEvent = "Globale",
	RemoteLoader = "Globale",
	StateManager = "Server",
}

local function GetRunningIn()
	if RS:IsServer() then
		return "Server"
	else
		return "Client"
	end
end

local function GetServiceRunType(serviceModule)
	local explicitRunType = serviceModule:GetAttribute("ServiceRunType")
	if explicitRunType ~= nil then
		return explicitRunType
	end

	return DEFAULT_RUN_TYPES[serviceModule.Name]
end

local function ShouldLoadService(serviceModule, runningIn)
	local runType = GetServiceRunType(serviceModule)
	if runType == nil then
		return true
	end

	return runType == "Globale" or runType == runningIn
end

local function GetServiceLoadPriority(serviceModule)
	local explicitPriority = serviceModule:GetAttribute("ServiceLoadPriority")
	if typeof(explicitPriority) == "number" then
		return explicitPriority
	end

	return SERVICE_LOAD_PRIORITY[serviceModule.Name] or 100
end

local function GetSortedServiceModules(runningIn)
	local serviceModules = {}

	for _, serviceModule in ipairs(ServiceFolder:GetChildren()) do
		if serviceModule:IsA("ModuleScript") and ShouldLoadService(serviceModule, runningIn) then
			table.insert(serviceModules, serviceModule)
		end
	end

	table.sort(serviceModules, function(a, b)
		local priorityA = GetServiceLoadPriority(a)
		local priorityB = GetServiceLoadPriority(b)

		if priorityA == priorityB then
			return a.Name < b.Name
		end

		return priorityA < priorityB
	end)

	return serviceModules
end

function myservices:LoadService(serviceName)
	return self.Services[serviceName]
end


function myservices:GetService(serviceName)

	local attempts = 5
	local cooldown = 0.2

	for i = 1, attempts do

		if self.Services[serviceName] then
			return self.Services[serviceName]
		end

		task.wait(cooldown)

	end

	warn("[MODULE LOADER]: Service "..serviceName.." not found")
end


function myservices:FetchAllServices()

	if servicesLoaded then
		return self.Services
	end

	local runningIn = GetRunningIn()
	local serviceModules = GetSortedServiceModules(runningIn)

	for _, serviceModule in ipairs(serviceModules) do
		local serviceName = serviceModule.Name
		local success, service = pcall(require, serviceModule)

		if success then
			self.Services[serviceName] = service
		else
			warn("[MODULE LOADER]: Error while requiring " .. serviceName, service)
		end
	end

	for _, serviceModule in ipairs(serviceModules) do
		local serviceName = serviceModule.Name
		local service = self.Services[serviceName]

		if service.Init and not self.InitializedServices[serviceName] then
			self.InitializedServices[serviceName] = true

			task.spawn(function()
				local success, err = pcall(function()
					service:Init()
				end)

				if success then
					print("[MODULE LOADER]: Successfully initialized " .. serviceName)
				else
					self.InitializedServices[serviceName] = nil
					warn("[MODULE LOADER]: Error while initiating " .. serviceName, err)
				end
			end)
		end

	end

	servicesLoaded = true

	return self.Services

end


return myservices
