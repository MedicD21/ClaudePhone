# ClaudePhone

A native iOS app that gives Claude direct access to 55+ iOS framework capabilities through tool calling. Chat with Claude and let it interact with your calendar, health data, contacts, smart home, location, photos, and much more.

## Architecture

- **SwiftUI** with MVVM pattern
- **Streaming** Claude API with Server-Sent Events
- **Recursive tool calling** up to 10 rounds per message
- **iOS 17+** deployment target
- **Dark theme** with glassmorphism design system

## Features

### Chat
- Real-time streaming responses with typing indicators
- Multi-conversation management with history
- Tool call badges shown inline on messages
- Suggestion chips for quick prompts

### Tool Integrations

| Framework | Tools | What Claude Can Do |
|-----------|-------|--------------------|
| EventKit | 4 | Create, list, search, delete calendar events |
| Reminders | 3 | Create, list, complete reminders |
| Contacts | 3 | Search, create, view full contact details |
| Location | 4 | Get GPS location, search nearby places, get directions, reverse geocode |
| Notifications | 3 | Schedule, list, remove local notifications |
| HealthKit | 5 | Read steps, heart rate, workouts, sleep; log water intake |
| Photos | 3 | Browse recent photos, search by date/favorites, get metadata |
| UIKit/Device | 5 | Device info, battery status, brightness control, haptics, screen info |
| Media | 3 | Now playing info, play/pause, skip tracks |
| Motion | 2 | Accelerometer/gyroscope data, pedometer (steps/distance/floors) |
| Network | 2 | Connectivity status, WiFi info |
| NaturalLanguage | 4 | Sentiment analysis, language detection, tokenization, entity extraction |
| Speech | 1 | Text-to-speech with configurable voice, rate, pitch |
| Bluetooth | 1 | Scan for nearby BLE devices |
| HomeKit | 2 | List accessories, control smart home devices |
| Vision | 3 | OCR text recognition, image classification, face detection |
| NFC | 1 | Read NDEF tags |
| StoreKit | 1 | Look up in-app purchase product info |
| WebKit | 1 | Fetch and extract text from web pages |
| CloudKit | 2 | Save and fetch iCloud records |
| CoreImage | 2 | Apply photo filters (sepia, noir, blur, etc.), generate QR codes |

### Settings
- Secure API key storage via iOS Keychain
- Framework status dashboard with tool counts per category
- Conversation management

## Project Structure

```
ClaudePhone/
├── App/                    # App entry point, ContentView, AppState
├── Models/                 # ChatModels, ToolDefinition protocol
├── Services/               # ChatViewModel, ClaudeAPIService, ToolRegistry
├── Theme/                  # AppTheme design system
├── Utilities/              # KeychainManager
├── Views/
│   ├── Chat/               # ChatView, message bubbles, input bar
│   ├── Settings/           # SettingsView
│   └── ToolsBrowserView    # Tool discovery with search
└── Tools/
    ├── EventKit/           # CalendarTools, ReminderTools
    ├── Contacts/           # ContactsTools
    ├── Location/           # LocationTools
    ├── Notifications/      # NotificationTools
    ├── HealthKit/          # HealthKitTools
    ├── Photos/             # PhotosTools
    ├── UIKitTools/         # DeviceTools
    ├── Media/              # MediaTools
    ├── Motion/             # MotionTools
    ├── Network/            # NetworkTools
    ├── NaturalLanguage/    # NaturalLanguageTools
    ├── Speech/             # SpeechTools
    ├── Bluetooth/          # BluetoothTools
    ├── HomeKit/            # HomeKitTools
    ├── Vision/             # VisionTools
    ├── NFC/                # NFCTools
    ├── StoreKit/           # StoreKitTools
    ├── WebKit/             # WebKitTools
    ├── CloudKit/           # CloudKitTools
    └── CoreImage/          # CoreImageTools
```

## Setup

1. Open `ClaudePhone.xcodeproj` in Xcode 15+
2. Set your development team in Signing & Capabilities
3. Build and run on a device or simulator
4. Enter your Anthropic API key on the onboarding screen
5. Start chatting — Claude will use tools automatically when relevant

## Requirements

- Xcode 15+
- iOS 17.0+
- Anthropic API key
- Physical device recommended (many tools require real hardware sensors)

## Privacy

All framework permissions are declared in `Info.plist` with usage descriptions. The app requests access only when a tool needs it — nothing is accessed proactively.
