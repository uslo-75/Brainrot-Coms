local RP = game:GetService("ReplicatedStorage")
local ServiceFolder = RP:WaitForChild("MyService")
local myServices = require(ServiceFolder:WaitForChild("MyService"))

local IndexGui = {}
IndexGui.__index = IndexGui

local ServiceTable = {}

local ViewPortModule = require(RP.Module.ViewPortModule)
local PreviewModel = require(RP.Module.PreviewModel)
local GuiList = require(RP.List.GuiList)

local PREVIEW_BATCH_SIZE = 8
local SLOT_BASE_COLOR = Color3.fromRGB(16, 22, 33)
local SLOT_UNKNOWN_TOP = Color3.fromRGB(145, 149, 158)
local SLOT_UNKNOWN_BOTTOM = Color3.fromRGB(83, 88, 99)
local SLOT_VIEWPORT_COLOR = Color3.fromRGB(10, 14, 22)
local SLOT_TEXT_COLOR = Color3.fromRGB(248, 250, 255)
local SLOT_UNKNOWN_TEXT_COLOR = Color3.fromRGB(240, 242, 247)
local MUTATION_ORDER_PRIORITY = {
	Normal = 1,
	Gold = 2,
	Diamond = 3,
	Shiny = 4,
}

ServiceTable["RemoteEvent"] = myServices:GetService("RemoteEvent") or require(ServiceFolder.Service.RemoteEvent)
ServiceTable["Gui"] = myServices:GetService("Gui") or require(ServiceFolder.Service.Gui)

local function GetPreviewKey(name, mutation)
	return "Index_" .. tostring(mutation) .. "_" .. tostring(name)
end

local function LerpColor(a: Color3, b: Color3, alpha: number)
	return Color3.new(
		a.R + ((b.R - a.R) * alpha),
		a.G + ((b.G - a.G) * alpha),
		a.B + ((b.B - a.B) * alpha)
	)
end

local function EnsureInstance(parent: Instance, className: string, name: string)
	local child = parent:FindFirstChild(name)
	if child and child.ClassName == className then
		return child
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function GetMutationColors(mutation)
	local sequence = GuiList.Colors[mutation]
	if typeof(sequence) ~= "ColorSequence" then
		return Color3.fromRGB(129, 224, 255), Color3.fromRGB(88, 160, 255)
	end

	local keypoints = sequence.Keypoints
	return keypoints[1].Value, keypoints[#keypoints].Value
end

local function GetSortedMutations(indexList)
	local mutations = {}

	for mutation in pairs(indexList or {}) do
		table.insert(mutations, mutation)
	end

	table.sort(mutations, function(left, right)
		local leftPriority = MUTATION_ORDER_PRIORITY[left] or math.huge
		local rightPriority = MUTATION_ORDER_PRIORITY[right] or math.huge

		if leftPriority == rightPriority then
			return left < right
		end

		return leftPriority < rightPriority
	end)

	return mutations
end

function IndexGui.new(MainGui: ScreenGui)
	local self = setmetatable({}, IndexGui)

	self.MainGui = MainGui
	self.IndexFrame = MainGui:WaitForChild("IndexFrame")
	self.Container = self.IndexFrame.Background.Container
	self.LeftButtons = MainGui:WaitForChild("LeftButtons")
	self.IndexButton = self.LeftButtons:WaitForChild("Index")

	self.IndexList = {}
	self.IndexData = {}
	self.MaxBrainrot = 0
	self.PreviewViews = {}
	self.LoadedPreviewKeys = {}
	self.PreviewGeneration = 0
	self.Connections = {}

	self:LoadData()
	self:Build()
	self:Bind()

	return self
end

function IndexGui:Destroy()
	self.PreviewGeneration += 1

	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end

	self.Connections = {}

	for _, preview in pairs(self.PreviewViews) do
		if preview then
			preview:Destroy()
		end
	end

	self.PreviewViews = {}
	self.LoadedPreviewKeys = {}
end

function IndexGui:Count()
	local count = 0
	for _, mutations in pairs(self.IndexData) do
		if typeof(mutations) == "table" then
			for _, collected in pairs(mutations) do
				if collected then
					count += 1
					break
				end
			end
		elseif mutations then
			count += 1
		end
	end
	return count
end

function IndexGui:UpdateCollectedText()
	local collectedText =
		self:Count() .. " / " .. tostring(self.MaxBrainrot or "NA")

	self.IndexFrame.Collected.Text = collectedText
	self.IndexButton.Amount.TextLabel.Text = collectedText
end

function IndexGui:LoadData()
	self.IndexList, self.MaxBrainrot =
		ServiceTable.RemoteEvent:InvokeServer("GetInfo", "Index")

	local data =
		ServiceTable.RemoteEvent:InvokeServer("GetInfo", "Data")

	self.IndexData = data and data.Index or {}
end

function IndexGui:FindMutationTitle(mutation)
	for _, child in ipairs(self.Container:GetChildren()) do
		if child:IsA("TextLabel") and child.Text == mutation then
			return child
		end
	end

	return nil
end

function IndexGui:StyleMutationTitle(titleLabel: TextLabel, mutation: string)
	local topColor, bottomColor = GetMutationColors(mutation)
	local gradient = titleLabel:FindFirstChildOfClass("UIGradient")
	local stroke = titleLabel:FindFirstChildOfClass("UIStroke")

	titleLabel.Text = mutation
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

	if gradient then
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, topColor),
			ColorSequenceKeypoint.new(1, bottomColor),
		})
	end

	if stroke then
		stroke.Color = Color3.fromRGB(0, 0, 0)
	end
