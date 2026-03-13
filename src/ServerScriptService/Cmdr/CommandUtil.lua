local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local BaseModule = require(ServerStorage.Module.GameHandler.Base)
local BrainrotList = require(ServerStorage.List.BrainrotList)
local BrainrotSelect = require(ServerStorage.Module.BrainrotSelect)
local DataManager = require(ServerStorage.Data.DataManager)
local MachineModule = require(ServerStorage.Module.GameHandler.Machine)
local RemoteEvent = require(ReplicatedStorage:WaitForChild("MyService"):WaitForChild("Service"):WaitForChild("RemoteEvent"))

local CommandUtil = {}

local AURA_SPIN_PRICE_MULTIPLIER = 1 + (10 / 100)

local function GetBrainrotModel(slotModel)
	if not slotModel then
		return nil
	end

	return slotModel:FindFirstChildWhichIsA("Model") or slotModel:FindFirstChildOfClass("Model")
end

local function ClearClaimLabel(slotModel)
	local claimPart = slotModel and slotModel:FindFirstChild("ClaimCash")
	local cashLabel = claimPart and claimPart:FindFirstChild("CashLabel")
	if cashLabel then
		cashLabel:Destroy()
	end
end

function CommandUtil.GetBase(player)
	local base = BaseModule.GetBase(player)
	if not (base and base.StockBrainrot) then
		return nil, "Base introuvable."
	end

	return base
end

function CommandUtil.GetState(player, position)
	local positionString = tostring(position)
	local base = BaseModule.GetBase(player)
	local slotModel = base and base.StockBrainrot and base.StockBrainrot:FindFirstChild(positionString)
	local model = GetBrainrotModel(slotModel)
	local brainrotData = DataManager.GetBrainrot(player, positionString)

	return {
		position = positionString,
		base = base,
		slotModel = slotModel,
		model = model,
		brainrotData = brainrotData,
	}
end

function CommandUtil.ClearSlot(slotModel)
	if not slotModel then
		return
	end

	local model = GetBrainrotModel(slotModel)
	if model then
		model:Destroy()
	end

	slotModel:SetAttribute("Enter", false)
	slotModel:SetAttribute("CurrentCash", 0)
	slotModel:SetAttribute("CashPerSeconde", nil)
	ClearClaimLabel(slotModel)
end

function CommandUtil.RebuildPositions(player, positions)
	local base, err = CommandUtil.GetBase(player)
	if not base then
		return false, err
	end

	local seen = {}
	for _, position in ipairs(positions) do
		local positionString = tostring(position)
		if not seen[positionString] then
			seen[positionString] = true

			local slotModel = base.StockBrainrot:FindFirstChild(positionString)
			if slotModel then
				CommandUtil.ClearSlot(slotModel)

				local brainrotData = DataManager.GetBrainrot(player, positionString)
				if brainrotData then
					base.UpdateBrairot:Fire(
						brainrotData.Name,
						brainrotData.Mutation,
						brainrotData.Position,
						brainrotData.Slots,
						brainrotData.HorsLineCash or 0
					)
				end
			end
		end
	end

	return true
end

function CommandUtil.RefreshAuraSpinUi(player)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not (data and data.AuraSpin) then
		return false
	end

	local name = data.AuraSpin.Name
	local position = data.AuraSpin.Position
	if name == "" or position == "" then
		return false
	end

	local brainrotInfo = BrainrotList[name]
	local brainrotData = DataManager.GetBrainrot(player, position)
	if not (brainrotInfo and brainrotData) then
		return false
	end

	local multipliers = { brainrotData.Mutation }
	for _, auraName in pairs(brainrotData.Slots or {}) do
		table.insert(multipliers, auraName)
	end

	local cashPerSeconde = brainrotInfo.CashPerSeconde * BrainrotSelect:GetMultiplicater(multipliers)

	RemoteEvent:InvokeClient(
		"AuraSpin",
		player,
		"UpdateInfo",
		name,
		brainrotData.Mutation,
		brainrotInfo.Rarity,
		cashPerSeconde,
		brainrotInfo.Price,
		brainrotData.Slots or {},
		brainrotInfo.Price * AURA_SPIN_PRICE_MULTIPLIER
	)
	RemoteEvent:InvokeClient(
		"AuraSpin",
		player,
		"BrairotPreview",
		true,
		brainrotData.Mutation,
		name,
		brainrotData.Slots or {}
	)

	return true
end

function CommandUtil.ClearAuraSpinUi(player)
	RemoteEvent:InvokeClient("AuraSpin", player, "Empty")
end

function CommandUtil.RefreshMachineUi(player)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	local machine = MachineModule:Return() or MachineModule:Init(player)

	if machine and data then
		machine:Update(data, player)
		machine:SyncFuseState(player)
		return true
	end

	return false
end

function CommandUtil.ClearMachineStateForPosition(player, position)
	local profile = DataManager:GetProfile(player)
	local data = profile and profile.Data
	if not data then
		return false, false, false
	end

	local positionString = tostring(position)
	local auraCleared = false
	local fuseCleared = false

	if data.AuraSpin and tostring(data.AuraSpin.Position) == positionString then
		DataManager:ClearAuraSpin(player)
		CommandUtil.ClearAuraSpinUi(player)
		auraCleared = true
	end

	if data.Fuse and typeof(data.Fuse.Fusing) == "table" then
		for index = #data.Fuse.Fusing, 1, -1 do
			local item = data.Fuse.Fusing[index]
			if item and tostring(item.Position) == positionString then
				table.remove(data.Fuse.Fusing, index)
				fuseCleared = true
			end
		end

		if fuseCleared then
			data.Fuse.FuseMode = "None"
			data.Fuse.FuseEndTime = 0
			CommandUtil.RefreshMachineUi(player)
		end
	end

	return auraCleared or fuseCleared, auraCleared, fuseCleared
end

return CommandUtil
