-- The brain of our operation - keeping track of what's what
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

-- For when you want your UI to be as smooth as butter
local currentThemeIndex = 1
local currentSoundData = nil
local fileDisplayNameCache = {}
local metaTextAlpha = 0       -- Starts invisible, like a ninja
local metaTextFadeTime = 2.0  -- Time to reveal our ninja
local playBarAlpha = 0        -- Another stealthy element
local playBarFadeTime = 2.0   -- Time to unmask the progress bar
local metaBoxAlpha = 0
local metaBoxFadeTime = 1.5

-- Instrument scroll physics - because why not add some bouncy fun?
local instrumentScrollOffset = 0
local instrumentScrollDirection = 1  -- 1 for down, -1 for up (gravity is optional)
local instrumentScrollSpeed = 15     -- Speed in pixels/sec (not quite light speed)
local instrumentRubberBandAmplitude = 0.1  -- How much jelly-like bounce we want
local instrumentScrollPause = 0      -- Taking a breather between scrolls

-- The chosen ones - file types we actually care about
local validExtensions = {
    [".mod"] = true, [".xm"] = true, [".s3m"] = true, [".it"] = true,
    [".mtm"] = true, [".amf"] = true, [".dbm"] = true, [".dsm"] = true,
    [".okt"] = true, [".psm"] = true, [".ult"] = true
}

-- UI Constants - because magic numbers are for wizards
local UI = {
    padding = 10,        -- Personal space for UI elements
    margin = 10,         -- The social distancing of UI
    cornerRadius = 10,   -- How round do you like your corners?
    panelOpacity = 0.8,  -- Just transparent enough to be mysterious
    borderOpacity = 0.6, -- The ghost of borders past
    width = love.graphics.getWidth(),
    height = love.graphics.getHeight(),
}

-- Panel dimensions - making sure everything fits like a well-tailored suit
UI.leftPanelWidth = 350
UI.rightPanelWidth = UI.width - UI.leftPanelWidth - (UI.margin * 3)
UI.headerHeight = 35
UI.shortcutsHeight = 35  -- Height for our handy shortcuts panel
UI.nowPlayingHeight = 35
UI.progressBarHeight = 10
UI.progressBarOffset = 5  -- Because perfect alignment is overrated
UI.bottomSpacing = UI.margin * 2  -- Extra breathing room at the bottom
UI.metadataHeight = 180  -- For all that juicy track info

-- Calculate positions for bottom elements first
UI.shortcutsY = UI.height - (
    UI.bottomSpacing +
    UI.progressBarHeight +
    UI.nowPlayingHeight +
    UI.margin +
    UI.shortcutsHeight
)

UI.nowPlayingY = UI.shortcutsY + UI.shortcutsHeight + UI.margin
UI.progressY = UI.nowPlayingY + UI.nowPlayingHeight