end

function IndexGui:EnsureMutationSections()
	local sectionTemplate = nil
	local titleTemplate = nil

	for _, child in ipairs(self.Container:GetChildren()) do
		if not sectionTemplate and child:IsA("ScrollingFrame") and self.IndexList[child.Name] then
			sectionTemplate = child
		elseif not titleTemplate and child:IsA("TextLabel") and string.find(child.Name, "Title", 1, true) then
			titleTemplate = child
		end

		if sectionTemplate and titleTemplate then
			break
		end
	end

	if not (sectionTemplate and titleTemplate) then
		return
	end

	local sortedMutations = GetSortedMutations(self.IndexList)

	for index, mutation in ipairs(sortedMutations) do
		local titleLabel = self:FindMutationTitle(mutation)
		if not titleLabel then
			titleLabel = titleTemplate:Clone()
			titleLabel.Name = mutation .. "Title"
			titleLabel.Parent = self.Container
		end

		self:StyleMutationTitle(titleLabel, mutation)
		titleLabel.LayoutOrder = ((index - 1) * 2)

		local sectionFrame = self.Container:FindFirstChild(mutation)
		if not (sectionFrame and sectionFrame:IsA("ScrollingFrame")) then
			sectionFrame = sectionTemplate:Clone()
			sectionFrame.Name = mutation
			sectionFrame.Parent = self.Container
		end

		sectionFrame.LayoutOrder = titleLabel.LayoutOrder + 1
	end
end

