# UltraKiosk

[![Build](https://github.com/mirkosertic/UltraKiosk/actions/workflows/build.yaml/badge.svg)](https://github.com/mirkosertic/UltraKiosk/actions/workflows/build.yaml)

UltraKiosk is a lightweight iOS app that displays Home Assistant in full‑screen kiosk mode. It can also act as a voice satellite. A common use case is a wall‑mounted iPad as a smart display.

## Features
- Full‑screen kiosk-mode display of Home Assistant dashboards (works best with HACS "Kioskmode")
- **Slideshow mode**: cycle through multiple dashboards with smooth cross-fade transitions at a configurable interval
- Screensaver after inactivity
- Wake the display via face detection using the device camera
- Wake-word detection via [Picovoice Porcupine](https://picovoice.ai/platform/porcupine/)
- Voice satellite for the Home Assistant Voice Pipeline

## Screenshots

*Start screen / Kiosk WebView*
![Start screen / Kiosk WebView](docs/welcome.png)

*Settings*
![Settings](docs/settings.png)

*Screensaver*
![Screensaver](docs/screensaver.png)


## Installation
- Open the project in Xcode (`UltraKiosk.xcodeproj`).
- Select a target device (iPad/iPhone).
- Build and install the app on the device.

Requirements:
- Xcode (latest version)
- iOS device with camera and network access
- A reachable Home Assistant instance (local or remote)

## Quick Start
1. Install and launch the app.
2. Open Settings (triple-tap the top-right corner) and add one or more URLs under **Kiosk mode → Manage URLs**.
3. The dashboard loads in full screen; a screensaver starts after inactivity.
4. The display wakes via local face detection.

Example URL:
```
http://homeassistant.local:8123/anzeige-flur/0?kiosk=true
```

## Configuration
Configuration data is available by tapping three times in the top right corner of the screen. You should also see a small semi-transparent circle there. A configuration dialog will appear, offering the following configuration sections:

### Home Assistant
- IP/Name
- Port
- Use HTTPS
- Access Token

### MQTT Integration
- Enable MQTT
- Broker IP/Name
- Port
- Use TLS/SSL
- Username (optional)
- Password (optional)
- Topic Prefix
- Battery Update Interval

### ScreenSaver
- Inactivity timeout
- Screen brightness (dimmed)
- Screen brightness (normal)
- Face detection interval

### Voice Control
- Enable voice activation
- Sample rate
- Timeout
- Porcupine Access Token (from [Picovoice Console](https://console.picovoice.ai/))

### Kiosk mode / Slideshow
- **Manage URLs**: add, remove, and reorder up to 5 dashboard URLs
  - One URL: single-page mode (no timer)
  - Two or more URLs: slideshow mode with automatic cross-fade transitions
  - No URLs: built-in demo page is shown
- **Transition interval**: time each slide is displayed before cross-fading to the next (5 s – 5 min, default 30 s)

All configured WebViews remain loaded in the background — sessions stay alive and assets are not reloaded on every transition. Because all slides share a single cookie store and process pool, a single Home Assistant login is valid across all dashboards.

## Privacy & Permissions
- **Camera**: Used for face detection to wake the display.
- **Microphone**: Used for the voice satellite feature (always‑listening when enabled).
- No biometric data is stored. Face detection is used locally only to activate the display.

## Contributing
Contributions are welcome! Please:
- Open an issue for bugs or feature requests.
- Submit pull requests with clear descriptions and small, reviewable changes.

## License
MIT License. See `LICENSE` for details.
 