-- Calculate vertical spacing for right panels (it's like Tetris, but with UI)
UI.rightStartY = UI.margin
UI.metadataEndY = UI.rightStartY + UI.metadataHeight
UI.instrumentsStartY = UI.metadataEndY + UI.margin

-- Calculate instruments height to extend down to shortcuts bar
UI.instrumentsHeight = UI.shortcutsY - UI.instrumentsStartY - UI.margin

-- Calculate browser height to fit perfectly above shortcuts
UI.browserHeight = UI.height - (
    UI.margin +                -- Top margin
    UI.headerHeight +          -- Header space
    UI.margin +               -- Space after header
    UI.margin +               -- Space before shortcuts
    UI.shortcutsHeight +      -- Shortcuts panel
    UI.margin +               -- Space before now playing
    UI.nowPlayingHeight +     -- Now playing panel
    UI.progressBarHeight +    -- Progress bar
    UI.bottomSpacing          -- Bottom breathing room
)

-- Themes - because life is too short for monochrome
local themes = {
    { -- Dark Theme: For those who think light mode is too mainstream
        highlightColor = {0.7, 0.7, 0.7}, 
        textColor = {0.5, 0.5, 0.5},
        dirColor = {0.6, 0.6, 0.6}, 
        progressColor = {0.4, 0.4, 0.4},
        gameboyBackgroundColor = {0.2, 0.2, 0.2}
    },
    { -- Light Theme: For the brave souls who dare to burn their retinas
        highlightColor = {0.0, 0.4, 0.8},    -- Darker blue for better contrast
        textColor = {0.1, 0.1, 0.1},         -- Nearly black text
        dirColor = {0.2, 0.2, 0.4},          -- Darker directory color
        progressColor = {0.2, 0.3, 0.5},      -- Darker progress color
        gameboyBackgroundColor = {0.95, 0.95, 0.98}  -- Slightly cooler white
    },
    { -- Synthwave: Because the 80s never truly died
        highlightColor = {0.91, 0.34, 0.89},
        textColor = {0.33, 0.83, 0.95},
        dirColor = {0.92, 0.37, 0.71},
        progressColor = {0.47, 0.18, 0.64},
        gameboyBackgroundColor = {0.13, 0.07, 0.23}
    },
    { -- Forest: For when you miss touching grass
        highlightColor = {0.45, 0.85, 0.37},
        textColor = {0.78, 0.95, 0.45},
        dirColor = {0.37, 0.65, 0.35},
        progressColor = {0.25, 0.45, 0.22},
        gameboyBackgroundColor = {0.12, 0.18, 0.12}
    },
    { -- Amber Terminal: Because you watched too many hacker movies
        highlightColor = {1.0, 0.75, 0.0},
        textColor = {0.9, 0.6, 0.0},
        dirColor = {0.8, 0.5, 0.0},
        progressColor = {0.6, 0.4, 0.0},
        gameboyBackgroundColor = {0.15, 0.1, 0.0}
    },
    { -- Ocean: Deeper than your code's complexity
        highlightColor = {0.0, 0.85, 1.0},
        textColor = {0.4, 0.8, 0.9},
        dirColor = {0.2, 0.6, 0.8},
        progressColor = {0.1, 0.4, 0.6},
        gameboyBackgroundColor = {0.05, 0.15, 0.25}
    },
    { -- Sunset: For the romantic coders
        highlightColor = {1.0, 0.6, 0.2},
        textColor = {0.95, 0.75, 0.55},
        dirColor = {0.85, 0.45, 0.3},
        progressColor = {0.7, 0.3, 0.2},
        gameboyBackgroundColor = {0.2, 0.1, 0.15}
    },
    { -- Matrix: In case Neo needs to play some tunes
        highlightColor = {0.0, 1.0, 0.0},
        textColor = {0.0, 0.8, 0.0},
        dirColor = {0.0, 0.6, 0.0},
        progressColor = {0.0, 0.4, 0.0},
        gameboyBackgroundColor = {0.05, 0.1, 0.05}
    },
    { -- Pastel: Soft on the eyes, easy on the soul
        highlightColor = {0.95, 0.7, 0.85},
        textColor = {0.7, 0.8, 0.9},
        dirColor = {0.8, 0.7, 0.8},
        progressColor = {0.6, 0.7, 0.8},
        gameboyBackgroundColor = {0.95, 0.95, 0.98}
    },
    { -- Coffee: For those coding at 3 AM
        highlightColor = {0.8, 0.6, 0.4},
        textColor = {0.6, 0.4, 0.3},
        dirColor = {0.5, 0.35, 0.25},
        progressColor = {0.4, 0.25, 0.15},
        gameboyBackgroundColor = {0.15, 0.1, 0.08}
    },
    { -- Neon: Warning - may cause spontaneous dance parties
        highlightColor = {1.0, 0.2, 0.6},
        textColor = {0.2, 1.0, 0.8},
        dirColor = {0.8, 0.2, 1.0},
        progressColor = {0.6, 0.1, 0.8},
        gameboyBackgroundColor = {0.1, 0.1, 0.15}
    },
    { -- Monochrome: When you're feeling extra serious
        highlightColor = {1.0, 1.0, 1.0},
        textColor = {0.8, 0.8, 0.8},
        dirColor = {0.6, 0.6, 0.6},
        progressColor = {0.4, 0.4, 0.4},
        gameboyBackgroundColor = {0.0, 0.0, 0.0}
    }
}

-- Time formatting - because seconds since epoch is so 1970
local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d", minutes, secs)
end

-- The color wizard - making sure our theme colors are always ready
local function updateThemeColors()
    highlightColor = themes[currentThemeIndex].highlightColor
    textColor = themes[currentThemeIndex].textColor
    dirColor = themes[currentThemeIndex].dirColor
    progressColor = themes[currentThemeIndex].progressColor
    gameboyBackgroundColor = themes[currentThemeIndex].gameboyBackgroundColor
end

-- Helper function to sanitize strings that might contain invalid UTF-8
local function sanitizeString(str)
    local result = ""
    -- First remove null bytes
    str = str:gsub("%z", "")
    
    -- Then keep only valid printable characters
    for i = 1, #str do
        local byte = str:byte(i)
        if byte >= 32 and byte <= 126 then  -- Only keep printable ASCII characters
            result = result .. string.char(byte)
        end
    end
    -- Trim whitespace and return
    return (result:match("^%s*(.-)%s*$")) or ""
end

function parseModFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data then
        return nil, "Failed to read file"
    end

    -- A valid MOD file should be at least 1084 bytes
    if size < 1084 then
        return nil, "File too short to be a valid MOD file"
    end

    -- Extract the song title from the first 20 bytes
    local rawTitle = data:sub(1, 20)
    local songNameMod = ""
    for i = 1, #rawTitle do
        local c = rawTitle:sub(i, i)
        local b = string.byte(c)
        if b >= 32 and b <= 126 then
            songNameMod = songNameMod .. c
        end
    end
    if songNameMod == "" then
        songNameMod = "No Title"
    end

    -- Get default MOD tempo and BPM
    -- MOD files typically use 6 ticks per row at 125 BPM
    local defaultTempo = 6  -- ticks per row
    local defaultBPM = 125

    -- Try to read tempo from the file (offset 950-951 in some MOD variants)
    local tempoBytes = data:sub(950, 951)
    if #tempoBytes == 2 then
        local tempo = string.byte(tempoBytes, 1) * 256 + string.byte(tempoBytes, 2)
        if tempo > 0 and tempo < 256 then
            defaultTempo = tempo
        end
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
    local instruments = {} -- Table to store instrument names
    for i = 1, instrumentCountFixed do
        local recordBase = 20 + (i - 1) * 30
        local sampleName = data:sub(recordBase + 1, recordBase + 22)
        sampleName = sampleName:gsub("%z", "") -- Remove null characters
        sampleName = sampleName:match("^%s*(.-)%s*$") -- Trim whitespace

        if sampleName ~= "" then
            table.insert(instruments, sampleName)
        end
    end

    -- Store the instrument names in metadata
    local instrumentsDisplay = #instruments > 0 and instruments or {"No Instruments Found"}

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
        tempo = defaultTempo,
        bpm = defaultBPM,
        instrumentCount = usedInstrumentCount,
        sampleCount = usedInstrumentCount,
        patternCount = patternCount,
        channels = channels,
        instruments = instrumentsDisplay
    }
