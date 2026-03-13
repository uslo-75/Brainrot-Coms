local ServerScriptService = game:GetService("ServerScriptService")

local CmdrConfig = require(game.ServerStorage.Config.Cmdr)
local Cmdr = require(ServerScriptService.Package.Cmdr)

local Commands = script.Parent.Commands
local Types = script.Parent.Types
local Hooks = script.Parent.Hooks

Cmdr:RegisterDefaultCommands()
Cmdr:RegisterCommandsIn(Commands)
Cmdr:RegisterTypesIn(Types)
Cmdr:RegisterHooksIn(Hooks)

Cmdr:RegisterHook("BeforeRun", function(context)
	local userId = context.Executor.UserId
	local isAdmin = table.find(CmdrConfig.Admins, userId) ~= nil
	local IAdminsCommand = context.Group == "Admin"
	if IAdminsCommand and not isAdmin then
		return "Tu n'as pas les permissions pour cette commande !"
	end

	if not isAdmin then
		return "Tu n'as pas les permissions pour cette commande !"
	end
end)