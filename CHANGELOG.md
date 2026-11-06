# Changelog

## 2.2.2
- Android: the back arrow closes the scanner again. Apps targeting Android 15+ draw the screen under the status bar, and the arrow sat inside it, where the status bar takes every tap. It now stays below the status bar and has a 48dp touch target. Closing returns `null` from `CardScanner.scanCard`, as the system back does.

## 2.2.1
- iOS: the close button is back. Its image had stopped being bundled (1.0.2), so it was invisible, and it sat under the Dynamic Island. The close and flash buttons now use SF Symbols inside the safe area.
- iOS: closing the scanner (close button or `cardScannerTimeOut`) now returns `null` from `CardScanner.scanCard`, as on Android. Before, the call never returned.
- iOS: the camera keeps the card in focus. It focused once, before the camera had started, and then stayed locked. It now uses continuous autofocus on the card frame, tap to focus, and, on iPhones whose main lens can't focus that close (Pro models), the multi-lens camera that switches to the ultra-wide for close-ups like the Camera app.
- iOS: the scanner opens from the top-most view controller, the timeout closes only the scanner, and results reach Flutter on the main thread.

## 2.2.0
- iOS: read card text with Apple's Vision framework instead of Google ML Kit. ML Kit has no arm64 simulator build, so apps using this plugin could not run on Apple Silicon simulators (Xcode 27 removed the Rosetta ones).

## 2.1.1
- iOS: fix a crash when the scanner screen is tapped before the camera is ready, or after camera access was denied (nil capture device in `refocus()` / `stopScanning()`).

## 1.0.5
- Updated for Flutter 3

## 1.0.4
- Fixing problems to run your app in iOS

## 1.0.3
- Fixing iOS Bugs

## 1.0.2
- Formating files.

## 1.0.1
- Fixing problems to run your app

#### 1.0.1-prerelease
- ios bug fix

## 1.0.0-prerelease
+ migrating to null safety

## 0.2.1
+ Adds many options to control scanning behavior
+ improved card holder name scanning and expiry date scanning accuracy
+ refactored major part of code
+ added example app and parameter customization ui to fully customize any parameter during run time and find the best options that suit your needs
+ added back button to the scanner screen


## 0.1.0
+ Added IOS support 🥳
+ Still Better accuracy and speed of scanning ✅
+ refactored example app 📖


### 0.0.4
* Much Better accuracy in card holder name and expiry date scanning ✅
+ Improved speed of scanning 🏎


## 0.0.1
* First Release