end

-- Helper to read a little-endian 2-byte integer (if not already defined)
local function readLE2(data, offset)
    local b1 = data:byte(offset) or 0
    local b2 = data:byte(offset + 1) or 0
    return b1 + b2 * 256
end

local function readLE4(data, offset)
    local b1 = data:byte(offset) or 0
    local b2 = data:byte(offset+1) or 0
    local b3 = data:byte(offset+2) or 0
    local b4 = data:byte(offset+3) or 0
    return b1 + b2*256 + b3*65536 + b4*16777216
end

function parseITFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data then return nil, "Failed to read file" end

    if size < 192 then return nil, "File too short" end
    if data:sub(1, 4) ~= "IMPM" then return nil, "Not valid IT file" end

    -- Basic headers
    local songName = sanitizeString(data:sub(5, 30)) or "Unnamed"
    
    -- Read tempo and speed from IT header
    local tempo = string.byte(data:sub(50, 50)) or 6
    local bpm = string.byte(data:sub(51, 51)) or 125

    -- Read counts from header
    local ordNum = readLE2(data, 32)      -- Number of orders
    local insNum = readLE2(data, 34)      -- Number of instruments
    local smpNum = readLE2(data, 36)      -- Number of samples
    local patNum = readLE2(data, 38)      -- Number of patterns

    -- Read instrument and sample names
    local instruments = {}
    local headerSize = 192
    local offset = headerSize

    -- Skip order list
    offset = offset + ordNum

    -- Get instrument offsets
    local instrumentOffsets = {}
    for i = 1, insNum do
        local insOffset = readLE4(data, offset + (i-1) * 4)
        if insOffset > 0 and insOffset < size then
            table.insert(instrumentOffsets, insOffset)
        end
    end
    offset = offset + (insNum * 4)

    -- Get sample offsets
    local sampleOffsets = {}
    for i = 1, smpNum do
        local smpOffset = readLE4(data, offset + (i-1) * 4)
        if smpOffset > 0 and smpOffset < size then
            table.insert(sampleOffsets, smpOffset)
        end
    end

    -- Read instrument names from their actual offsets
    for i, insOffset in ipairs(instrumentOffsets) do
        if insOffset + 32 <= size then
            local nameData = data:sub(insOffset + 1, insOffset + 26)  -- Name starts 1 byte into instrument header
            local name = sanitizeString(nameData)
            if name ~= "" then
                instruments[i] = string.format("%02d: %s", i, name)
            end
        end
    end

    -- Merge sample names with instruments
    for i, smpOffset in ipairs(sampleOffsets) do
        if smpOffset + 32 <= size then
            local nameData = data:sub(smpOffset + 1, smpOffset + 26)  -- Name starts 1 byte into sample header
            local name = sanitizeString(nameData)
            if name ~= "" then
                if instruments[i] then
                    instruments[i] = instruments[i] .. " / " .. string.format("Sample %02d: %s", i, name)
                else
                    instruments[i] = string.format("Sample %02d: %s", i, name)
                end
            end
        end
    end

    -- If still no names found, provide default message
    if #instruments == 0 then
        if insNum > 0 or smpNum > 0 then
            instruments = {"No named instruments/samples found"}
        else
            instruments = {"No instruments or samples"}
        end
    end

    return {
        songName = songName,
        tracker = "Impulse Tracker",
        tempo = tempo,
        bpm = bpm,
        instrumentCount = insNum,
        sampleCount = smpNum,
        patternCount = patNum,
        channels = 64,  -- IT supports up to 64 channels
        instruments = instruments
    }
