# Test Setup

This document describes how to configure the unit test target in Xcode and how tests are run in GitHub Actions CI.

## Prerequisites

- Xcode 16.4 or later
- The project opens cleanly and builds without errors (`Cmd+B`)

---

## 1. Create the Unit Test Target in Xcode (one-time setup)

### 1.1 Add the target

1. Open `UltraKiosk.xcodeproj` in Xcode.
2. **File → New → Target**
3. Select **Unit Testing Bundle** → **Next**
4. Fill in the fields:
   - **Product Name:** `UltraKioskTests`
   - **Team:** same as the main app target
   - **Host Application:** `UltraKiosk`
   - **Language:** Swift
5. Click **Finish**.

### 1.2 Remove the generated placeholder

Xcode auto-generates an empty `UltraKioskTests.swift`. Delete it:

1. Select `UltraKioskTests.swift` in the Project Navigator.
2. Press **Delete** → **Move to Trash**.

### 1.3 Add the existing test files to the target

The test sources already exist in the `UltraKioskTests/` folder on disk. Each file must be added to the new target:

1. Select each file below in the Project Navigator.
2. Open the **File Inspector** (right panel, ⌥+⌘+1).
3. Under **Target Membership**, check `UltraKioskTests`.

Files to add:

| File | What it tests |
|------|---------------|
| `TestHelpers.swift` | Shared mocks and `UserDefaults` helpers |
| `SettingsManagerTests.swift` | `SettingsManager` — defaults, persistence, migration, export/import |
| `KioskManagerTests.swift` | `KioskManager` — screensaver state, inactivity timer, brightness calls |
| `SlideshowManagerTests.swift` | `SlideshowManager` — timer, index advance, screensaver pause/resume |
| `AudioManagerTests.swift` | `AudioManager.convertFloatToInt16`, `sendHomeAssistantConversation`, `APIError` |
| `MQTTManagerTests.swift` | `MQTTManager.batteryStateToString`, `formatNumberPayload`, `computeDeviceSerializedId` |

### 1.4 Enable the test target in the scheme

1. **Product → Scheme → Edit Scheme…** (`Cmd+<`)
2. Select **Test** in the left sidebar.
3. Click **+** and add `UltraKioskTests`.
4. Optional but recommended: select **Options → Gather Coverage Data** to get code coverage reports.
5. Click **Close**.

### 1.5 Run the tests locally

Press **`Cmd+U`** — all tests should pass.  
The Test Navigator (**`Cmd+6`**) shows individual results with green/red indicators.

---

## 2. Test Architecture

### Isolation strategy

Each test class uses an isolated `UserDefaults` suite so tests never affect each other or the app's real settings:

```swift
private static let suiteName = "test.ultrakiosk.settings"

override func setUp() {
    testDefaults = .testSuite(name: Self.suiteName)
    sut = SettingsManager(userDefaults: testDefaults)
}

override func tearDown() {
    testDefaults.removeSuite(name: Self.suiteName)
}
```

### Testability refactorings

The following production-code changes were made specifically to enable testing without hardware dependencies:

| Class | Change |
|-------|--------|
| `SettingsManager` | `init(userDefaults:)` accepts a custom `UserDefaults` suite |
| `BrightnessManager` | `BrightnessControlling` protocol extracted; `MockBrightnessManager` used in tests |
| `KioskManager` | `init(brightnessManager:)` accepts any `BrightnessControlling` |
| `AudioManager` | `convertFloatToInt16(floatSamples:)` made internal; `sendHomeAssistantConversation` accepts a `URLDataLoader` closure |
| `MQTTManager` | `batteryStateToString` and `formatNumberPayload` made `static` |

### Async tests

Timer-based and Combine-based tests use `XCTestExpectation` with `wait(for:timeout:)`.  
Combine's `receive(on: RunLoop.main)` dispatches are drained synchronously via:

```swift
RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
```

---

## 3. GitHub Actions CI

The workflow is defined in `.github/workflows/build.yaml`.  
It runs automatically on every push to `main` and on every pull request targeting `main`.

### What the workflow does

1. Checks out the repository.
2. Selects Xcode 16.4.
3. Restores cached SPM package checkouts (CocoaMQTT, Porcupine, Starscream).
4. Runs `xcodebuild clean test` on an **iPad (A16) / iOS 18.6** simulator.
5. Uploads the `.xcresult` bundle as a downloadable artifact.

### Viewing CI results

After a workflow run on GitHub:

1. Open the run page → **Artifacts** → download `test-results-<run_number>`.
2. Unzip and double-click `TestResults.xcresult` — Xcode opens it with full test logs, failure details, and coverage data.

### Adding tests to CI after creating the target

Once the Xcode target is set up locally (Section 1) and committed, CI picks up the tests automatically — no further workflow changes are needed.

If the test target does not exist in the committed `.xcodeproj`, CI will still succeed (the `test` action finds no test targets and skips gracefully) but no tests will run.

---

## 4. Troubleshooting

### "No such module 'XCTest'" in SourceKit

Expected until the test target exists in the `.xcodeproj`. SourceKit cannot index test files without a compiled target. Disappears after completing Section 1.

### Tests are not discovered by Xcode

Check that the files are listed under the `UltraKioskTests` target in the project file (`project.pbxproj`). Re-add them via File Inspector → Target Membership if missing.

### CI fails with "xcodebuild: error: The test action requires that the scheme … has at least one test target"

The test target has not been added to the scheme's Test action. Complete step 1.4 and push the updated `.xcodeproj`.

### Timer-based tests flake on slow machines

Increase the `timeout:` parameter in `wait(for:timeout:)` calls. Tests currently use 1–3 second timeouts for 0.1 second timers, which provides a 10–30× safety margin.

---

## 5. Dependabot — Automated Dependency Updates

### How it works

Dependabot's Swift support requires a `Package.swift` manifest. Because this project manages SPM dependencies entirely through Xcode (no standalone `Package.swift`), a minimal manifest exists at the repository root **for Dependabot only**. Xcode ignores it when opening `UltraKiosk.xcodeproj`.

Dependabot is configured in `.github/dependabot.yml` and tracks:

| Ecosystem | Packages |
|-----------|----------|
| `swift` | CocoaMQTT, Porcupine, Starscream |
| `github-actions` | `actions/checkout`, `actions/cache`, `actions/upload-artifact` |

PRs are opened every Monday. Each PR updates the version constraint in `Package.swift` and the root-level `Package.resolved`.

### Applying a Dependabot PR

Dependabot updates `Package.swift` only. The Xcode project still pins its own copy of the dependencies. After merging a Dependabot PR, apply the version bump in Xcode:

1. Open `UltraKiosk.xcodeproj`.
2. **File → Packages → Update to Latest Package Versions**  
   Xcode resolves all packages and updates `UltraKiosk.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.
3. Build (`Cmd+B`) and run tests (`Cmd+U`) to verify nothing broke.
4. Commit the updated `.xcodeproj`.

### Special considerations for Porcupine

Major version bumps of Porcupine (e.g. 3.x → 4.x) usually include API changes and may require a new access key from the [Picovoice Console](https://console.picovoice.ai/). Review the release notes before merging a Porcupine major-version PR.