function IndexGui:StyleTemplate(template: Frame, mutation: string, isCollected: boolean)
	local stroke = template:FindFirstChildOfClass("UIStroke")
	local gradient = template:FindFirstChildOfClass("UIGradient")
	local nameLabel = template:FindFirstChild("Name")
	local viewPortFrame = template:FindFirstChild("Vf")

	template.ClipsDescendants = true

	if stroke then
		stroke.Thickness = 3
	end

	if nameLabel and nameLabel:IsA("TextLabel") then
		nameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		nameLabel.Position = UDim2.fromScale(0.5, 0.84)
		nameLabel.Size = UDim2.fromScale(0.88, 0.2)
		nameLabel.BackgroundColor3 = Color3.fromRGB(7, 10, 16)
		nameLabel.TextColor3 = isCollected and SLOT_TEXT_COLOR or SLOT_UNKNOWN_TEXT_COLOR
		nameLabel.TextStrokeTransparency = 0.25
		nameLabel.TextYAlignment = Enum.TextYAlignment.Center
		nameLabel.ZIndex = 4

		local labelCorner = nameLabel:FindFirstChildOfClass("UICorner") or EnsureInstance(nameLabel, "UICorner", "CardCorner")
		labelCorner.CornerRadius = UDim.new(0.22, 0)

		local labelStroke = nameLabel:FindFirstChildOfClass("UIStroke")
		if labelStroke then
			labelStroke.Color = Color3.fromRGB(0, 0, 0)
			labelStroke.Thickness = 2
			labelStroke.Transparency = 0.3
		end
	end

	if viewPortFrame and viewPortFrame:IsA("ViewportFrame") then
		viewPortFrame.Position = UDim2.fromScale(0.06, 0.06)
		viewPortFrame.Size = UDim2.fromScale(0.88, 0.62)
		viewPortFrame.BackgroundColor3 = SLOT_VIEWPORT_COLOR
		viewPortFrame.ZIndex = 2

		local viewPortCorner = viewPortFrame:FindFirstChildOfClass("UICorner") or EnsureInstance(viewPortFrame, "UICorner", "CardCorner")
		viewPortCorner.CornerRadius = UDim.new(0.14, 0)

		local viewPortStroke = viewPortFrame:FindFirstChildOfClass("UIStroke") or EnsureInstance(viewPortFrame, "UIStroke", "CardStroke")
		viewPortStroke.Thickness = 1.5

		if isCollected then
			local topColor, bottomColor = GetMutationColors(mutation)
			local accentColor = LerpColor(topColor, bottomColor, 0.45)

			template.BackgroundColor3 = LerpColor(SLOT_BASE_COLOR, accentColor, 0.18)
			template.BackgroundTransparency = 0.18
			viewPortFrame.BackgroundColor3 = LerpColor(SLOT_VIEWPORT_COLOR, accentColor, 0.12)
			viewPortFrame.BackgroundTransparency = 0.22
			viewPortStroke.Color = LerpColor(accentColor, Color3.new(1, 1, 1), 0.18)
			viewPortStroke.Transparency = 0.5

			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, LerpColor(SLOT_BASE_COLOR, topColor, 0.18)),
					ColorSequenceKeypoint.new(1, LerpColor(SLOT_BASE_COLOR, bottomColor, 0.3)),
				})
			end

			if stroke then
				stroke.Color = accentColor
				stroke.Transparency = 0.18
			end

			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.BackgroundTransparency = 0.18
			end
		else
			template.BackgroundColor3 = SLOT_BASE_COLOR
			template.BackgroundTransparency = 0.28
			viewPortFrame.BackgroundColor3 = SLOT_VIEWPORT_COLOR
			viewPortFrame.BackgroundTransparency = 0.32
			viewPortStroke.Color = Color3.fromRGB(112, 118, 132)
			viewPortStroke.Transparency = 0.72

			if gradient then
				gradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, SLOT_UNKNOWN_TOP),
					ColorSequenceKeypoint.new(1, SLOT_UNKNOWN_BOTTOM),
				})
			end

			if stroke then
				stroke.Color = Color3.fromRGB(70, 76, 89)
				stroke.Transparency = 0.4
			end

			if nameLabel and nameLabel:IsA("TextLabel") then
				nameLabel.BackgroundTransparency = 0.24
			end
		end
	end
end

function IndexGui:FrameSizeY(frame: Frame)
	--[[
	local grid = frame:FindFirstChildOfClass("UIGridLayout")
	local padding = frame:FindFirstChildOfClass("UIPadding")
	if not grid or not padding then
		return
	end

	local templatesPerRow = 4
	local baseRows = 2
	local minTemplates = templatesPerRow * baseRows

	local count = 0
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") and child.Visible then
			count += 1
		end
	end

	if count <= minTemplates then
		return
	end

	local rowsNeeded = math.ceil(count / templatesPerRow)

	local cellHeight = grid.AbsoluteCellSize.Y
	local spacing = grid.CellPadding.Y.Offset
	local paddingY = padding.PaddingTop.Offset + padding.PaddingBottom.Offset

	local newHeight =
		(rowsNeeded * cellHeight)
		+ ((rowsNeeded - 1) * spacing)
		+ paddingY

	frame.Size = UDim2.new(
		frame.Size.X.Scale,
		frame.Size.X.Offset,
		0,
		newHeight / 4
	)
	]]
end