end

function parseXMFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 336 then  -- XM header is 336 bytes
        return nil, "File too short to be a valid XM file"
    end

    if data:sub(1, 17) ~= "Extended Module:" then
        return nil, "Not a valid XM file"
    end

    -- Extract song name (bytes 18 to 37)
    local songName = data:sub(18, 37):match("^[^%z]+") or "Unnamed"
    
    -- Extract tracker name (bytes 38 to 57)
    local trackerName = data:sub(38, 57):match("^[^%z]+") or "Unknown Tracker"

    -- Read tempo and BPM from header
    -- In XM format, these are at offset 76 (default tempo) and 78 (default BPM)
    local defaultTempo = string.byte(data:sub(76, 76)) or 6
    local defaultBPM = string.byte(data:sub(78, 78)) or 125

    -- Read other header information
    local headerSize = readLE4(data, 60)
    local songLength = string.byte(data:sub(64, 64))
    local patternCount = string.byte(data:sub(70, 70))
    local instrumentCount = readLE2(data, 72)
    local flags = readLE2(data, 74)
    local channelCount = readLE2(data, 68)

    return {
        songName = songName,
        tracker = trackerName,
        tempo = defaultTempo,
        bpm = defaultBPM,
        instrumentCount = instrumentCount,
        sampleCount = instrumentCount,  -- In XM, typically same as instrument count
        patternCount = patternCount,
        channels = channelCount
    }
end

function parseS3MFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 96 then
        return nil, "File too short to be a valid S3M file"
    end

    if data:sub(1, 4) ~= "SCRM" then
        return nil, "Not a valid S3M file"
    end

    local songName = data:sub(5, 28):match("^[^%z]+") or "Unnamed"
    local instrumentCount = data:byte(30) or 0
    local patternCount = data:byte(32) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = "Scream Tracker",
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parseMTMFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 100 then
        return nil, "File too short to be a valid MTM file"
    end

    if data:sub(1, 4) ~= "MTM " then
        return nil, "Not a valid MTM file"
    end

    local songName = data:sub(5, 28):match("^[^%z]+") or "Unnamed"
    local instrumentCount = data:byte(29) or 0
    local patternCount = data:byte(30) or 0
    local channels = data:byte(31) or "N/A"

    return {
        songName = songName,
        author = "Unknown",
        tracker = "MultiTracker",
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = channels
    }
end

function parseAMFFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 50 then
        return nil, "File too short to be a valid AMF file"
    end

    local signature = data:sub(1, 4)
    if signature ~= "AMF0" and signature ~= "AMF1" then
        return nil, "Not a valid AMF file"
    end

    local songName = data:sub(5, 36):match("^[^%z]+") or "Unnamed"
    local tracker = "Advanced Music Format"
    local patternCount = data:byte(37) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = "N/A",
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parseDBMFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 60 then
        return nil, "File too short to be a valid DBM file"
    end

    local signature = data:sub(1, 4)
    if signature ~= "DBM0" then
        return nil, "Not a valid DBM file"
    end

    local songName = data:sub(5, 36):match("^[^%z]+") or "Unnamed"
    local tracker = "DigiBooster Pro"
    local patternCount = data:byte(37) or 0
    local instrumentCount = data:byte(38) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parseDSMFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 60 then
        return nil, "File too short to be a valid DSM file"
    end

    if data:sub(1, 4) ~= "DSMF" then
        return nil, "Not a valid DSM file"
    end

    local songName = data:sub(5, 28):match("^[^%z]+") or "Unnamed"
    local tracker = "Digital Sound Module"
    local instrumentCount = data:byte(29) or 0
    local patternCount = data:byte(30) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parseOKTFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 40 then
        return nil, "File too short to be a valid OKT file"
    end

    if data:sub(1, 8) ~= "OKTASONG" then
        return nil, "Not a valid OKT file"
    end

    local songName = "Unnamed" -- OKT files often don't have a song name
    local tracker = "Oktalyzer"
    local patternCount = data:byte(9) or 0
    local instrumentCount = data:byte(10) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parsePSMFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 40 then
        return nil, "File too short to be a valid PSM file"
    end

    if data:sub(1, 4) ~= "PSM " then
        return nil, "Not a valid PSM file"
    end

    local songName = data:sub(5, 36):match("^[^%z]+") or "Unnamed"
    local tracker = "ProTracker Studio"
    local patternCount = data:byte(37) or 0
    local instrumentCount = data:byte(38) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
    }
