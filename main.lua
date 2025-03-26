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
local smallFont = nil
local currentThemeIndex = 1
local currentSoundData = nil
local fileDisplayNameCache = {}
local metaTextAlpha = 0       -- initial alpha (transparent)
local metaTextFadeTime = 2.0  -- duration (in seconds) to fade from 0 to 1
local playBarAlpha = 0       -- initial alpha (transparent) for the play bar
local playBarFadeTime = 2.0    -- duration (in seconds) to fade from 0 to 1




-- Extensions set for fast lookups
local validExtensions = {
    [".mod"] = true, [".xm"] = true, [".s3m"] = true, [".it"] = true,
    [".mtm"] = true, [".amf"] = true, [".dbm"] = true, [".dsm"] = true,
    [".okt"] = true, [".psm"] = true, [".ult"] = true
}

-- Themes definition
local themes = {
    { -- Dark Theme
        highlightColor = {0.7, 0.7, 0.7}, textColor = {0.5, 0.5, 0.5},
        dirColor = {0.6, 0.6, 0.6}, progressColor = {0.4, 0.4, 0.4},
        gameboyBackgroundColor = {0.2, 0.2, 0.2}
    },
{ -- Improved Light Theme with Tweaked Highlight
    highlightColor = {0.0, 0.6, 0.85},
    textColor = {0.2, 0.2, 0.2},
    dirColor = {0.35, 0.35, 0.35},
    progressColor = {0.3, 0.3, 0.3},
    gameboyBackgroundColor = {0.98, 0.98, 0.95}
},




    { -- Blue Theme
        highlightColor = {0.4, 0.6, 0.9}, textColor = {0.3, 0.3, 0.7},
        dirColor = {0.4, 0.4, 0.8}, progressColor = {0.2, 0.2, 0.5},
        gameboyBackgroundColor = {0.1, 0.1, 0.3}
    },
    { -- Green Theme
        highlightColor = {0.5, 0.8, 0.5}, textColor = {0.3, 0.5, 0.3},
        dirColor = {0.4, 0.6, 0.4}, progressColor = {0.2, 0.4, 0.2},
        gameboyBackgroundColor = {0.1, 0.2, 0.1}
    },
    { -- Red Theme
        highlightColor = {0.8, 0.4, 0.4}, textColor = {0.6, 0.2, 0.2},
        dirColor = {0.7, 0.3, 0.3}, progressColor = {0.5, 0.1, 0.1},
        gameboyBackgroundColor = {0.3, 0.1, 0.1}
    }
}

-- Active theme colors
local highlightColor, textColor, dirColor, progressColor, gameboyBackgroundColor

-- Helper to update theme colors
local function updateThemeColors()
    highlightColor = themes[currentThemeIndex].highlightColor
    textColor = themes[currentThemeIndex].textColor
    dirColor = themes[currentThemeIndex].dirColor
    progressColor = themes[currentThemeIndex].progressColor
    gameboyBackgroundColor = themes[currentThemeIndex].gameboyBackgroundColor
end

function parseModFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data then
        return nil, "Failed to read file"
    end

    -- A valid MOD file should be at least 1084 bytes.
    if size < 1084 then
        return nil, "File too short to be a valid MOD file"
    end

    -- Extract the song title from the first 20 bytes using only printable characters.
    local rawTitle = data:sub(1, 20)
    local songNameMod = ""
    for i = 1, #rawTitle do
        local c = rawTitle:sub(i, i)
        local b = string.byte(c)
        if b >= 32 and b <= 126 then  -- only add printable ASCII characters
            songNameMod = songNameMod .. c
        end
    end
    if songNameMod == "" then
        songNameMod = "No Title"
    end

    -- Process the 31 instrument records.
    local instrumentCountFixed = 31  
    local usedInstrumentCount = 0  -- Count instruments with a nonzero sample length.
    local allHaveNames = true     -- Flag to detect if each instrument has a sample name.
    for i = 1, instrumentCountFixed do
        -- Each instrument record is 30 bytes starting at byte 21.
        local recordBase = 20 + (i - 1) * 30
        local sampleName = data:sub(recordBase + 1, recordBase + 22)
        sampleName = sampleName:gsub("%z", "")         -- Remove null characters.
        sampleName = sampleName:match("^%s*(.-)%s*$")    -- Trim whitespace.
        
        local sampleLengthStr = data:sub(recordBase + 23, recordBase + 24)
        local b1 = sampleLengthStr:byte(1) or 0
        local b2 = sampleLengthStr:byte(2) or 0
        local sampleLength = b1 * 256 + b2
        
        if sampleLength > 0 then
            usedInstrumentCount = usedInstrumentCount + 1
        end
        if sampleName == "" then
            allHaveNames = false
        end
    end
    -- If any instrument is missing a name, use a fallback.
    local instrumentsDisplay = allHaveNames and tostring(usedInstrumentCount) or "Data Unavailable"

    -- Extract the pattern order table (128 bytes starting at offset 953)
    local patternOrder = {}
    for i = 1, 128 do
        patternOrder[i] = data:byte(952 + i) or 0
    end
    local maxPattern = 0
    for i = 1, 128 do
        if patternOrder[i] > maxPattern then
            maxPattern = patternOrder[i]
        end
    end
    local patternCount = maxPattern + 1

    -- Determine channel count and tracker info from the magic signature at bytes 1081-1084.
    local magic = data:sub(1081, 1084)
    local channels = 4
    local tracker = "ProTracker"
    if magic == "M.K." or magic == "M!K!" or magic == "FLT4" then
        channels = 4
        tracker = "ProTracker"
    elseif magic == "6CHN" then
        channels = 6
        tracker = "6-Channel MOD"
    elseif magic == "8CHN" then
        channels = 8
        tracker = "8-Channel MOD"
    else
        channels = 4
        tracker = "Unknown MOD format"
    end

    -- Attempt to extract extra meta information (such as the author) from a comment block.
    local author = "Unknown"
    if size > 1084 then
        local extraData = data:sub(1085)
        -- Look for a line starting with "Author:" (case insensitive)
        local foundAuthor = extraData:match("[Aa]uthor:%s*(.-)[\r\n]")
        if foundAuthor and foundAuthor ~= "" then
            author = foundAuthor
        end
    end

    return {
        songName = songNameMod,
        author = author,
        tracker = tracker,
        instrumentCount = usedInstrumentCount,  -- Count of instruments with sample data.
        sampleCount = usedInstrumentCount,        -- For MOD files, each instrument is a sample.
        patternCount = patternCount,
        channels = channels,
        instruments = instrumentsDisplay         -- Either a count or "Data Unavailable"
    }
end

-- Helper to read a little-endian 2-byte integer (if not already defined)
local function readLE2(data, offset)
    local b1 = data:byte(offset) or 0
    local b2 = data:byte(offset + 1) or 0
    return b1 + b2 * 256
end
function parseITFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data then
        return nil, "Failed to read file"
    end

    if size < 192 then
        return nil, "File too short to be a valid IT file"
    end

    -- Verify file signature ("IMPM") to confirm it is an IT file.
    local id = data:sub(1, 4)
    if id ~= "IMPM" then
        return nil, "Not a valid IT file"
    end

    -- Extract the song name (bytes 5 to 30) and trim null characters.
    local songName = data:sub(5, 30):match("^[^%z]+") or "Unnamed"

    -- Read a little-endian word for instrument count at offset 35.
    local instrumentCount = readLE2(data, 35)
    if instrumentCount == 0 then
        instrumentCount = "N/A"
    end

    -- Similarly, read the sample count and pattern count.
    local sampleCount = readLE2(data, 37)
    local patternCount = readLE2(data, 39)

    return {
        songName = songName,
        tracker = "Impulse Tracker",  -- Default tracker value for IT files.
        instrumentCount = instrumentCount,
        sampleCount = sampleCount,
        patternCount = patternCount,
        channels = "N/A"              -- Channel count isn't analyzed.
    }
end



