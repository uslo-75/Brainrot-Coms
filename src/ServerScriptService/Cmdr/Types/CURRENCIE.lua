local CURRENCIE = {
	"Cash",
	"Roll",
	"Steal",
	
}

return function (registry)
	registry:RegisterType("currency", registry.Cmdr.Util.MakeEnumType("currency", CURRENCIE))
end