local PlayerService = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local TextModule = {}

function TextModule:Suffixe(Value: number)
	if Value == nil then return "" end
	if Value  < 1000 then
		return Value
	elseif Value >= 1000 then
		local Index = 1
		local Suffixes = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc, No", "De", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Oc", "Nd",
			"V", "Uv", "Dv", "Tv", "Qav", "Qiv", "Sxv", "Spv", "Ov", "Nv", "Tg", "Ut", "Dt", "Tt", "Qat", "Qit", "Sxt", "Spt", "Ot", "Nt", "Qd",
			"Uqd", "Dqd", "Tqd", "Qaqd", "Qiqd", "Sxqd", "Spqd", "Oqd", "Nqd", "Qng", "Uqn", "Dqn", "Tqn", "Qaqn", "Qiqn", "Sxqn", "Spqn", "Oqn",
			"Nqn", "Sxg", "Usx", "Dsx", "Tsx", "Qasx", "Qisx", "Sxsx", "Osx", "Nsx", "Spg", "Usp", "Dsp", "Tsp", "Qasp", "Qisp", "Sxsp", "Spsp",
			"Osp", "Nsp", "Og", "Uo", "Do", "To", "Qao", "Qio", "Sxo", "Spo", "Oo", "Nog", "Ng", "Un", "Dn", "Tn", "Qan", "Qin", "Sxn", "On", "Nn",
			"Ce", "Uce", "Dce", "Inf"}  
		while Value >= 1000 and Index <= #Suffixes do
			Value = Value / 1000
			Index += 1
		end 
		local Format = string.format("%.2f", Value) 
		if Format == "1000.00" and Index < #Suffixes then
			Format = "1.00"
			Index += 1
		end
		return Format .. Suffixes[Index]
	end
end

function TextModule:Spaced(Value: number, Space: string)
	local CurrentText = tostring(Value)
	local Chars = CurrentText:len()
	local NewText = ""

	for i = 1, Chars do
		local CharIndex = Chars - (i - 1)       
		if i ~= 1 and (i-1)%3 == 0 then
			NewText = CurrentText:sub(CharIndex, CharIndex) .. Space .. NewText
		else
			NewText = CurrentText:sub(CharIndex, CharIndex) .. NewText
		end
	end 

	return NewText
end

function TextModule:Timer(Seconds: number)
	local Minutes = (Seconds - Seconds%60)/60
	Seconds = Seconds - Minutes*60
	local Hours = (Minutes - Minutes%60)/60
	Minutes = Minutes - Hours*60
	if Hours <= 0 then
		return string.format("%02i", Minutes)..":"..string.format("%02i", Seconds)
	elseif Hours > 0 then
		return string.format("%02i", Hours).. ":" ..string.format("%02i", Minutes)..":"..string.format("%02i", Seconds)
	end
end

function TextModule:Percentage(FirstValue: number, SecondValue: number, Decimal: boolean)
	local Percent = FirstValue * 100 / SecondValue

	local function RoundNumber(num, numDecimalPlaces)
		return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
	end

	if Decimal == true then
		return tostring(RoundNumber(Percent, 1).. "%")
	elseif Decimal == false then
		return tostring(math.floor(Percent).. "%")
	end
end