end

function parseULTFileMetadata(filePath)
    local data, size = love.filesystem.read(filePath)
    if not data or size < 60 then
        return nil, "File too short to be a valid ULT file"
    end

    if data:sub(1, 4) ~= "MAS_UTrack_V00" then
        return nil, "Not a valid ULT file"
    end

    local songName = data:sub(5, 36):match("^[^%z]+") or "Unnamed"
    local tracker = "UltraTracker"
    local patternCount = data:byte(37) or 0
    local instrumentCount = data:byte(38) or 0

    return {
        songName = songName,
        author = "Unknown",
        tracker = tracker,
        instrumentCount = instrumentCount,
        sampleCount = "N/A",
        patternCount = patternCount,
        channels = "N/A"
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
        songTitle = files[index]:match("(.+)%..+$")

        -- Call the corresponding parser based on file extension
        if extension == ".mod" then
            modMetaData, err = parseModFileMetadata(trackPath)
        elseif extension == ".it" then
            modMetaData, err = parseITFileMetadata(trackPath)
        elseif extension == ".xm" then
            modMetaData, err = parseXMFileMetadata(trackPath)
        elseif extension == ".s3m" then
            modMetaData, err = parseS3MFileMetadata(trackPath)
        elseif extension == ".mtm" then
            modMetaData, err = parseMTMFileMetadata(trackPath)
        elseif extension == ".amf" then
            modMetaData, err = parseAMFFileMetadata(trackPath)
        elseif extension == ".dbm" then
            modMetaData, err = parseDBMFileMetadata(trackPath)
        elseif extension == ".dsm" then
            modMetaData, err = parseDSMFileMetadata(trackPath)
        elseif extension == ".okt" then
            modMetaData, err = parseOKTFileMetadata(trackPath)
        elseif extension == ".psm" then
            modMetaData, err = parsePSMFileMetadata(trackPath)
        elseif extension == ".ult" then
            modMetaData, err = parseULTFileMetadata(trackPath)
        else
            modMetaData = nil
            err = "Unsupported file format"
        end

        if not modMetaData then
            print("Error parsing metadata: " .. err)
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
    font = love.graphics.newFont("assets/retro.otf", 22)    -- Load retro font at size 22
    love.graphics.setFont(font)
    smallFont = love.graphics.newFont("assets/retro.otf", 16) -- Load retro font at size 16
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
    if instrumentScrollPause > 0 then
        instrumentScrollPause = instrumentScrollPause - dt
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
    
    if currentSong and isPlaying then
        metaBoxAlpha = math.min(metaBoxAlpha + dt / metaBoxFadeTime, 1)
    else
        metaBoxAlpha = math.max(metaBoxAlpha - dt / metaBoxFadeTime, 0)
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

-- Function to draw instrument names
local function drawInstrumentName(i, yPos, rightPanelX, metaBoxAlpha)
    love.graphics.setColor(0.8, 0.8, 0.8, metaBoxAlpha)
    love.graphics.print(i .. ":", rightPanelX + 30, yPos)
    
    local displayName = modMetaData.instruments[i]
    if displayName then  -- Ensure displayName is not nil
        if #displayName > 30 then
            displayName = displayName:sub(1, 27) .. "..."
        end
        
        love.graphics.setColor(1, 1, 1, metaBoxAlpha)
        love.graphics.print(displayName, rightPanelX + 60, yPos)
    end
end

function love.draw()
    -- Clear the screen with the background color based on the current theme
    love.graphics.clear(gameboyBackgroundColor)

    -- Header panel
    love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
    love.graphics.rectangle("fill", UI.margin, UI.margin, UI.leftPanelWidth, UI.headerHeight, UI.cornerRadius, UI.cornerRadius)
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
    love.graphics.rectangle("line", UI.margin, UI.margin, UI.leftPanelWidth, UI.headerHeight, UI.cornerRadius, UI.cornerRadius)
    love.graphics.setColor(highlightColor)
    love.graphics.setFont(font)
    love.graphics.print("ModPlayer by Cheese", UI.margin + UI.padding, UI.margin + 5)

    -- File browser panel
    local browserY = UI.margin + UI.headerHeight + UI.margin
    love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
    love.graphics.rectangle("fill", UI.margin, browserY, UI.leftPanelWidth, UI.browserHeight, UI.cornerRadius, UI.cornerRadius)
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
    love.graphics.rectangle("line", UI.margin, browserY, UI.leftPanelWidth, UI.browserHeight, UI.cornerRadius, UI.cornerRadius)

    -- Directory header
    love.graphics.setColor(highlightColor)
    love.graphics.print("CURRENT DIRECTORY", UI.margin + UI.padding, browserY + UI.padding)
    love.graphics.setFont(smallFont)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(currentDirectory, UI.margin + UI.padding, browserY + UI.padding + 25)

    -- File browser list
    local listStartY = browserY + 60
    local itemHeight = 25
    love.graphics.setScissor(UI.margin, listStartY, UI.leftPanelWidth - UI.padding, UI.browserHeight - 70)

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
        
        local yPos = listStartY + ((i - scrollOffset - 1) * itemHeight)
        
        -- Smooth selection highlight with animation
        if i == currentTrackIndex then
            local pulseAmount = (math.sin(colorCycleTimer * 3.14159 * 2) + 1) * 0.1 + 0.2
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], pulseAmount)
            love.graphics.rectangle("fill", UI.margin + 5, yPos - 2, UI.leftPanelWidth - 20, itemHeight, 5, 5)
        end
        
        -- Alternating row background for better readability
        if i % 2 == 0 then
            love.graphics.setColor(0.15, 0.15, 0.15, 0.3)
            love.graphics.rectangle("fill", UI.margin + 5, yPos - 2, UI.leftPanelWidth - 20, itemHeight, 5, 5)
        end
        
        -- Draw item text
        if isDirectory then
            love.graphics.setColor(dirColor[1], dirColor[2], dirColor[3], 0.9)
            love.graphics.print("> " .. item, UI.margin + 20, yPos)
        else
            love.graphics.setColor(textColor[1], textColor[2], textColor[3], 0.9)
            love.graphics.print("- " .. item, UI.margin + 20, yPos)
        end
    end

    love.graphics.setScissor()

    -- Right side panels
    local rightPanelX = UI.margin * 2 + UI.leftPanelWidth

    -- Metadata panel
    if modMetaData then
        love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
        love.graphics.rectangle("fill", rightPanelX, UI.rightStartY, UI.rightPanelWidth, UI.metadataHeight, UI.cornerRadius, UI.cornerRadius)
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
        love.graphics.rectangle("line", rightPanelX, UI.rightStartY, UI.rightPanelWidth, UI.metadataHeight, UI.cornerRadius, UI.cornerRadius)
        
        -- Metadata content
        love.graphics.setFont(font)
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], metaBoxAlpha)
        love.graphics.print("TRACK INFO", rightPanelX + 15, UI.rightStartY + 10)
        
        -- Metadata content with tighter spacing
        love.graphics.setFont(smallFont)
        love.graphics.setColor(1, 1, 1, metaBoxAlpha)
        local lineSpacing = 20  -- Reduced from 25
        local startY = UI.rightStartY + 35  -- Slightly reduced initial offset
        local metaText = {
            {"Song:", modMetaData.songName},
            {"Tracker:", modMetaData.tracker},
            {"Tempo:", tostring(modMetaData.tempo)},
            {"BPM:", tostring(modMetaData.bpm)},
            {"Instruments:", tostring(modMetaData.instrumentCount)},
            {"Patterns:", tostring(modMetaData.patternCount)},
            {"Channels:", tostring(modMetaData.channels)}
        }
        
        for i, item in ipairs(metaText) do
            love.graphics.setColor(0.8, 0.8, 0.8, metaBoxAlpha)
            love.graphics.print(item[1], rightPanelX + 20, startY + (i-1)*lineSpacing)
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], metaBoxAlpha)
            love.graphics.print(item[2], rightPanelX + 120, startY + (i-1)*lineSpacing)
        end
    end

    -- Instruments panel
    if modMetaData and type(modMetaData.instruments) == "table" then
        love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
        love.graphics.rectangle("fill", rightPanelX, UI.instrumentsStartY, UI.rightPanelWidth, UI.instrumentsHeight, UI.cornerRadius, UI.cornerRadius)
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
        love.graphics.rectangle("line", rightPanelX, UI.instrumentsStartY, UI.rightPanelWidth, UI.instrumentsHeight, UI.cornerRadius, UI.cornerRadius)
        
        -- Header
        love.graphics.setFont(font)
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], metaBoxAlpha)
        love.graphics.print("INSTRUMENTS", rightPanelX + 15, UI.instrumentsStartY + 10)
        
        -- Set up scrolling list parameters
        love.graphics.setFont(smallFont)
        local rowHeight = 20
        local visibleArea = UI.instrumentsHeight - 60
        local startY = UI.instrumentsStartY + 40
        
        -- Create a clipping region for the scrolling area
        love.graphics.setScissor(rightPanelX, startY, UI.rightPanelWidth, visibleArea)
        
        -- Calculate total height of all instruments
        local totalInstruments = #modMetaData.instruments
        local totalHeight = totalInstruments * rowHeight
        
        -- Only scroll if we have more instruments than can fit in the visible area
        if totalHeight > visibleArea and isPlaying then
            -- Update the scroll position with rubber band effect
            if instrumentScrollPause <= 0 then
                instrumentScrollOffset = instrumentScrollOffset + 
                    instrumentScrollDirection * instrumentScrollSpeed * love.timer.getDelta()
                
                -- Check if we need to change direction
                if instrumentScrollDirection > 0 and instrumentScrollOffset >= totalHeight - visibleArea then
                    instrumentScrollDirection = -1
                    instrumentScrollPause = 0.5  -- Pause briefly at the bottom
                elseif instrumentScrollDirection < 0 and instrumentScrollOffset <= 0 then
                    instrumentScrollDirection = 1
                    instrumentScrollPause = 0.5  -- Pause briefly at the top
                end
            else
                instrumentScrollPause = instrumentScrollPause - love.timer.getDelta()
            end
            
            -- Draw instruments with rubber band effect
            for i = 1, totalInstruments do
                -- Calculate instrument position with rubber band deformation
                local normalPosition = startY + (i - 1) * rowHeight - instrumentScrollOffset
                
                -- Apply rubber band deformation based on distance from center of visible area
                local distFromCenter = (normalPosition - (startY + visibleArea/2)) / visibleArea
                local rubberBandOffset = 0
                
                -- Add rubber band effect that increases toward the edges
                if math.abs(distFromCenter) > 0.2 then
                    rubberBandOffset = distFromCenter * instrumentRubberBandAmplitude * 
                        instrumentScrollDirection * 10
                end
                
                local yPos = normalPosition + rubberBandOffset
                
                -- Handle wrapping for continuous scrolling
                if yPos < startY - rowHeight then
                    yPos = yPos + totalHeight
                elseif yPos > startY + visibleArea then
                    yPos = yPos - totalHeight
                end
                
                -- Only draw if visible in the scrolling area
                if yPos >= startY - rowHeight and yPos <= startY + visibleArea then
                    drawInstrumentName(i, yPos, rightPanelX, metaBoxAlpha)
                end
            end
            
            -- Draw a duplicate set of instruments to create a seamless loop
            for i = 1, totalInstruments do
                local normalPosition = startY + (i - 1) * rowHeight - instrumentScrollOffset + totalHeight
                
                -- Apply rubber band deformation
                local distFromCenter = (normalPosition - (startY + visibleArea/2)) / visibleArea
                local rubberBandOffset = 0
                
                if math.abs(distFromCenter) > 0.2 then
                    rubberBandOffset = distFromCenter * instrumentRubberBandAmplitude * 
                        instrumentScrollDirection * 10
                end
                
                local yPos = normalPosition + rubberBandOffset
                
                -- Handle wrapping
                if yPos < startY - rowHeight then
                    yPos = yPos + totalHeight
                elseif yPos > startY + visibleArea + totalHeight then
                    yPos = yPos - totalHeight
                end
                
                -- Only draw if visible
                if yPos >= startY - rowHeight and yPos <= startY + visibleArea then
                    drawInstrumentName(i, yPos, rightPanelX, metaBoxAlpha)
                end
            end
        else
            -- If not scrolling, display instruments normally
            for i = 1, totalInstruments do
                if i <= 8 then  -- Limit to what can fit in the visible area
                    local yPos = startY + (i - 1) * rowHeight
                    
                    drawInstrumentName(i, yPos, rightPanelX, metaBoxAlpha)
                end
            end
            
            -- Show "more" indicator if there are more instruments than displayed
            if totalInstruments > 8 then
                love.graphics.setColor(0.7, 0.7, 0.7, metaBoxAlpha)
                love.graphics.print("+ " .. (totalInstruments - 8) .. " more", 
                                   rightPanelX + 30, startY + 8 * rowHeight)
            end
        end
        
        -- Clear the scissor/clipping region
        love.graphics.setScissor()
        
        -- Draw decorative scroll indicators with animation
        if totalHeight > visibleArea then
            local indicatorAlpha = (math.sin(love.timer.getTime() * 3) + 1) * 0.25 + 0.25
            love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], 
                                 indicatorAlpha * metaBoxAlpha)
            
            -- Change arrow based on scroll direction
            if instrumentScrollDirection > 0 then
                love.graphics.print("▲", rightPanelX + UI.rightPanelWidth - 30, startY + visibleArea - rowHeight)
                love.graphics.print("▼", rightPanelX + UI.rightPanelWidth - 30, startY)
            else
                love.graphics.print("▼", rightPanelX + UI.rightPanelWidth - 30, startY + visibleArea - rowHeight)
                love.graphics.print("▲", rightPanelX + UI.rightPanelWidth - 30, startY)
            end
        end
    end

    -- Shortcuts panel with expanded shortcuts
    love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
    love.graphics.rectangle("fill", UI.margin, UI.shortcutsY, UI.width - (UI.margin * 2), UI.shortcutsHeight, UI.cornerRadius, UI.cornerRadius)
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
    love.graphics.rectangle("line", UI.margin, UI.shortcutsY, UI.width - (UI.margin * 2), UI.shortcutsHeight, UI.cornerRadius, UI.cornerRadius)

    -- Draw shortcuts title
    love.graphics.setFont(smallFont)
    love.graphics.setColor(highlightColor)
    local shortcutsTitle = "SHORTCUTS:"
    local titleWidth = smallFont:getWidth(shortcutsTitle)
    love.graphics.print(shortcutsTitle, UI.margin + UI.padding, UI.shortcutsY + 8)

    -- Calculate shortcut positions based on available width
    local shortcutStartX = UI.margin + UI.padding + titleWidth + 40  -- Add extra padding after title
    local availableWidth = UI.width - (shortcutStartX + UI.margin * 3)
    local shortcuts = {
        "A: Play/Pause",
        "B: Stop",
        "R: Random",
        "T: Theme",
        "Select: Quit"
    }

    -- Calculate spacing between shortcuts
    local totalShortcuts = #shortcuts
    local spacing = availableWidth / (totalShortcuts)

    -- Draw shortcuts with even spacing
    for i, shortcut in ipairs(shortcuts) do
        love.graphics.setColor(1, 1, 1, 0.9)
        local x = shortcutStartX + (i-1) * spacing
        love.graphics.print(shortcut, x, UI.shortcutsY + 8)
    end

    -- Now Playing panel
    love.graphics.setColor(0.1, 0.1, 0.1, UI.panelOpacity)
    love.graphics.rectangle("fill", UI.margin, UI.nowPlayingY, UI.width - (UI.margin * 2), UI.nowPlayingHeight, UI.cornerRadius, UI.cornerRadius)
    love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
    love.graphics.rectangle("line", UI.margin, UI.nowPlayingY, UI.width - (UI.margin * 2), UI.nowPlayingHeight, UI.cornerRadius, UI.cornerRadius)

    -- Now Playing text with pulsing effect
    local pulseAmount = (math.sin(colorCycleTimer * 3.14159 * 2) + 1) * 0.2 + 0.8
    if isPlaying then
        love.graphics.setColor(highlightColor[1] * pulseAmount, highlightColor[2] * pulseAmount, highlightColor[3] * pulseAmount)
    else
        love.graphics.setColor(highlightColor[1] * 0.7, highlightColor[2] * 0.7, highlightColor[3] * 0.7)
    end

    local playingText = isPlaying and "Now Playing: " or "Paused: "
    love.graphics.print(playingText .. (songTitle or "None"), UI.margin + UI.padding, UI.nowPlayingY + 8)

    -- Time display
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(formatTime(songTime) .. " / " .. formatTime(songDuration), UI.width - 120, UI.nowPlayingY + 8)

    -- Progress bar
    if currentSong and songDuration > 0 then
        local progress = songTime / songDuration
        local barY = UI.height - UI.margin - UI.progressBarHeight + UI.progressBarOffset
        
        -- Background with theme-based color
        love.graphics.setColor(progressColor[1], progressColor[2], progressColor[3], 0.3)
        love.graphics.rectangle("fill", UI.margin, barY, UI.width - (UI.margin * 2), UI.progressBarHeight, 5, 5)
        
        -- Progress with highlight color
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], playBarAlpha)
        love.graphics.rectangle("fill", UI.margin, barY, progress * (UI.width - (UI.margin * 2)), UI.progressBarHeight, 5, 5)
        
        -- Waveform effect using text color for better theme integration
        love.graphics.setColor(textColor[1], textColor[2], textColor[3], 0.7 * playBarAlpha)
        local waveCount = 40
        for i = 1, waveCount do
            local waveX = UI.margin + (i / waveCount) * progress * (UI.width - (UI.margin * 2))
            if waveX <= UI.margin + progress * (UI.width - (UI.margin * 2)) then
                local waveY = barY + (UI.progressBarHeight / 2)
                local amplitude = math.sin(i * 0.5 + colorCycleTimer * 10) * (UI.progressBarHeight / 2)
                love.graphics.line(waveX, waveY - amplitude, waveX, waveY + amplitude)
            end
        end
        
        -- Position marker using highlight color
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], playBarAlpha)
        love.graphics.circle("fill", UI.margin + progress * (UI.width - (UI.margin * 2)), barY + UI.progressBarHeight/2, 5)
        
        -- Add subtle border to match other UI elements
        love.graphics.setColor(highlightColor[1], highlightColor[2], highlightColor[3], UI.borderOpacity)
        love.graphics.rectangle("line", UI.margin, barY, UI.width - (UI.margin * 2), UI.progressBarHeight, 5, 5)
    end
end