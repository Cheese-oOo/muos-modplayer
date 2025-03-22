local currentTrackIndex = 1
local isPlaying = false
local files = {}
local directories = {}
local currentSong = nil
local scrollOffset = 0
local visibleCount = 14
local songTime = 0
local songDuration = 0
local songTitle = ""
local currentDirectory = "content"
local font = nil
local highlightColor = {0.2, 0.8, 1}
local textColor = {0.1, 0.4, 0.1}
local dirColor = {0.3, 0.5, 0.3}
local titleColor = {0.6, 0.8, 0.6}
local progressColor = {0.4, 0.6, 0.4}
local colorCycleTime = 0
local colorCycleSpeed = 1
local gameboyBackgroundColor = {0.8, 0.9, 0.8}
local smallFont = nil -- For navigation instructions

-- Function to load files and directories
function loadFiles()
    local extensions = {".mod", ".xm", ".s3m", ".it", ".mtm", ".amf", ".dbm", ".dsm", ".okt", ".psm", ".ult"}
    local directory = love.filesystem.getDirectoryItems(currentDirectory)
    files = {}
    directories = {}

    for _, file in ipairs(directory) do
        local path = currentDirectory .. "/" .. file
        local isDirectory = love.filesystem.getInfo(path, "directory")

        if isDirectory then
            table.insert(directories, file)
        else
            local ext = file:match(".*(%.%a+)$")
            if ext then
                ext = ext:lower()
                for _, validExt in ipairs(extensions) do
                    if ext == validExt then
                        table.insert(files, file)
                        break
                    end
                end
            end
        end
    end
end

-- Load and play a track
function loadTrack(index)
    if currentSong and currentSong:isPlaying() then
        currentSong:stop()
    end

    local trackPath = currentDirectory .. "/" .. files[index]
    local success, source = pcall(love.audio.newSource, trackPath, "stream")
    if success then
        currentSong = source
        currentSong:setLooping(true)
        songDuration = currentSong:getDuration()
        songTime = 0
        songTitle = files[index]:match("(.+)%..+$")
    else
        print("Error loading track: " .. trackPath)
        currentSong = nil
        songDuration = 0
        songTime = 0
        songTitle = "Error Loading"
    end
end

-- Navigate back to the parent directory
function navigateBack()
    if currentDirectory ~= "content" then
        local lastSlashIndex = currentDirectory:match(".*()/")
        if lastSlashIndex then
            currentDirectory = currentDirectory:sub(1, lastSlashIndex - 1)
        end
        loadFiles()
    end
end

function love.load()
    love.window.setMode(800, 600)
    font = love.graphics.newFont(20)
    love.graphics.setFont(font)
    smallFont = love.graphics.newFont(14) -- Create small font
    loadFiles()
    if #files > 0 then
        loadTrack(currentTrackIndex)
    else
        print("No valid music files found.")
    end
end

function love.update(dt)
    if currentSong and currentSong:isPlaying() then
        songTime = currentSong:tell()
    end

    if isPlaying then
        colorCycleTime = colorCycleTime + dt * colorCycleSpeed
    end
end

function love.keypressed(key)
    if key == "space" then
        if currentSong then
            if isPlaying then
                currentSong:stop()
                isPlaying = false
            else
                currentSong:play()
                isPlaying = true
            end
        end
    elseif key == "up" then
        if currentTrackIndex > 1 then
            currentTrackIndex = currentTrackIndex - 1
        end
        if currentTrackIndex < scrollOffset + 1 then
            scrollOffset = scrollOffset - 1
        end
    elseif key == "down" then
        if currentTrackIndex < #directories + #files then
            currentTrackIndex = currentTrackIndex + 1
        end
        if currentTrackIndex > scrollOffset + visibleCount then
            scrollOffset = scrollOffset + 1
        end
    elseif key == "return" then
        if currentTrackIndex <= #directories then
            local dirName = directories[currentTrackIndex]
            currentDirectory = currentDirectory .. "/" .. dirName
            loadFiles()
        elseif currentTrackIndex > #directories and #files > 0 then
            loadTrack(currentTrackIndex - #directories)
            if currentSong then
                currentSong:play()
                isPlaying = true
            end
        end
    elseif key == "backspace" then
        navigateBack()
    end
end

function love.draw()
    love.graphics.clear(gameboyBackgroundColor)

    local red = math.abs(math.sin(colorCycleTime))
    local green = math.abs(math.sin(colorCycleTime + 2))
    local blue = math.abs(math.sin(colorCycleTime + 4))

    love.graphics.setColor(titleColor)

    love.graphics.print("MUOS Mod Player by Cheese", 10, 10)

    local startY = 40
    love.graphics.setColor(textColor)
    love.graphics.print("Current Directory: " .. currentDirectory, 10, startY)
    startY = startY + 30

    for i = scrollOffset + 1, math.min(scrollOffset + visibleCount, #directories + #files) do
        local item, isDirectory
        if i <= #directories then
            item = directories[i]
            isDirectory = true
            love.graphics.setColor(dirColor)
        else
            item = files[i - #directories]
            isDirectory = false
            love.graphics.setColor(textColor)
        end

        if i == currentTrackIndex then
            love.graphics.setColor(highlightColor)
        end
        love.graphics.print((isDirectory and "[DIR] " or "") .. item, 10, startY + ((i - scrollOffset - 1) * 30))
    end

    local function formatTime(seconds)
        local minutes = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d", minutes, secs)
    end

    if isPlaying then
        love.graphics.setColor(red, green, blue)
    else
        love.graphics.setColor(textColor)
    end
    love.graphics.print("Now Playing: " .. (songTitle or "None"), 10, 550)

    love.graphics.setColor(textColor)
    love.graphics.print(formatTime(songTime) .. " / " .. formatTime(songDuration), 600, 550)

    if currentSong and songDuration > 0 then
        local progress = songTime / songDuration
        local barWidth = 300
        love.graphics.setColor(progressColor)
        love.graphics.rectangle("line", 10, 580, barWidth, 10)
        love.graphics.rectangle("fill", 10, 580, progress * barWidth, 10)
    end

    -- Draw navigation instructions with bevelled border
    love.graphics.setColor(0.6, 0.7, 0.6) -- Border color
    love.graphics.rectangle("line", 650, 40, 140, 100) -- Border
    love.graphics.setColor(0.5, 0.6, 0.5) -- Bevel shadow color
    love.graphics.rectangle("line", 651, 41, 138, 98) -- Bevel shadow
    love.graphics.setColor(textColor)
    love.graphics.setFont(smallFont)
    love.graphics.print("Navigation:", 660, 50)
    love.graphics.print("Up/Down: Select", 660, 65)
    love.graphics.print("Return: Enter/Play", 660, 80)
    love.graphics.print("Backspace: Back", 660, 95)
    love.graphics.print("Space: Play/Pause",660, 110)
    love.graphics.setFont(font)
end