function TextModule:TypeWrite(Object: TextLabel, Text: string, Speed: number, Sound: Sound, Mode: string, Effects: SharedTableRegistry)
	local State = false

	local FadeReady = true
	local GrowReady = true
	local HackReady = true

	local AllFace = {"Legacy", "Arial", "ArialBold", "SourceSans", "SourceSansBold", "SourceSansLight", "SourceSansItalic", "Bodoni", "Garamond", "Cartoon", "Code", "Highway",
		"SciFi", "Arcade", "Fantasy", "Antique", "SourceSansSemibold", "Gotham", "GothamMedium", "GothamBold", "GothamBlack", "AmaticSC", "Bangers", "Creepster", "DenkOne",
		"Fondamento", "FredokaOne", "GrenzeGotisch", "IndieFlower", "JosefinSans", "Jura", "Kalam", "LuckiestGuy", "Merriweather", "Michroma", "Nunito", "Oswald", "PatrickHand",
		"PermanentMarker", "Roboto", "RobotoCondensed", "RobotoMono", "Sarpanch", "SpecialElite", "TitilliumWeb", "Ubuntu"
	}

	local function PlaySound()
		if Sound then
			Sound.TimePosition = 0
			Sound:Play()
		end
	end

	local function RoundNumber(num, numDecimalPlaces)
		return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
	end

	local function Fading()
		FadeReady = false
		local Trans = 0
		for i = 1, 10 do
			Trans += 0.1
			local NewTrans = Trans - 0.1
			Object.Text = string.gsub(Object.Text, [[transparency="]].. tostring(RoundNumber(Trans, 1)).. [["]], [[transparency="]].. tostring(RoundNumber(NewTrans, 1)).. [["]])
		end
		task.wait(Speed*2.5)
		FadeReady = true
	end

	local function Growing()
		GrowReady = false
		local Gr = tonumber(Object.TextSize)
		for i = 1, Object.TextSize+1 do
			Object.Text = string.gsub(Object.Text, [[size="]].. tostring(Gr).. [["]], [[size="]].. tostring(Gr+1).. [["]])
			Gr -= 1
		end
		task.wait(0.01)
		GrowReady = true
	end

	local function Checking()
		while State == true do
			for _,Selected in pairs(Effects)do
				if Selected == "Fading" or Selected == "fading" then
					task.spawn(Fading)
				elseif Selected == "Growing" or Selected == "growing" then
					task.spawn(Growing)
				end
			end
			task.wait()
		end
	end

	local function Dialog()
		local FadeStart, FadeEnd = "",""
		local GrowStart, GrowEnd = "",""
		local HackStart, HackEnd = "", ""
		local RainbowStart, RainbowEnd = "", ""

		State = true

		for _,Selected in pairs(Effects)do
			if Selected == "Fading" or Selected == "fading" then
				FadeStart, FadeEnd = [[<font transparency="1">]], [[</font>]]
			elseif Selected == "Growing" or Selected == "growing" then
				GrowStart, GrowEnd = [[<font size="0">]], [[</font>]]
			end
		end

		task.spawn(Checking)
		for i = 1, #Text do
			for _,Selected in pairs(Effects)do
				if Selected == "Colored" or Selected == "colored" then
					local r = math.random(1,255)
					local g = math.random(1,255)
					local b = math.random(1,255)
					RainbowStart, RainbowEnd = [[<stroke transparency="0" joins="Round" thickness="1.5" color="rgb(]].. r.. ",".. g.. ",".. b.. [[)">]], [[</stroke>]]
				elseif Selected == "Hacked" or Selected == "hacked" then
					local RandomFace = AllFace[math.random(1, #AllFace)]
					HackStart, HackEnd = [[<font face="]].. RandomFace.. [[">]], [[</font>]]
				end
			end

			Object.Text = Object.Text.. FadeStart.. GrowStart.. HackStart.. RainbowStart.. string.sub(Text, i, i).. RainbowEnd.. HackEnd.. GrowEnd.. FadeEnd
			PlaySound()
			task.wait(Speed or 0.025)
		end
		task.wait(2)
		State = false
	end

	if Mode and Mode == "Create" or Mode == "create" then
		Object.Text = ""
		Object.MaxVisibleGraphemes = -1
		task.spawn(Dialog)
	elseif Mode and Mode == "Continue" or Mode == "continue" then
		task.spawn(Dialog)
	end

	if Object.MaxVisibleGraphemes == -1 then
		Object.MaxVisibleGraphemes = #Text
	elseif Object.MaxVisibleGraphemes > 0 then
		Object.MaxVisibleGraphemes += #Text
	end
end

function TextModule:TypeDelete(Object: TextLabel, Speed: number, Sound: Sound)
	local function PlaySound()
		if Sound then
			Sound.TimePosition = 0
			Sound:Play()
		end
	end

	local function Deleting()
		for i = 1, Object.MaxVisibleGraphemes do
			Object.MaxVisibleGraphemes -= 1
			PlaySound()
			task.wait(Speed or 0.025)
		end
		Object.Text = ""
		Object.MaxVisibleGraphemes = -1
	end

	if Object.MaxVisibleGraphemes == -1 then
		local TextCount = Object.Text       
		Object.MaxVisibleGraphemes = #TextCount
	end

	task.spawn(Deleting)
end

function TextModule:Customize(Table)
	local Text = tostring(Table[1])
	local Settings = {
		Color = {"", [[color="]], [[" ]]};
		Size = {"", [[size="]], [[" ]]};
		Face = {"", [[face="]], [[" ]]};
		Weight = {"", [[weight="]], [[" ]]};
		Transparency = {"", [[transparency="]], [[" ]]};
		Stroke = {[[transparency="1" ]], [[color="]], [[joins="]], [[thickness="]], [[transparency="]], [[" ]]}
	}
	local Special = {
		Bold = {"", "", [[<b>]], [[</b>]]};
		Italic = {"", "", [[<i>]], [[</i>]]};
		Underlined = {"", "", [[<u>]], [[</u>]]};
		Strikethrough = {"", "", [[<s>]], [[</s>]]};
		Uppercase = {"", "", [[<uc>]], [[</uc>]]};
		Smallcaps = {"", "", [[<sc>]], [[</sc>]]};
		Break = {"", [[<br />]]}
	}

	for Key,Value in pairs(Settings)do
		if Table[Key] and not (tostring(Key) == "Stroke")then
			Value[1] = Value[2].. Table[Key].. Value[3]
		elseif Table[Key] and (tostring(Key) == "Stroke")then
			local StrokeColor = Value[2].. Table[Key][1].. Value[6]
			local StrokeJoins = Value[3].. Table[Key][2].. Value[6]
			local StrokeThickness = Value[4].. Table[Key][3].. Value[6]
			local StrokeTransparency = Value[5].. Table[Key][4].. Value[6]

			Value[1] = StrokeColor.. StrokeJoins.. StrokeThickness.. StrokeTransparency
		end
	end

	for Key,Value in pairs(Special)do
		if Table[Key] and Table[Key] == true and not (tostring(Key) == "Break")then
			Value[1] = Value[3]
			Value[2] = Value[4]
		elseif Table[Key] and Table[Key] == true and (tostring(Key) == "Break")then
			Value[1] = Value[2]
		end
	end

	local SpecialTextStart = Special.Bold[1].. Special.Italic[1].. Special.Underlined[1].. Special.Strikethrough[1].. Special.Uppercase[1].. Special.Smallcaps[1]
	local SpecialTextEnd = Special.Smallcaps[2].. Special.Uppercase[2].. Special.Strikethrough[2].. Special.Underlined[2].. Special.Italic[2].. Special.Bold[2]
	local SettingsText = Settings.Color[1].. Settings.Size[1].. Settings.Face[1].. Settings.Weight[1].. Settings.Transparency[1]
	return SpecialTextStart.. [[ <font ]].. SettingsText.. [[>]].. [[<stroke ]].. Settings.Stroke[1].. [[>]].. Special.Break[1].. Text.. [[</stroke> ]].. [[</font>]].. SpecialTextEnd
end

return TextModule
