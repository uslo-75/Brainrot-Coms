local InputService = {}
local ServicesTable = {}

local CAS = game:GetService("ContextActionService")
local UIS = game:GetService("UserInputService")
local RP = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local TS = game:GetService("TweenService")
local RS = game:GetService("RunService")

local ServicesFolder = RP:WaitForChild("MyService")
local myservice = require(ServicesFolder:WaitForChild("MyService"))

local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild('Humanoid')
local humanoidRootPart = char:WaitForChild('HumanoidRootPart')
local animator = humanoid:WaitForChild("Animator")

local Settings = require(RP:WaitForChild("List"):WaitForChild("PlayersSettings"))

InputService.Enabled = false
InputService.Initialized = false
InputService.Held = {}
InputService.Bindings = {}
InputService.Modules = {}
InputService.Params = {}



function InputService:GetHeldTime(action)
	local t = self.Held[action]
	return t and tick() - t or 0
end

function InputService:RegisterAction(actionName, keyCodes, module, ...)
	local normalizedKeys = {}
	
	print("Nouveal action enregistre ["..actionName.."]")

	for _, key in ipairs(keyCodes) do
		if typeof(key) == "string" then
			local keyCode = Enum.KeyCode[key]
			if keyCode then
				table.insert(normalizedKeys, keyCode)
			else
				warn("KeyCode invalide:", key)
			end
		else
			table.insert(normalizedKeys, key)
		end
	end

	self.Bindings[actionName] = normalizedKeys
	self.Modules[actionName] = module
	self.Params[actionName] = {...}
end


function InputService:_BindActions()
	for action, keys in pairs(self.Bindings) do
		CAS:BindAction(
			action,
			function(_, state, input)
				if not self.Enabled then return end

				local module = self.Modules[action]
				if not module then return end

				local params = self.Params[action]

				if state == Enum.UserInputState.Begin then
					self.Held[action] = tick()
					if module.Start then
						module:Start(input.KeyCode, table.unpack(params))
					end
				elseif state == Enum.UserInputState.End then
					self.Held[action] = nil
					if module.Stop then
						module:Stop(input.KeyCode, table.unpack(params))
					end
				end
			end,
			false,
			table.unpack(keys)
		)
	end
end

function InputService:BindKeyPressUpdate(actionName, callback)
	RS:BindToRenderStep("KeyUpdate_" .. actionName, Enum.RenderPriority.Input.Value, function()
		if not self.Enabled then return end

		local t = self.Held[actionName]
		if t then
			callback(actionName, tick() - t)
		end
	end)
end

function InputService:UnbindKeyPressUpdate(actionName)
	RS:UnbindFromRenderStep("KeyUpdate_" .. actionName)
end


function InputService:GetKeyHoldTime(actionName)
	local t = self.Held[actionName]
	return t and (tick() - t) or 0
end

function InputService:Enable()
	if not self.Initialized or self.Enabled then return end
	self.Enabled = true
	self:_BindActions()
end

function InputService:Disable()
	if not self.Enabled then return end
	self.Enabled = false
	table.clear(self.Held)
	CAS:UnbindAllActions()
end

function InputService:Init()
	if self.Initialized then return end
	self.Initialized = true
	
	self:Enable()
	
	
	return true
end

function InputService:GetPlateforme()

	if UIS.TouchEnabled and not UIS.KeyboardEnabled then
		return "Mobile"
	elseif UIS.GamepadEnabled then
		return "Console"
	else
		return "PC"
	end
end

function InputService:Destroy()
	self:Disable()
	table.clear(self.Bindings)
	table.clear(self.Modules)
	table.clear(self.Params)
	self.Initialized = false
end

return InputService

