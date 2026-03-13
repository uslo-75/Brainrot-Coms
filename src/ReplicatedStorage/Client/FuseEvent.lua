local RP = game:GetService("ReplicatedStorage")
local myServices = require(RP:WaitForChild("MyService"):WaitForChild("MyService"))
local TS = game:GetService("TweenService")

local MessageModule = require(RP.Module.MessageModule)
local TextModule = require(RP.Module.TextModule)
local ViewPortModule = require(RP.Module.ViewPortModule)
local PreviewModel = require(RP:WaitForChild("Module"):WaitForChild("PreviewModel"))
local GuiList = require(RP:WaitForChild("List"):WaitForChild("GuiList"))

local Gui = myServices:LoadService("Gui") or myServices:GetService("Gui") or require(RP.MyService.Service.Gui)
local RemoteEvent = myServices:LoadService("RemoteEvent")
	or myServices:GetService("RemoteEvent")
	or require(RP.MyService.Service.RemoteEvent)

local ModelMachine = game.Workspace.InteractFolder.Fusion
local db = false
local FuseEvent = {}
local fuseConnection
local fuseButtonConnection
local closeButtonConnection
local MAX_FUSE_SLOTS = 4
local slotButtonConnections = {}
local DEFAULT_MUTATION_TOP = Color3.fromRGB(129, 224, 255)
local DEFAULT_MUTATION_BOTTOM = Color3.fromRGB(88, 160, 255)
local NORMAL_MUTATION_TOP = Color3.fromRGB(245, 247, 252)
local NORMAL_MUTATION_BOTTOM = Color3.fromRGB(137, 144, 161)
local MUTATION_CARD_BASE = Color3.fromRGB(18, 24, 36)
local MUTATION_CARD_TEXT = Color3.fromRGB(248, 250, 255)
local MUTATION_CARD_SUBTEXT = Color3.fromRGB(216, 222, 235)
local FUSE_MUTATION_HELP = "* The fused brainrot rolls one mutation from the odds shown on the right."

local function startFuseTimer(fuseLabel, fuseEndTime)
	if fuseConnection then
		fuseConnection:Disconnect()
	end

	fuseConnection = game:GetService("RunService").RenderStepped:Connect(function()
		local remaining = fuseEndTime - os.time()
		if remaining <= 0 then
			fuseLabel.Text = "Ready"
			fuseConnection:Disconnect()
			fuseConnection = nil
			return
		end

		local hours = math.floor(remaining / 3600)
		local minutes = math.floor((remaining % 3600) / 60)
		local seconds = remaining % 60

		fuseLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
	end)
end

local function clearViewport(viewport)
	if not viewport then
		return
	end

	local worldModel = viewport:FindFirstChildOfClass("WorldModel") or viewport:FindFirstChildWhichIsA("WorldModel")
	if worldModel then
		worldModel:Destroy()
	end
end

local function findNamedChild(container, name, className)
	if not container then
		return nil
	end

	for _, child in ipairs(container:GetChildren()) do
		if child.Name == name and (not className or child:IsA(className)) then
			return child
		end
	end

	return nil
end

local function setLabelText(container, name, value)
	local label = findNamedChild(container, name, "TextLabel")
	if label and label:IsA("TextLabel") then
		label.Text = value
	end
end

local function setTextContent(instance, value)
	if not instance then
		return
	end

	if instance:IsA("TextLabel") or instance:IsA("TextButton") then
		instance.Text = value
		return
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
			descendant.Text = value
		end
	end
end

local function getFuseActionTarget(fuseFrame)
	if not fuseFrame then
		return nil
	end

	local fuseButton = fuseFrame:FindFirstChild("Fuse")
	return fuseButton and (fuseButton:FindFirstChild("Button") or fuseButton)
end

local function setFuseActionState(fuseFrame, action, previewCost)
	local fuseAction = getFuseActionTarget(fuseFrame)
	if not fuseAction then
		return
	end

	if previewCost ~= nil then
		fuseAction:SetAttribute("FusePreviewCost", previewCost)
	else
		previewCost = fuseAction:GetAttribute("FusePreviewCost")
	end

	previewCost = tonumber(previewCost) or 0
	fuseAction:SetAttribute("FuseAction", action)

	if action == "Cancel" then
		setTextContent(fuseAction, "Cancel")
	elseif action == "Claim" then
		setTextContent(fuseAction, "Claim")
	elseif previewCost and previewCost > 0 then
		setTextContent(fuseAction, `Fuse ({TextModule:Suffixe(previewCost)} $)`)
	else
		setTextContent(fuseAction, "Fuse")
	end
