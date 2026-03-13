local MessagingService = game:GetService("MessagingService")

return function(context, LuckBuff: number, Time: number?)
	local player = context.Executor

	if typeof(LuckBuff) ~= "number" or LuckBuff ~= LuckBuff or LuckBuff <= 0 or math.abs(LuckBuff) == math.huge then
		return "Luck invalide."
	end

	local duration = tonumber(Time) or 900
	if duration ~= duration or math.abs(duration) == math.huge then
		return "Temps invalide."
	end

	duration = math.clamp(math.floor(duration), 1, 86400)
	local formattedLuck = string.format("%.2f", LuckBuff):gsub("%.?0+$", "")
	local messageString = string.format("%s a ajoute la Luck x%s.", player.Name, formattedLuck)

	local success, err = pcall(MessagingService.PublishAsync, MessagingService, "GlobalLuckEvent", {
		Luck = LuckBuff,
		Time = duration,
		Message = messageString,
	})

	if not success then
		warn("[Cmdr.LuckServer] PublishAsync failed:", err)
		return "Impossible d'envoyer le buff global."
	end

	return `Luck globale x{formattedLuck} envoyee pour {duration}s.`
end
