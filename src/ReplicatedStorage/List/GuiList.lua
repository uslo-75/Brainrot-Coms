local GuiList = {}

GuiList.Settings = {
	rtbx = "rbxassetid://",
}


GuiList.Colors = {
	
	--//[Mutation]//--
	
	["Gold"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0.92549, 0.513725)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 0)),
	},
	
	["Diamond"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.345098, 0.572549, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0.333333, 1)),
	},
	
	["Shiny"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.67451, 0.596078, 0.572549)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	},

	["Spectral"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.1, 0.6, 0.3)),  
		ColorSequenceKeypoint.new(0.5, Color3.new(0.4, 1, 0.4)),  
		ColorSequenceKeypoint.new(1, Color3.new(0.8, 1, 0.9)),
	},

	["Freeze"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0, 0.2, 1)),     
		ColorSequenceKeypoint.new(0.5, Color3.new(0, 0.8, 1)),  
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),    
	},

	["Solar"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),       
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.5, 0)),   
		ColorSequenceKeypoint.new(1, Color3.new(1, 0.9, 0)),     
	},
	
	["BubbleGum"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0.3, 0.6)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.6, 0.8)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 0.9, 0.95)),
	},

	["Volcan"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.35, 0.05, 0.05)), 
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 0.25, 0)),     
		ColorSequenceKeypoint.new(1, Color3.new(1, 0.9, 0.4)),
	},

	["Electric"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0.6, 0)),
		ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 0)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
	},
	
	--//[Rarity]//--
	
	["Commun"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.87451, 0.772549, 0.741176)),
		ColorSequenceKeypoint.new(1, Color3.new(0.87451, 0.772549, 0.741176)),
	},

	["Rare"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0, 0.666667, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0.666667, 1)),
	},

	["Epic"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(0.847059, 0.286275, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(0.333333, 0, 0.498039)),
	},

	["Legendaire"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 0)),
		ColorSequenceKeypoint.new(1, Color3.new(1, 0.92549, 0.513725)),
	},

	["Mythique"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0.164706, 0.247059)),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	},

	["BrainrotGod"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 0, 0)),        
		ColorSequenceKeypoint.new(0.166, Color3.new(1, 1, 0)),    
		ColorSequenceKeypoint.new(0.333, Color3.new(0, 1, 0)),    
		ColorSequenceKeypoint.new(0.5, Color3.new(0, 1, 1)),      
		ColorSequenceKeypoint.new(0.666, Color3.new(0, 0, 1)),    
		ColorSequenceKeypoint.new(0.833, Color3.new(1, 0, 1)),    
		ColorSequenceKeypoint.new(1, Color3.new(1, 0, 0)),
	},

	["Secret"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), 
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	},
	
	
	["Exotique"] = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), 
		ColorSequenceKeypoint.new(1, Color3.new(0, 0.666667, 1)),
	},
	
	
}


GuiList.Auras = {
	["Fire"] = {logo = 0, Color = Color3.new(0,0,0)}
}

GuiList.ColorList = {
	["Red"] = Color3.fromRGB(255, 0, 0),
	["Blue"] = Color3.fromRGB(0, 0, 255),
	["White"] = Color3.fromRGB(255, 255, 255),
	["Black"] = Color3.fromRGB(0, 0, 0),
	["Green"] = Color3.fromRGB(0, 255, 0),
	["Yellow"] = Color3.fromRGB(255, 255, 0),
	["Orange"] = Color3.fromRGB(255, 165, 0),
	["Purple"] = Color3.fromRGB(128, 0, 128),
	["Pink"] = Color3.fromRGB(255, 192, 203),
	["Brown"] = Color3.fromRGB(139, 69, 19),
	["Gray"] = Color3.fromRGB(128, 128, 128),
	["LightGray"] = Color3.fromRGB(211, 211, 211),
	["DarkGray"] = Color3.fromRGB(64, 64, 64),
	["Cyan"] = Color3.fromRGB(0, 255, 255),
	["Magenta"] = Color3.fromRGB(255, 0, 255),
	["Lime"] = Color3.fromRGB(50, 205, 50),
	["Teal"] = Color3.fromRGB(0, 128, 128),
	["Navy"] = Color3.fromRGB(0, 0, 128),
	["Maroon"] = Color3.fromRGB(128, 0, 0),
	["Olive"] = Color3.fromRGB(128, 128, 0),
	["Gold"] = Color3.fromRGB(255, 215, 0),
	["Silver"] = Color3.fromRGB(192, 192, 192),
	["Beige"] = Color3.fromRGB(245, 245, 220),
	["Turquoise"] = Color3.fromRGB(64, 224, 208),
	["Indigo"] = Color3.fromRGB(75, 0, 130),
	["Violet"] = Color3.fromRGB(238, 130, 238),
	["Coral"] = Color3.fromRGB(255, 127, 80),
	["Salmon"] = Color3.fromRGB(250, 128, 114),
	["Crimson"] = Color3.fromRGB(220, 20, 60),
	["Khaki"] = Color3.fromRGB(240, 230, 140),
	["Mint"] = Color3.fromRGB(152, 255, 152),
	["Peach"] = Color3.fromRGB(255, 218, 185),
	["Lavender"] = Color3.fromRGB(230, 230, 250),
	["Aqua"] = Color3.fromRGB(0, 255, 255),
	["SkyBlue"] = Color3.fromRGB(135, 206, 235),
	["DarkBlue"] = Color3.fromRGB(0, 0, 139),
	["DarkGreen"] = Color3.fromRGB(0, 100, 0),
	["LightBlue"] = Color3.fromRGB(173, 216, 230),
	["LightGreen"] = Color3.fromRGB(144, 238, 144)
}


return GuiList
