local RP = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local ClientSettings = require(RP:WaitForChild("Module"):WaitForChild("ClientSettings"))
local GameConfig = require(RP:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local musicConfig = GameConfig.Music

local defaultPlaylistFolder = SoundService:WaitForChild(musicConfig.DefaultPlaylistFolder)
local DISCO_PLAYLIST_FOLDER_NAMES = musicConfig.DiscoPlaylistFolders
local lastSongByFolder = {}
local currentSong = nil
local musicEnabled = true
local playbackToken = 0
local activePlaylistFolder = defaultPlaylistFolder
local SONG_STALL_TIMEOUT = musicConfig.SongStallTimeout

local function findDiscoPlaylistFolder()
	for _, folderName in ipairs(DISCO_PLAYLIST_FOLDER_NAMES) do
		local folder = SoundService:FindFirstChild(folderName)
		if folder and folder:IsA("Folder") then
			return folder
		end
	end

	return nil
end

local function isDiscoPlaylistFolder(instance)
	if not (instance and instance:IsA("Folder")) then
		return false
	end

	for _, folderName in ipairs(DISCO_PLAYLIST_FOLDER_NAMES) do
		if instance.Name == folderName then
			return true
		end
	end

	return false
end

local function getDesiredPlaylistFolder()
	if Workspace:GetAttribute("ActiveAdminAbuse") == "Disco" then
		return findDiscoPlaylistFolder() or defaultPlaylistFolder
	end

	return defaultPlaylistFolder
end

local function getSongs(folder)
	local songs = {}
	if not folder then
		return songs
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") then
			table.insert(songs, child)
		end
	end

	return songs
end

local function pickNextSong(folder)
	local songs = getSongs(folder)
	if #songs == 0 then
		return nil
	end

	local lastSong = lastSongByFolder[folder]
	local nextSong = nil

	repeat
		nextSong = songs[math.random(1, #songs)]
	until nextSong ~= lastSong or #songs == 1

	lastSongByFolder[folder] = nextSong
	return nextSong
end

local function stopFolderSongs(folder)
	if not folder then
		return
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Sound") and child.IsPlaying then
			child:Stop()
		end
	end
end

local function stopAllPlaylistSongs()
	stopFolderSongs(defaultPlaylistFolder)
	stopFolderSongs(findDiscoPlaylistFolder())
end

local function stopCurrentSong()
	if currentSong and currentSong.IsPlaying then
		currentSong:Stop()
		currentSong.TimePosition = 0
	end

	currentSong = nil
end

local function runPlaylist(token)
	while playbackToken == token do
		if not musicEnabled then
			stopAllPlaylistSongs()
			stopCurrentSong()
			return
		end

		activePlaylistFolder = getDesiredPlaylistFolder()
		local playlistFolder = activePlaylistFolder
		local nextSong = pickNextSong(playlistFolder)
		if not nextSong then
			task.wait(1)
			continue
		end

		currentSong = nextSong
		local finished = false
		local endedConnection = nextSong.Ended:Connect(function()
			finished = true
		end)
		local stoppedConnection = nextSong.Stopped:Connect(function()
			finished = true
		end)
		local startedAt = os.clock()

		nextSong.TimePosition = 0
		nextSong:Play()

		repeat
			task.wait(0.1)
		until
			playbackToken ~= token
			or not musicEnabled
			or finished
			or nextSong.Parent ~= playlistFolder
			or activePlaylistFolder ~= playlistFolder
			or (not nextSong.IsPlaying and (os.clock() - startedAt) >= SONG_STALL_TIMEOUT)

		endedConnection:Disconnect()
		stoppedConnection:Disconnect()

		if playbackToken ~= token or not musicEnabled then
			stopAllPlaylistSongs()
			stopCurrentSong()
			return
		end

		if activePlaylistFolder ~= playlistFolder and nextSong.IsPlaying then
			nextSong:Stop()
			nextSong.TimePosition = 0
		end

		currentSong = nil
	end
end

local function restartPlaylist()
	playbackToken += 1
	activePlaylistFolder = getDesiredPlaylistFolder()
	stopAllPlaylistSongs()
	stopCurrentSong()
	task.spawn(runPlaylist, playbackToken)
end

ClientSettings:WaitUntilLoaded(10)
musicEnabled = ClientSettings:GetToggle("MusicEnabled")

ClientSettings:ObserveToggle("MusicEnabled", function(value)
	musicEnabled = value == true

	if musicEnabled then
		if currentSong == nil or not currentSong.IsPlaying then
			restartPlaylist()
		end
	else
		playbackToken += 1
		stopAllPlaylistSongs()
		stopCurrentSong()
	end
end, false)

Workspace:GetAttributeChangedSignal("ActiveAdminAbuse"):Connect(function()
	if musicEnabled then
		restartPlaylist()
	else
		activePlaylistFolder = getDesiredPlaylistFolder()
		stopAllPlaylistSongs()
	end
end)

SoundService.ChildAdded:Connect(function(child)
	if isDiscoPlaylistFolder(child) and Workspace:GetAttribute("ActiveAdminAbuse") == "Disco" and musicEnabled then
		restartPlaylist()
	end
end)

SoundService.ChildRemoved:Connect(function(child)
	if isDiscoPlaylistFolder(child) and musicEnabled then
		restartPlaylist()
	end
end)

if musicEnabled then
	restartPlaylist()
end
