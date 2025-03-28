# ModPlayer by Cheese 🎵

ModPlayer is your gateway to experiencing classic tracker music formats on retro handheld devices. Supporting a variety of file types, including `.mod`, `.xm`, `.s3m`, `.it`, and more, it offers portability and simplicity for tracker music enthusiasts.

---

## 🛠️ Installation Instructions

### For MuOS
1. Create a ModPlayer directory in the **Applications** folder.
2. Copy all files from this repository into the new directory.
3. Open the **Apps** section in MuOS and locate ModPlayer.
4. Add your `.mod` files to the `content` folder.
5. You're ready to play your music!

### For Other Systems
1. Install [LÖVE 2D](https://love2d.org/), the lightweight game framework powering ModPlayer.
2. Place the ModPlayer files in your chosen directory.
3. Run the application using `love .` within the ModPlayer folder.

---

## 📝 Still To Do
- Test compatibility for all supported mod formats.
- Improve on-screen shortcut labels (current button functionality works but can be more intuitive in the next update).
- Enhance header extraction across all formats (currently complete for `.mod`) to display instruments in the interface.

---

## 🚀 Features

- **Wide Format Support**: Play popular tracker formats including `.mod`, `.xm`, `.s3m`, `.it`, `.mtm`, `.amf`, `.dbm`, `.dsm`, `.okt`, `.psm`, and `.ult`.
- **Metadata Display**: View song details such as instruments, samples, patterns, and tracker information.
- **Dynamic Themes**: Customize the interface with themes like Light, Dark, Red, Blue, and Green.
- **Keyboard Shortcuts**:
  - `A` - Play
  - `B` - Pause
  - `R` - Randomize tracks
  - `T` - Change themes
  - `Backspace` - Navigate to the previous directory
  - `Select` - Quit the application

---

## 🔧 Interface Highlights

ModPlayer features a simple interface with organized file browsing, real-time progress bars for playback, and detailed metadata. It’s designed to make exploring and playing tracker music straightforward and enjoyable.

---

## ⚡ Troubleshooting Tips

1. **Screen Goes Black?**  
   Verify that themes are properly initialized and that files exist in the correct directory.

2. **UTF-8 Decoding Errors?**  
   Ensure filenames and metadata are UTF-8 compatible. Invalid characters are sanitized during processing.

3. **Missing Features?**  
   Feel free to submit feedback or suggestions for features you’d like to see in future versions. ModPlayer is open to improvement!

---

## 🎵 About ModPlayer

Inspired by the legacy of tracker music, ModPlayer combines portability and simplicity to bring classic formats into modern devices. Whether revisiting old modules or discovering retro chiptune music, ModPlayer is designed for you.

---

Enjoy exploring tracker music with ModPlayer! Feedback and ideas are always welcome.
