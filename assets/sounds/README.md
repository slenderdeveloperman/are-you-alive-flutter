# Sound Assets

## Required: eerie_beep.mp3

This folder needs an `eerie_beep.mp3` file for the splash screen animation.

### Specifications
- **Duration:** ~200ms (short beep)
- **Style:** Slightly distorted, filtered, eerie tone
- **Format:** MP3 (for cross-platform compatibility)

### Suggested Sources (Royalty-Free)
1. **freesound.org** - Search for "glitch beep" or "distorted alert"
2. **pixabay.com/sound-effects** - Search for "eerie beep"
3. **zapsplat.com** - Search for "glitch tone"

### How to Add
1. Download a suitable sound effect
2. Rename it to `eerie_beep.mp3`
3. Place it in this folder (`assets/sounds/`)
4. Run `flutter pub get` to refresh assets

The app will work without this file (audio gracefully degrades), but the splash screen animation is designed to have synchronized beeps for the full eerie effect.