-- Function to switch themes
function cycleTheme()
    currentThemeIndex = (currentThemeIndex % #themes) + 1
    updateThemeColors()
end

-- Function to load files and directories
function loadFiles()
    files, directories = {}, {}
    local directory = love.filesystem.getDirectoryItems(currentDirectory)

    for _, file in ipairs(directory) do
        local path = currentDirectory .. "/" .. file
        local isDirectory = love.filesystem.getInfo(path, "directory")

        if isDirectory then
            table.insert(directories, file)
        else
            local ext = file:match(".*(%.%a+)$"):lower()
            if validExtensions[ext] then
                table.insert(files, file)
            end
        end
    end
end

function loadTrack(index)
    if currentSong and currentSong:isPlaying() then
        currentSong:stop()
    end

    local trackPath = currentDirectory .. "/" .. files[index]
    local extension = trackPath:match("(%.[^%.]+)$"):lower()

    local success, source = pcall(love.audio.newSource, trackPath, "stream")
    if success then
        currentSong = source
        currentSong:setLooping(true)
        songDuration = currentSong:getDuration()
        songTime = 0

        if extension == ".mod" then
            modMetaData, err = parseModFileMetadata(trackPath)
            if not modMetaData then
                print("Error parsing MOD metadata: " .. err)
            end
        elseif extension == ".it" then
            modMetaData, err = parseITFileMetadata(trackPath)
            if not modMetaData then
                print("Error parsing IT metadata: " .. err)
            end
        else
            modMetaData = nil
        end

        local baseFileName = files[index]:match("(.+)%..+$") or "Unknown File"
        -- Add the file name as a separate metadata field.
        if modMetaData then
            modMetaData.filename = baseFileName
        end

        -- Use the file name plus embedded title for Now Playing text.
        if modMetaData and modMetaData.songName and modMetaData.songName ~= "No Title" then
            songTitle = baseFileName .. " (" .. modMetaData.songName .. ")"
        else
            songTitle = baseFileName
        end
    else
        print("Error loading track: " .. trackPath)
        currentSong = nil
        songDuration = 0
        songTime = 0
        songTitle = "Error Loading"
        modMetaData = nil
    end
end


function navigateBack()
    if currentDirectory ~= "content" then
        -- Get the parent directory (without relying on `match()` or `()`):
        local parentDirectory = currentDirectory:match("(.+)/[^/]+$")
        currentDirectory = parentDirectory or "content"
        loadFiles()
    end
end

-- Timer for color cycling
local colorCycleTimer = 0
local colorCycleSpeed = 2  -- Speed of the color cycle

function love.load()
    love.window.setMode(800, 600)
    font = love.graphics.newFont("assets/retro.otf", 20)    -- Load retro font at size 20
    love.graphics.setFont(font)
    smallFont = love.graphics.newFont("assets/retro.otf", 14) -- Load retro font at size 14
    loadFiles()
    currentTrackIndex = 1
    songTitle = "No Track Selected"
    
    -- Ensure the theme colors are initialized
    updateThemeColors()
end

function love.update(dt)
    if currentSong and not currentSong:isPlaying() then
        -- Do not skip to the next track unless the song naturally ends
        songTime = songDuration
    end

    -- Check if the song has reached the end and move to the next track
    if currentSong and currentSong:isPlaying() then
        songTime = currentSong:tell()
        if songTime >= songDuration then
            -- Song has finished, but we don't skip to the next track unless explicitly told
            currentTrackIndex = currentTrackIndex + 1

            -- If we reach the end of the list, wrap around to the start
            if currentTrackIndex > #directories + #files then
                currentTrackIndex = 1
            end

            -- Load and play the next track (if desired)
            if currentTrackIndex > #directories then
                loadTrack(currentTrackIndex - #directories)
                if currentSong then
                    currentSong:play()
                    isPlaying = true
                end
            end
        end
        -- Increase the meta text alpha gradually.
    if metaTextAlpha < 1 then
        metaTextAlpha = math.min(metaTextAlpha + dt / metaTextFadeTime, 1)
    end
    end
    -- Increase the play bar alpha gradually over playBarFadeTime seconds.
    if playBarAlpha < 1 then
        playBarAlpha = math.min(playBarAlpha + dt / playBarFadeTime, 1)
    end
    -- Update the color cycle timer
    colorCycleTimer = colorCycleTimer + dt * colorCycleSpeed
    if colorCycleTimer > 1 then colorCycleTimer = colorCycleTimer - 1 end  -- Reset after a full cycle
end

function love.keypressed(key)
    if key == "space" or key == "a" then
        -- Toggle play/pause
        if currentSong then
            if isPlaying then
                currentSong:stop()
                isPlaying = false
            else
                currentSong:play()
                isPlaying = true
            end
        end
    elseif key == "b" then
        -- Stop playing
        if currentSong and isPlaying then
            currentSong:stop()
            isPlaying = false
        end
    elseif key == "up" then
        -- Navigate up
        if currentTrackIndex > 1 then
            currentTrackIndex = currentTrackIndex - 1
        end
        if currentTrackIndex < scrollOffset + 1 then
            scrollOffset = scrollOffset - 1
        end
    elseif key == "down" then
        -- Navigate down
        if currentTrackIndex < #directories + #files then
            currentTrackIndex = currentTrackIndex + 1
        end
        if currentTrackIndex > scrollOffset + visibleCount then
            scrollOffset = scrollOffset + 1
        end
    elseif key == "return" then
        -- Enter a directory or play a file
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
        -- Navigate back
        navigateBack()
    elseif key == "x" or key == "select" then
        -- Quit the application
        love.event.quit()
    elseif key == "t" then
        -- Cycle themes
        cycleTheme()
    elseif key == "r" then
        -- Randomize: select a random track and play it
        if #files > 0 then
            local randomIndex = math.random(1, #files)
            loadTrack(randomIndex)

            if currentSong then
                currentSong:play()
                isPlaying = true
                -- Update current track index to highlight the selected file in the browser
                currentTrackIndex = randomIndex + #directories
            end

            -- Ensure the browser scrolls to the selected file
            if currentTrackIndex <= scrollOffset then
                scrollOffset = currentTrackIndex - 1
            elseif currentTrackIndex > scrollOffset + visibleCount then
                scrollOffset = currentTrackIndex - visibleCount
            end
        end
    end
end

function love.draw()
    -- Clear the screen with the background color based on the current theme
    love.graphics.clear(gameboyBackgroundColor)

    -- Draw the header with "ModPlayer by Cheese" at the top, adjusting for theme
    love.graphics.setColor(textColor)
    love.graphics.setFont(font)
    -- Draw the header in yellow
    love.graphics.setColor(1, 1, 0)  -- Yellow
    love.graphics.setFont(font)
    love.graphics.print("ModPlayer by Cheese", 10, 10)

    -- Reset the color to your theme's default text color
    love.graphics.setColor(textColor)

-- Define dimensions and corner radius for the file browser background
local browserX = 5
local browserY = 40
local browserWidth = 350
local browserHeight = 30 * (visibleCount + 2)  -- adjust as needed
local cornerRadius = 10

-- Define the colors (these can be adjusted based on your theme)
local baseColor  = {0.1, 0.1, 0.1, 0.8}    -- the main dark background
local lightEdge  = {0.6, 0.6, 0.6, 0.8}    -- light highlight (top and left edges)
local darkEdge   = {0.05, 0.05, 0.05, 0.8}  -- dark shadow (bottom and right edges)

-- Draw the highlight (offset slightly up and to the left)
love.graphics.setColor(lightEdge)
love.graphics.rectangle("fill", browserX - 1, browserY - 1, browserWidth, browserHeight, cornerRadius, cornerRadius)

-- Draw the shadow (offset slightly down and to the right)
love.graphics.setColor(darkEdge)
love.graphics.rectangle("fill", browserX + 1, browserY + 1, browserWidth, browserHeight, cornerRadius, cornerRadius)

-- Finally, draw the main rounded rectangle on top
love.graphics.setColor(baseColor)
love.graphics.rectangle("fill", browserX, browserY, browserWidth, browserHeight, cornerRadius, cornerRadius)


    -- Set the font and color for the rest of the UI
    love.graphics.setFont(smallFont)

    -- Shortcut text
    love.graphics.setColor(highlightColor)
    love.graphics.print("A - Play", 665, 430)
    love.graphics.print("B - Pause", 665, 450)
    love.graphics.print("R - Randomize", 665, 470)
    love.graphics.print("Select - Quit", 665, 490)

    -- Drawing current directory and files
    local startY = 60
    love.graphics.setFont(font)
    love.graphics.setColor(highlightColor)
    love.graphics.print("Current Directory: " .. currentDirectory, 10, startY)
    startY = startY + 30

    local itemXOffset = 30
    for i = scrollOffset + 1, math.min(scrollOffset + visibleCount, #directories + #files) do
        local item, isDirectory
        if i <= #directories then
            item = directories[i]
            isDirectory = true
        else
            item = files[i - #directories]
            isDirectory = false
            if fileDisplayNameCache[item] then
                item = fileDisplayNameCache[item]
            end
        end

        if i == currentTrackIndex then
            love.graphics.setColor(highlightColor)
        elseif isDirectory then
            love.graphics.setColor(dirColor)
        else
            love.graphics.setColor(textColor)
        end
        love.graphics.print((isDirectory and "[DIR] " or "") .. item, itemXOffset, startY + ((i - scrollOffset - 1) * 30))
    end

    -- Scrollbar drawing (Moved down by 30 pixels)
    local scrollBarYOffset = 30  -- Adjust the scroll bar position
    if #directories + #files > visibleCount then
        local barX = 10
        local barY = 60 + scrollBarYOffset  -- Move the bar down by 30 pixels
        local totalHeight = visibleCount * 30
        local totalItems = #directories + #files
        local scrollRatio = scrollOffset / (totalItems - visibleCount)
        local handleHeight = math.max(totalHeight * (visibleCount / totalItems), 10)
        local handleY = barY + scrollRatio * (totalHeight - handleHeight)
        love.graphics.setColor(progressColor)
        love.graphics.rectangle("fill", barX, barY, 5, totalHeight)
        love.graphics.setColor(highlightColor)
        love.graphics.rectangle("fill", barX, handleY, 5, handleHeight)
    end

    -- Time formatting
    local function formatTime(seconds)
        local minutes = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return string.format("%02d:%02d", minutes, secs)
    end

    -- Now Playing text (Using Highlight Color)
    love.graphics.setColor(highlightColor)
    love.graphics.print("Now Playing: " .. (songTitle or "None"), 10, 550)

    -- Song progress display
    love.graphics.print(formatTime(songTime) .. " / " .. formatTime(songDuration), 665, 550)

  if currentSong and songDuration > 0 then
    local progress = songTime / songDuration
    local barWidth = love.graphics.getWidth() - 20
    local barX = 10

    -- Draw the outline of the progress bar:
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], playBarAlpha)
    love.graphics.rectangle("line", barX, 580, barWidth, 10)

    -- Draw the filled progress based on the song progress:
    love.graphics.rectangle("fill", barX, 580, progress * barWidth, 10)
end
    -- Display metadata info, etc.
if modMetaData then
    love.graphics.setFont(font)  -- using the main font for meta text now
    -- Note: textColor is assumed to be a table with three numbers: {r, g, b}
    love.graphics.setColor(textColor[1], textColor[2], textColor[3], metaTextAlpha)
    local metaText =
 love.graphics.setFont(font)  -- Use the main font for metadata.
    love.graphics.setColor(textColor)
    local metaText =
        "Filename: " .. (modMetaData.filename or "Unknown File") .. "\n" ..
        "Song: " .. modMetaData.songName .. "\n" ..
        "Tracker: " .. modMetaData.tracker .. "\n" ..
        "Instruments: " .. modMetaData.instrumentCount .. "\n" ..
        "Samples: " .. modMetaData.sampleCount .. "\n" ..
        "Patterns: " .. modMetaData.patternCount .. "\n" ..
        "Channels: " .. modMetaData.channels
    love.graphics.print(metaText, 375, 150)
end
end
