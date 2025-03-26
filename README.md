# ModPlayer by Cheese

ModPlayer is a lightweight music player designed for .mod and .it files, featuring an interactive interface with theme support, directory navigation, and more. It’s your go-to tool for exploring and listening to retro module music in style.

## Key Features
- **Music Playback:** Seamlessly plays .mod and .it files.
- **Metadata Display:** Shows song metadata such as song name, author, and sample count.
- **Directory Navigation:** Navigate through directories to browse your music files.
- **Theme Support:** Switch between multiple themes (including a nostalgic Gameboy-inspired theme).
- **Playlists:** Cycle through tracks or play a random song.
- **Interactive UI:** Move through files and directories with easy-to-use keyboard controls.

## File Support
ModPlayer currently supports the following file formats:
- .mod
- .xm
- .s3m
- .it
- .mtm
- .amf
- .dbm
- .dsm
- .okt
- .psm
- .ult

The player automatically detects supported files and plays them. Files not in this list are ignored.

## Themes
You can cycle through various color themes to fit your mood or environment. Current themes include:
- **Dark Theme:** A classic dark theme for that "late-night coding" aesthetic.
- **Light Theme:** An improved light theme with some tweaks for better contrast.
- **Blue Theme:** Because who doesn't like blue?
- **Green Theme:** For those who appreciate the color of nature and retro vibes.
- **Red Theme:** Bold and fiery, just like your music taste.

## Controls
- **Space / A:** Toggle play/pause.
- **B:** Stop the current track.
- **Up/Down Arrow:** Navigate through the track list.
- **Return:** Enter a directory or play a file.
- **Backspace:** Navigate back to the previous directory.
- **T:** Cycle through themes.
- **R:** Randomize and play a random track.
- **X / Select:** Quit the application.

## Technical Details
- **Written in:** Lua (using LÖVE framework).
- **Font:** Retro-inspired typeface for that nostalgic touch.
- **Audio Processing:** Supports playing of .mod and .it files, including metadata parsing.

## How It Works
- **Loading Files:** ModPlayer loads files from the content directory and displays supported .mod and .it files.
- **Track Navigation:** You can navigate through directories and select a track to play.
- **Playing Music:** Once a track is selected, the player reads its metadata and starts playing. If it’s a .mod or .it file, the song title and author (if available) will be displayed.

## Metadata Parsing
ModPlayer reads key metadata from supported file formats:
- **For .mod files:** Song name, author, sample count, pattern count, and tracker type (e.g., ProTracker, 6-Channel MOD).
- **For .it files:** Song name, sample count, instrument count, and pattern count.

If metadata is missing or corrupted, the player will gracefully fall back to default values, ensuring you can still enjoy your music.

## Contributing
While ModPlayer is simple, it’s designed to be extensible. Feel free to fork and submit improvements or bug fixes!

## License
ModPlayer is open-source and licensed under the MIT License. Feel free to use it, modify it, and share it.
