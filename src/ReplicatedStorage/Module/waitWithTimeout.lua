--!strict
return function(event: RBXScriptSignal, timeoutInSeconds: number): (boolean, ...any)
	local thread = coroutine.running()
	local connection: RBXScriptConnection?

	local function onEvent(...)
		if not connection then
			return
		end

		connection:Disconnect()
		connection = nil

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, false, ...)
		end
	end

	connection = event:Once(onEvent)

	task.delay(timeoutInSeconds, function()
		if not connection then
			return
		end

		connection:Disconnect()
		connection = nil

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, true)
		end
	end)

	return coroutine.yield()
end