local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CmdrTypeLists = require(ReplicatedStorage.List.CmdrTypeLists)

return function(registry)
	registry:RegisterType("brairotName", registry.Cmdr.Util.MakeEnumType("brairotName", CmdrTypeLists.BrainrotNames))
	registry:RegisterType("brairotMutation", registry.Cmdr.Util.MakeEnumType("brairotMutation", CmdrTypeLists.Mutations))
	registry:RegisterType("mapMutation", registry.Cmdr.Util.MakeEnumType("mapMutation", CmdrTypeLists.MapMutations))
	registry:RegisterType("mapMutationScope", registry.Cmdr.Util.MakeEnumType("mapMutationScope", CmdrTypeLists.MapMutationScopes))
	registry:RegisterType("adminAbuse", registry.Cmdr.Util.MakeEnumType("adminAbuse", CmdrTypeLists.AdminAbuses))
	registry:RegisterType("auraList", registry.Cmdr.Util.MakeEnumType("auraList", CmdrTypeLists.Auras))
	registry:RegisterType("typesList", registry.Cmdr.Util.MakeEnumType("typesList", CmdrTypeLists.TypesList))
	registry:RegisterType("globaleTypesList", registry.Cmdr.Util.MakeEnumType("globaleTypesList", CmdrTypeLists.GlobaleTypesList))
	registry:RegisterType("colorList", registry.Cmdr.Util.MakeEnumType("colorList", CmdrTypeLists.ColorList))
end
