local RemoteLoader = {}
local RS = game:GetService("RunService")


function RemoteLoader:Init()
	if RS:IsServer() then
		local RemoteServerLoader = require(script:WaitForChild("RemoteServerLoader"))
		RemoteServerLoader:Init()
	else
		local RemoteClientLoader = require(script:WaitForChild("RemoteClientLoader"))
		RemoteClientLoader:Init()
	end
	
	return true
end

return RemoteLoader