function IndexGui:Build()
	self:EnsureMutationSections()
	self:UpdateCollectedText()

	for _, frame in ipairs(self.Container:GetChildren()) do
		local MyIndex = self.IndexList[frame.Name]

		if MyIndex then
			for name in pairs(MyIndex) do
				local Template = frame:FindFirstChild(name)

				if not Template then
					Template = frame.Military:Clone()
					Template.Name = name
					Template.Parent = frame
					Template.Visible = true
					Template.ImageLabel.Visible = false
				end

				self:ApplyState(Template, name, frame.Name)
			end
		end

		self:FrameSizeY(frame)
	end
end

function IndexGui:DestroyPreview(template)
	local viewPort = self.PreviewViews[template]
	if viewPort then
		viewPort:Destroy()
		self.PreviewViews[template] = nil
	end

	self.LoadedPreviewKeys[template] = nil
end

function IndexGui:LoadPreview(template, name, mutation)
	local viewPortFrame = template:FindFirstChild("Vf")
	if not viewPortFrame then
		return
	end

	local previewKey = GetPreviewKey(name, mutation)
	if self.LoadedPreviewKeys[template] == previewKey then
		return
	end

	self:DestroyPreview(template)

	local model = PreviewModel:GetModel(previewKey, name, mutation)
	if not model then
		return
	end

	viewPortFrame.Ambient = Color3.fromRGB(200, 200, 200)
	viewPortFrame.LightColor = Color3.fromRGB(140, 140, 140)

	local viewPort = ViewPortModule.new(model, viewPortFrame, true)
	viewPort:Start()

	self.PreviewViews[template] = viewPort
	self.LoadedPreviewKeys[template] = previewKey

	PreviewModel:Clear(previewKey)
end

function IndexGui:RefreshPreviews()
	if not self.IndexFrame.Visible then
		return
	end

	self.PreviewGeneration += 1
	local generation = self.PreviewGeneration

	task.spawn(function()
		local processed = 0

		for _, frame in ipairs(self.Container:GetChildren()) do
			if generation ~= self.PreviewGeneration then
				return
			end

			for _, template in ipairs(frame:GetChildren()) do
				if generation ~= self.PreviewGeneration then
					return
				end

				if not template:IsA("Frame") then
					continue
				end

				local isCollected = self.IndexData[template.Name] and self.IndexData[template.Name][frame.Name]
				if isCollected then
					self:LoadPreview(template, template.Name, frame.Name)
					processed += 1

					if processed % PREVIEW_BATCH_SIZE == 0 then
						task.wait()
					end
				else
					self:DestroyPreview(template)
				end
			end
		end
	end)
end

function IndexGui:ApplyState(Template, name, mutation)
	local isCollected = self.IndexData[name] and self.IndexData[name][mutation]

	self:StyleTemplate(Template, mutation, isCollected)

	if isCollected then
		Template:WaitForChild("Name").Text = name

		if Template:FindFirstChild("Vf") then
			Template.Vf.Ambient = Color3.fromRGB(200, 200, 200)
			Template.Vf.LightColor = Color3.fromRGB(140, 140, 140)
		end
	else
		Template:WaitForChild("Name").Text = "???"

		if Template:FindFirstChild("Vf") then
			Template.Vf.Ambient = Color3.new(0, 0, 0)
			Template.Vf.LightColor = Color3.new(0, 0, 0)
		end

		self:DestroyPreview(Template)
	end
end

function IndexGui:UpdateIndex()
	self:UpdateCollectedText()

	for _, frame in ipairs(self.Container:GetChildren()) do
		for _, Template in pairs(frame:GetChildren()) do
			if Template:IsA("Frame") then
				self:ApplyState(Template, Template.Name, frame.Name)
			end
		end
	end
end

function IndexGui:Bind()
	table.insert(self.Connections, self.IndexButton.MouseButton1Click:Connect(function()
		local nextVisible = not self.IndexFrame.Visible
		ServiceTable["Gui"]:AnimFrame(self.IndexFrame, nextVisible)

		if nextVisible then
			self:LoadData()
			self:UpdateIndex()
			self:RefreshPreviews()
		else
			self.PreviewGeneration += 1
		end
	end))

	table.insert(self.Connections, self.IndexFrame.Background.X.MouseButton1Click:Connect(function()
		self.PreviewGeneration += 1
		ServiceTable["Gui"]:AnimFrame(self.IndexFrame, false)
	end))
end

return IndexGui
