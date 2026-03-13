-- Cooldown.lua
local Cooldown = {}
Cooldown.__index = Cooldown

Cooldown._data = {} -- [char] = { [name] = expireTime }

function Cooldown:Start(char, name, duration)
	if not char or not name or not duration then return false end

	self._data[char] = self._data[char] or {}
	self._data[char][name] = os.clock() + duration
	return true
end

function Cooldown:Check(char, name)
	local charData = self._data[char]
	if not charData then return false end

	local expire = charData[name]
	if not expire then return false end

	if os.clock() >= expire then
		charData[name] = nil
		return false end

	return true, expire - os.clock()
end

function Cooldown:Clear(char, name)
	if self._data[char] then
		self._data[char][name] = nil
	end
end

return Cooldown