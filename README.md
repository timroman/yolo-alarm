# yolo alarm

**Wake up ready to live.**

yolo alarm wakes you gently when your body is ready. Set a wake window, and the app listens for the subtle sounds of you naturally stirring to wake you at the perfect moment.

## Features

- **Wake Window** - Set your earliest and latest wake times
- **Smart Detection** - Adjustable sensitivity detects subtle movements or only louder sounds
- **Gentle Alarm** - Volume builds gradually over 60 seconds
- **Multiple Sounds** - Gentle chimes, soft bells, ocean waves, or import your own
- **Haptic Patterns** - Heartbeat, pulse, escalating, or steady vibrations
- **Color Themes** - Ocean, Sunset, Forest, Lavender, Midnight, Coral
- **Live Activity** - See your alarm status on your lock screen
- **Private by Design** - All processing on-device, nothing recorded or sent anywhere

## How It Works

1. Set your wake window (e.g., 6:30 - 7:00 AM)
2. Tap Start and sleep
3. When yolo detects you stirring, it gently wakes you
4. Start your day feeling ready

## Requirements

- iOS 17.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Building

```bash
# Install XcodeGen if needed
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open yolo-alarm.xcodeproj
```

## Privacy

yolo alarm uses your microphone solely to detect movement sounds during your wake window. Audio is processed on your device in real-time. Nothing is ever recorded, stored, or sent anywhere.

## Links

- [Website](https://timroman.github.io/yolo-alarm/)
- [Privacy Policy](https://timroman.github.io/yolo-alarm/privacy.html)
- [App Store](https://apps.apple.com/app/yolo-alarm)

## License

Copyright 2025. All rights reserved.
