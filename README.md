# TideNotes 🌊📝

TideNotes is a native, offline-first notes app for iPhone built with SwiftUI, SwiftData, PhotosUI, PencilKit and LocalAuthentication.

## v0.1

- Create, edit and delete notes
- Automatic local saving
- Search titles, note text and tags
- Pin important notes
- Custom folders with rename and delete
- Recently Deleted with recovery and permanent deletion
- Checklists and quick text formatting snippets
- Photo attachments
- PencilKit drawings
- Tags
- Move notes between folders
- Lock individual notes with Face ID, Touch ID or device passcode
- Share/export note text
- Word count
- Native light and dark mode
- Fully usable without an account or network connection

## Build

The Xcode project is generated with XcodeGen.

```bash
brew install xcodegen
python3 ios-ci/generate_app_icon.py
xcodegen generate
open TideNotes.xcodeproj
```

GitHub Actions also compiles every push to `main` for an iOS Simulator target.

## TestFlight

The manual **TideNotes to TestFlight** workflow uses Fastlane and expects these repository secrets:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT` (raw or base64 App Store Connect `.p8` contents)
- `APPLE_TEAM_ID`

Bundle ID: `com.jdarkyeka6.TideNotes`

The workflow can register the bundle ID if needed, but the App Store Connect app record must exist before upload.
