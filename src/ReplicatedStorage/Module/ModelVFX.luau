local HttpService = game:GetService("HttpService")
local RP = game:GetService("ReplicatedStorage")

local ModelVFX = {}

local function getVfxPart(model)
	if not model then
		return nil
	end

	return model:FindFirstChild("VfxInstance")
end

function ModelVFX.ClearAura(model)
	local vfxPart = getVfxPart(model)
	if not vfxPart then
		return false
	end

	for _, child in ipairs(vfxPart:GetChildren()) do
		if child:GetAttribute("Aura") then
			child:Destroy()
		end
	end

	return true
end

function ModelVFX.ApplyAuraList(model, auraList)
	local vfxPart = getVfxPart(model)
	if not vfxPart then
		return false
	end

	ModelVFX.ClearAura(model)

	for _, auraName in pairs(auraList or {}) do
		if auraName and auraName ~= "" then
			local auraTemplate = RP:WaitForChild("Aura"):FindFirstChild(auraName)
			if auraTemplate then
				local auraClone = auraTemplate:Clone()

				for _, child in ipairs(auraClone:GetChildren()) do
					child:SetAttribute("Aura", true)
					child.Parent = vfxPart

					if child:IsA("BasePart") then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = vfxPart
						weld.Part1 = child
						weld.Parent = child
					elseif child:IsA("ParticleEmitter") or child:IsA("Trail") or child:IsA("Beam") then
						child.Enabled = true
					end
				end

				auraClone:Destroy()
			end
		end
	end

	return true
end

function ModelVFX.DecodeAuraSlots(model)
	local encodedSlots = model and model:GetAttribute("AuraSlotsJson")
	if typeof(encodedSlots) ~= "string" or encodedSlots == "" then
		return nil
	end

	local success, decodedSlots = pcall(HttpService.JSONDecode, HttpService, encodedSlots)
	if success and typeof(decodedSlots) == "table" then
		return decodedSlots
	end

	return nil
end

function ModelVFX.RefreshModelFromAttributes(model, enabled)
	if not (model and model:IsA("Model")) then
		return false
	end

	if enabled == false then
		return ModelVFX.ClearAura(model)
	end

	local auraSlots = ModelVFX.DecodeAuraSlots(model)
	if not auraSlots then
		return ModelVFX.ClearAura(model)
	end

	return ModelVFX.ApplyAuraList(model, auraSlots)
end

return ModelVFX