end

local function lerpColor(a, b, alpha)
	return Color3.new(
		a.R + ((b.R - a.R) * alpha),
		a.G + ((b.G - a.G) * alpha),
		a.B + ((b.B - a.B) * alpha)
	)
end

local function getMutationColors(mutation)
	if mutation == "Normal" then
		return NORMAL_MUTATION_TOP, NORMAL_MUTATION_BOTTOM
	end

	local sequence = GuiList.Colors[mutation]
	if typeof(sequence) ~= "ColorSequence" then
		return DEFAULT_MUTATION_TOP, DEFAULT_MUTATION_BOTTOM
	end

	local keypoints = sequence.Keypoints
	return keypoints[1].Value, keypoints[#keypoints].Value
end

local function formatPercent(value)
	if not value then
		return "0"
	end

	if math.abs(value - math.floor(value)) < 0.01 then
		return tostring(math.floor(value + 0.5))
	end

	return string.format("%.1f", value)
end

local function formatDuration(seconds)
	if not seconds or seconds <= 0 then
		return "00:00"
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	local remainingSeconds = math.floor(seconds % 60)

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
	end

	return string.format("%02d:%02d", minutes, remainingSeconds)
end

local function buildMutationEntries(mutationPercents)
	local entries = {}

	for mutation, chance in pairs(mutationPercents or {}) do
		if type(chance) == "number" and chance > 0 then
			table.insert(entries, {
				Name = mutation,
				Chance = chance,
			})
		end
	end

	table.sort(entries, function(a, b)
		if a.Chance == b.Chance then
			return a.Name < b.Name
		end

		return a.Chance > b.Chance
	end)

	return entries
end

local function getMutationPanel(container)
	if not container then
		return nil
	end

	local direct = findNamedChild(container, "Mutation", "Frame")
	if direct then
		return direct
	end

	local background = findNamedChild(container, "Background", "Frame")
	if background then
		local nested = findNamedChild(background, "Mutation", "Frame")
		if nested then
			return nested
		end
	end

	local parent = container.Parent
	if parent then
		local sibling = findNamedChild(parent, "Mutation", "Frame")
		if sibling then
			return sibling
		end
	end

	return nil
end

local function getMutationList(container)
	local panel = getMutationPanel(container)
	return panel and findNamedChild(panel, "SFR", "ScrollingFrame") or nil
end

local function getMutationTemplate(container)
	local list = getMutationList(container)
	if not list then
		return nil
	end

	local template = findNamedChild(list, "Template", "Frame")
	if template then
		template.Visible = false
		template.Size = UDim2.new(1, 0, 0, 0)
	end

	return template
end

local function clearMutationCards(container)
	local list = getMutationList(container)
	if not list then
		return
	end

	for _, child in ipairs(list:GetChildren()) do
		if child.Name == "MutationEmptyState" or child.Name:match("^MutationCard_") then
			child:Destroy()
		end
	end
end

local function createMutationEmptyState(list, text)
	local emptyState = Instance.new("TextLabel")
	emptyState.Name = "MutationEmptyState"
	emptyState.BackgroundTransparency = 1
	emptyState.BorderSizePixel = 0
	emptyState.Size = UDim2.new(1, -20, 0, 120)
	emptyState.LayoutOrder = 999
	emptyState.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	emptyState.Text = text
	emptyState.TextColor3 = MUTATION_CARD_SUBTEXT
	emptyState.TextScaled = true
	emptyState.TextWrapped = true
	emptyState.Parent = list

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 26
	constraint.MinTextSize = 14
	constraint.Parent = emptyState
end

local function createMutationCard(container, entry, order)
	local list = getMutationList(container)
	local template = getMutationTemplate(container)
	if not (list and template) then
		return
	end

	local topColor, bottomColor = getMutationColors(entry.Name)
	local accentColor = lerpColor(topColor, bottomColor, 0.5)

	local card = template:Clone()
	card.Name = "MutationCard_" .. tostring(order)
	card.LayoutOrder = order
	card.Visible = true
	card.Size = UDim2.new(1, -12, 0, 62)
	card.BackgroundTransparency = 0.08
	card.BackgroundColor3 = lerpColor(MUTATION_CARD_BASE, accentColor, 0.22)
	card.Parent = list

	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = card
	end
	stroke.Color = accentColor
	stroke.Thickness = 2.5

	local strokeGradient = stroke:FindFirstChildOfClass("UIGradient")
	if not strokeGradient then
		strokeGradient = Instance.new("UIGradient")
		strokeGradient.Parent = stroke
	end
	strokeGradient.Color = ColorSequence.new(topColor, bottomColor)
	strokeGradient.Rotation = 0

	local label = findNamedChild(card, "Label", "TextLabel") or findNamedChild(card, "Title", "TextLabel")
	if label then
		label.Text = `{entry.Name} - {formatPercent(entry.Chance)}%`
		label.TextColor3 = MUTATION_CARD_TEXT
		local textGradient = label:FindFirstChild("Gradien") or label:FindFirstChildOfClass("UIGradient")
		if textGradient then
			textGradient:Destroy()
		end
		Gui:LabelColor(label, entry.Name)
	end

	local head = findNamedChild(card, "Head", "ImageLabel")
	if head then
		head.Image = ""
		head.ImageTransparency = 1
		head.BackgroundTransparency = 0
		head.BackgroundColor3 = accentColor
		head.BorderSizePixel = 0
		local headCorner = head:FindFirstChildOfClass("UICorner")
		if not headCorner then
			headCorner = Instance.new("UICorner")
			headCorner.Parent = head
		end
	end
end

local function renderMutationCards(container, mutationPercents, hasFusingItems)
	local list = getMutationList(container)
	if not list then
		return
	end

	clearMutationCards(container)

	if not hasFusingItems then
		createMutationEmptyState(list, "Place brainrots in the machine to preview mutation odds.")
		return
	end

	local entries = buildMutationEntries(mutationPercents)
	if #entries == 0 then
		createMutationEmptyState(list, "No mutation odds available.")
		return
	end

	for index, entry in ipairs(entries) do
		createMutationCard(container, entry, index)
	end
end

local function updateFuseSummary(background, fuseFrame, data, solution, mutationPercents, preview)
	local fuseData = data and data.Fuse
	local currentCount = preview and preview.CurrentCount or (fuseData and #fuseData.Fusing or 0)
	local remaining = preview and preview.Remaining or math.max(0, MAX_FUSE_SLOTS - currentCount)
	local resultCount = preview and preview.ResultCount or (solution and #solution or 0)
	local previewCost = preview and preview.Cost or 0
	local previewDuration = preview and preview.Duration or 0

	setLabelText(background, "Title", `Fusion Preview ({currentCount}/{MAX_FUSE_SLOTS})`)
	setLabelText(background, "Mutation", `Estimate time : {formatDuration(previewDuration)}`)
	setLabelText(background, "Rarity", `{resultCount} possible result(s)`)

	if currentCount >= MAX_FUSE_SLOTS then
		setLabelText(background, "Price", `Fuse Cost: {TextModule:Suffixe(previewCost)} $`)
	else
		setLabelText(background, "Price", `Need {remaining} more | Cost: {TextModule:Suffixe(previewCost)} $`)
	end

	setLabelText(background, "CashPerSeconde", "")

	if fuseData and fuseData.FuseMode ~= "None" then
		if (fuseData.FuseEndTime or 0) > os.time() then
			setFuseActionState(fuseFrame, "Cancel", previewCost)
		else
			setFuseActionState(fuseFrame, "Claim", previewCost)
		end
	else
		setFuseActionState(fuseFrame, "Fuse", previewCost)
	end

	renderMutationCards(fuseFrame or background, mutationPercents, currentCount > 0)
end

local function getSlotReturnButton(slot)
	if not slot then
		return nil
	end

	local button = slot:FindFirstChild("ReturnButton")
	if button and button:IsA("TextButton") then
		return button
	end

	button = Instance.new("TextButton")
	button.Name = "ReturnButton"
	button.Text = "Return"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -8, 1, -8)
	button.Size = UDim2.new(0.34, 0, 0.16, 0)
	button.BackgroundColor3 = Color3.fromRGB(225, 84, 61)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	button.AutoButtonColor = true
	button.ZIndex = 10
	button.Visible = false
	button.Parent = slot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = button

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = button

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 18
	constraint.MinTextSize = 1
	constraint.Parent = button

	return button
end

local function getSlotMutationBadge(slot)
	if not slot then
		return nil
	end

	local badge = slot:FindFirstChild("MutationBadge")
	if badge and badge:IsA("TextLabel") then
		return badge
	end

	badge = Instance.new("TextLabel")
	badge.Name = "MutationBadge"
	badge.AnchorPoint = Vector2.new(0, 1)
	badge.Position = UDim2.new(0, 8, 1, -8)
	badge.Size = UDim2.new(0.46, 0, 0.16, 0)
	badge.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
	badge.BackgroundTransparency = 0.2
	badge.BorderSizePixel = 0
	badge.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	badge.Text = ""
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextScaled = true
	badge.TextWrapped = true
	badge.Visible = false
	badge.ZIndex = 10
	badge.Parent = slot

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = badge

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = badge

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 18
	constraint.MinTextSize = 1
	constraint.Parent = badge

	return badge
end

local function setSlotMutationBadge(slot, mutation)
	local badge = getSlotMutationBadge(slot)
	if not badge then
		return
	end

	mutation = mutation or ""
	badge.Text = mutation
	badge.Visible = mutation ~= ""
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.BackgroundColor3 = Color3.fromRGB(14, 18, 28)

	local stroke = badge:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		stroke.Color = Color3.new(0, 0, 0)
	end

	local existingGradient = badge:FindFirstChild("Gradien") or badge:FindFirstChildOfClass("UIGradient")
	if existingGradient then
		existingGradient:Destroy()
	end

	if mutation ~= "" and mutation ~= "Normal" then
		local topColor, bottomColor = getMutationColors(mutation)
		badge.BackgroundColor3 = lerpColor(MUTATION_CARD_BASE, lerpColor(topColor, bottomColor, 0.5), 0.22)
		if stroke and stroke:IsA("UIStroke") then
			stroke.Color = lerpColor(topColor, bottomColor, 0.5)
		end
		Gui:LabelColor(badge, mutation)
	end
end

local function setSlotButtonVisible(slot, visible)
	local button = getSlotReturnButton(slot)
	if button then
		button.Visible = visible
		button.Active = visible
		button.AutoButtonColor = visible
		button.Selectable = visible
	end
end

local function bindSlotButton(slot, player)
	if not slot or slotButtonConnections[slot] then
		return
	end

	local button = getSlotReturnButton(slot)
	if not button then
		return
	end

	slotButtonConnections[slot] = button.MouseButton1Click:Connect(function()
		local slotIndex = tonumber(slot.Name)
		if not slotIndex then
			return
		end

		local success, result = RemoteEvent:InvokeServer("FuseEvent", "ReturnSlot", slotIndex)
		if result then
			MessageModule:SendMessage(player, tostring(result), 1.5, success and Color3.new(0, 1, 0) or Color3.new(1, 0, 0))
		end
	end)
end

local function resetFuseFrame(FuseFrame)
	local Background = FuseFrame:WaitForChild("Background")

	for index = 1, MAX_FUSE_SLOTS do
		local slot = Background:FindFirstChild(tostring(index))
		if slot then
			setSlotButtonVisible(slot, false)
			setSlotMutationBadge(slot, "")
			clearViewport(slot)
			setLabelText(slot, "Title", "")
		end
	end

	if Background:FindFirstChild("SFR") then
		for _, child in pairs(Background.SFR:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	clearMutationCards(FuseFrame)
	renderMutationCards(FuseFrame, nil, false)

	setLabelText(Background, "Title", "Place 4 brainrots")
	setLabelText(Background, "Mutation", FUSE_MUTATION_HELP)
	setLabelText(Background, "Rarity", "")
	setLabelText(Background, "CashPerSeconde", "")
	setLabelText(Background, "Price", "")
	setFuseActionState(FuseFrame, "Fuse", 0)
end

ModelMachine.FuseMachine:WaitForChild("Prompt").Special.Triggered:Connect(function(player)
	local MainGui = Gui:GetGuiByName("MainGui")
	local RollGui = Gui:GetGuiByName("RollGui")
	local FuseFrame = MainGui:WaitForChild("FuseMachine")
	local Background = FuseFrame:WaitForChild("Background")

	resetFuseFrame(FuseFrame)
	RollGui.Enabled = FuseFrame.Visible
	Gui:AnimFrame(FuseFrame, not FuseFrame.Visible)

	if closeButtonConnection then
		closeButtonConnection:Disconnect()
	end

	local closeButton = Background:FindFirstChild("X", true)
	if closeButton and closeButton:IsA("GuiButton") then
		closeButtonConnection = closeButton.MouseButton1Click:Connect(function()
			Gui:AnimFrame(FuseFrame, false)
			RollGui.Enabled = true
		end)
	end

	if fuseButtonConnection then
		fuseButtonConnection:Disconnect()
	end

	local fuseAction = getFuseActionTarget(FuseFrame)
	if not (fuseAction and fuseAction:IsA("GuiButton")) then
		return
	end

	fuseButtonConnection = fuseAction.MouseButton1Click:Connect(function()
		local action = fuseAction:GetAttribute("FuseAction") or "Fuse"
		local eventName = action == "Cancel" and "Cancel" or "Fuse"
		local succes, result = RemoteEvent:InvokeServer("FuseEvent", eventName)

		if succes then
			if action ~= "Cancel" then
				Gui:AnimFrame(FuseFrame, false)
				RollGui.Enabled = true
			end
			MessageModule:SendMessage(player, tostring(result), 1.5, Color3.new(0, 1, 0))
			return
		end

		if result then
			MessageModule:SendMessage(player, tostring(result), 1.5, Color3.new(1, 0, 0))
		end
	end)
end)

local function UpdateFuse(player, Halls, FuseFrame)
	local data = Halls[2]
	local Solution = Halls[3]
	local mutationPercents = Halls[4]
	local preview = Halls[5]
	local Background = FuseFrame:WaitForChild("Background")
	local fuseLocked = data and data.Fuse and data.Fuse.FuseMode ~= "None"

	resetFuseFrame(FuseFrame)

	if data and data.Fuse then
		for index, value in pairs(data.Fuse.Fusing) do
			local Template = Background:FindFirstChild(tostring(index))
			local Model = PreviewModel:GetModel("FuseSlot_" .. tostring(index), value.Name, value.Mutation)

			if Template then
				bindSlotButton(Template, player)
				setSlotButtonVisible(Template, not fuseLocked)
				Template.Title.Text = value.Name
				setSlotMutationBadge(Template, value.Mutation or "Normal")
			end

			if Template and Model then
				local preview = ViewPortModule.new(Model, Template)

				preview:Start(Vector3.new(0, 1.5, 8))
			end
		end
	end

	if Solution then
		for _, v in pairs(Background.SFR:GetChildren()) do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end

		for index, v in pairs(Solution) do
			local Template = Background:WaitForChild("Template"):Clone()
			Template.Parent = Background.SFR
			Template.Name = v.Name
			Template.Visible = true
			Template.Title.Text = v.Name
			Template.Pourcent.Text = formatPercent(v.Chance) .. " %"
			Gui:LabelColor(Template.Title, v.Rarity)

			local Model = PreviewModel:GetModel("FuseResult_" .. tostring(index), v.Name, "Normal")

			if Model then
				local preview = ViewPortModule.new(Model, Template.VF)

				preview:Start(Vector3.new(0, 1.5, 8))
			end
		end
	end

	if data and data.Fuse and #data.Fuse.Fusing > 0 then
		updateFuseSummary(Background, FuseFrame, data, Solution or {}, mutationPercents, preview)
	end
end

function FuseEvent:Init(player, ...)
	local Halls = { ... }
	local EventType = Halls[1]

	local MainGui = Gui:GetGuiByName("MainGui")
	local RollGui = Gui:GetGuiByName("RollGui")
	local FuseFrame = MainGui:WaitForChild("FuseMachine")

	local model = game.Workspace.InteractFolder:WaitForChild("Fusion")
	local BillboardGui = model.Head.BillboardGui

	if EventType == "Update" then
		UpdateFuse(player, Halls, FuseFrame)
	elseif EventType == "Running" then
		BillboardGui.Timer.Text = Halls[2]
		BillboardGui.Timer.TextColor3 = Color3.new(0.345098, 0.572549, 1)
		BillboardGui.Timer.Visible = true
		startFuseTimer(BillboardGui.Timer, Halls[2])
		for index = 1, MAX_FUSE_SLOTS do
			local slot = FuseFrame.Background:FindFirstChild(tostring(index))
			if slot then
				setSlotButtonVisible(slot, false)
			end
		end
		setFuseActionState(FuseFrame, "Cancel")
	elseif EventType == "Ready" then
		if fuseConnection then
			fuseConnection:Disconnect()
			fuseConnection = nil
		end

		BillboardGui.Timer.Text = "Ready"
		BillboardGui.Timer.TextColor3 = Color3.new(1, 0.92549, 0.513725)
		BillboardGui.Timer.Visible = true
		for index = 1, MAX_FUSE_SLOTS do
			local slot = FuseFrame.Background:FindFirstChild(tostring(index))
			if slot then
				setSlotButtonVisible(slot, false)
			end
		end
		setFuseActionState(FuseFrame, "Claim")
	else
		if fuseConnection then
			fuseConnection:Disconnect()
			fuseConnection = nil
		end
		BillboardGui.Timer.Visible = false
		setFuseActionState(FuseFrame, "Fuse")
	end
end

return FuseEvent
