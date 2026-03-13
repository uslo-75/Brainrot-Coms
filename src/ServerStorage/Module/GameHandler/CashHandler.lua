-- CashHandler Module
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Base = require(game.ServerStorage.Module.GameHandler.Base)
local TextModule = require(game.ReplicatedStorage.Module.TextModule)
local Sounds = require(ReplicatedStorage.Module.Sounds)

local DataManager = nil
local CashHandler = {}


local AddCash = game.ServerStorage.AddCash
CashHandler.cashModels = {}
CashHandler.started = false
CashHandler.Hits = {}

function CashHandler:Add(model)
	table.insert(self.cashModels, model)
	self:SetupClaimPart(model)
end

function CashHandler:Remove(model)
	for i = #self.cashModels, 1, -1 do
		if self.cashModels[i] == model then
			table.remove(self.cashModels, i)
			break
		end
	end
end

local function GetMultiplicated(player)
	local MyBases = Base.GetBase(player)
	local CashBuff = player
		and player:FindFirstChild("Stats")
		and player.Stats:FindFirstChild("CashBuff")

	local finalCash = 0

	if MyBases then
		finalCash = MyBases.Multiplicateur
	end

	if CashBuff then
		if CashBuff.Value > 1 then
			finalCash = finalCash + (CashBuff.Value - 1)
		end
		if CashBuff:GetAttribute("Buff") then
			finalCash = finalCash + CashBuff:GetAttribute("Buff") or 0
		end
	end

	if finalCash < 1 then
		finalCash += 1
	end
	return finalCash
end

local function CashLabelApply(part, text)
	if part and text then
		local CashLabel = part:FindFirstChild("CashLabel")
		if not CashLabel then
			CashLabel = ReplicatedStorage.Gui.CashLabel:Clone()
			CashLabel.Parent = part
		end
		CashLabel.Label.Text = text
	end
end

function CashHandler:Start()
	if self.started then return end
	self.started = true
	
	AddCash.Event:Connect(function(_type, model)
		if _type == "Add" then
			self:Add(model)
		elseif _type == "Remove" then
			self:Remove(model)
		else
			warn("Error !")
		
		end
	end)

	for _, model in ipairs(CollectionService:GetTagged("CashPerSeconde")) do
		table.insert(self.cashModels, model)
		self:SetupClaimPart(model)
	end

	CollectionService.TagAdded:Connect(function(inst, tag)
		if tag == "CashPerSeconde" then
			table.insert(self.cashModels, inst)
			self:SetupClaimPart(inst)
		end
	end)

	spawn(function()
		while true do
			task.wait(1)
			for i = #self.cashModels, 1, -1 do
				local model = self.cashModels[i]
				if not model or not model.Parent then
					table.remove(self.cashModels, i)
					
				else
					if not model:GetAttribute("InPlace") then
						
						local ownerName = model:GetAttribute("Owner") or ""
						local player = Players:FindFirstChild(ownerName)
						
						if player then
							local currentCash = model:GetAttribute("CurrentCash") or 0
							currentCash += model:GetAttribute("CashFinal") * GetMultiplicated(player)

							if model and ownerName and model:GetAttribute("Type") ~= "InMachine" then

								if player then
									model:SetAttribute("CurrentCash", currentCash)
									local value = model:GetAttribute("CurrentCash")
									local rounded = math.floor(value * 10 + 0.5) / 10
									CashLabelApply(
										model.Parent:FindFirstChild("ClaimCash"),
										tostring(TextModule:Suffixe(rounded)).." $"
									)
								end
							end
						end
						
						
					end
				end
			end
		end
	end)
end

function CashHandler:SetupClaimPart(model)
	local SlotsModel = model.Parent
	if not SlotsModel then return end

	local claimPart = SlotsModel:FindFirstChild("ClaimCash")
	if not claimPart then return end

	claimPart.Touched:Connect(function(hit)
		local char = hit and hit.Parent
		if char and char:FindFirstChildOfClass("Humanoid") then
			if not self.Hits[char] then
				self.Hits[char] = true
				task.delay(1, function()
					self.Hits[char] = nil
				end)

				local player = Players:GetPlayerFromCharacter(char)
				if player then
					local cashStat = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash")
					if cashStat and model:GetAttribute("Type") ~= "InMachine" and model:GetAttribute("Owner") == player.Name then
						if model and model.Parent then
							local cashToAdd = model:GetAttribute("CurrentCash") or 1
							cashStat.Value += cashToAdd
							model:SetAttribute("CurrentCash", 0)
							CashLabelApply(
								model.Parent:FindFirstChild("ClaimCash"),
								""
							)
							Sounds.PlayParts("CashRecup", claimPart, 1.8)
						end
					end
				end
			end
		end
	end)
end

return CashHandler
