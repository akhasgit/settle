# Firebase Setup Guide

This guide will walk you through setting up Firebase Authentication for your Settle app.

## Prerequisites

- A Google account
- Flutter SDK installed
- Android Studio or Xcode (depending on your target platform)

## Step 1: Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click **"Add project"** or select an existing project
3. Enter your project name (e.g., "Settle")
4. Follow the setup wizard:
   - Disable Google Analytics (optional, you can enable it later if needed)
   - Click **"Create project"**
5. Wait for the project to be created, then click **"Continue"**

## Step 2: Add Android App to Firebase

1. In the Firebase Console, click the **Android icon** (or click **"Add app"** and select Android)
2. Fill in the Android app details:
   - **Android package name**: `com.example.settle`
     - You can find this in `android/app/build.gradle.kts` under `applicationId`
   - **App nickname** (optional): Settle Android
   - **Debug signing certificate SHA-1** (optional for now, needed for some features)
3. Click **"Register app"**
4. Download the `google-services.json` file
5. Place the `google-services.json` file in: `android/app/`
   ```
   android/app/google-services.json
   ```

## Step 3: Add iOS App to Firebase (if targeting iOS)

1. In the Firebase Console, click **"Add app"** and select iOS
2. Fill in the iOS app details:
   - **iOS bundle ID**: Check `ios/Runner.xcodeproj` or `ios/Runner/Info.plist` for the bundle identifier
   - **App nickname** (optional): Settle iOS
3. Click **"Register app"**
4. Download the `GoogleService-Info.plist` file
5. Open Xcode and add the file to your iOS project:
   - Drag `GoogleService-Info.plist` into `ios/Runner/` in Xcode
   - Make sure "Copy items if needed" is checked
   - Add it to the Runner target

## Step 4: Enable Email/Password Authentication

1. In Firebase Console, go to **Authentication** (left sidebar)
2. Click **"Get started"** (if first time)
3. Click on the **"Sign-in method"** tab
4. Click on **"Email/Password"**
5. Enable the first toggle (Email/Password)
6. Click **"Save"**

## Step 5: Install FlutterFire CLI (Recommended)

The FlutterFire CLI can help automate some of the setup:

```bash
dart pub global activate flutterfire_cli
```

Then run:

```bash
flutterfire configure
```

This will:
- Detect your Firebase projects
- Let you select which platforms to configure
- Automatically download and place configuration files
- Update your Flutter code if needed

**OR** manually complete the steps above.

## Step 6: Verify Setup

1. Make sure `google-services.json` is in `android/app/`
2. Make sure `GoogleService-Info.plist` is in `ios/Runner/` (if targeting iOS)
3. Run `flutter pub get` (already done)
4. Run `flutter clean`
5. Run `flutter run`

## Step 7: Test Authentication

1. Launch the app
2. You should see the login screen
3. Click "Sign Up" to create a new account
4. Enter an email and password (minimum 6 characters)
5. After signing up, you should be automatically logged in and see the main screen
6. Close and reopen the app - you should remain logged in (persistent session)

## Troubleshooting

### Android Issues

- **Build error about google-services**: Make sure `google-services.json` is in `android/app/`
- **Plugin not found**: Run `flutter clean` and `flutter pub get`
- **Gradle sync failed**: Check that the Google Services plugin is in `android/settings.gradle.kts`

### iOS Issues

- **Missing GoogleService-Info.plist**: Make sure it's added to the Xcode project and included in the Runner target
- **Build errors**: Run `pod install` in the `ios/` directory:
  ```bash
  cd ios
  pod install
  cd ..
  ```

### General Issues

- **Firebase not initialized**: Make sure `Firebase.initializeApp()` is called in `main()` before `runApp()`
- **Authentication not working**: Verify Email/Password is enabled in Firebase Console
- **User not staying logged in**: This should work automatically. If not, check that `authStateChanges` stream is properly set up

## Next Steps

- Add password reset functionality
- Add email verification
- Add social login (Google, Apple, etc.)
- Add user profile management
- Secure your Firebase rules in Firestore/Realtime Database if you plan to use them

## Important Notes

- **Keep your configuration files secure**: Don't commit `google-services.json` or `GoogleService-Info.plist` to public repositories if they contain sensitive data
- **SHA-1 Certificate**: For production, you'll need to add your release signing certificate SHA-1 to Firebase Console
- **Firebase Rules**: Set up proper security rules for any Firebase services you use

## Support

If you encounter issues:
1. Check the [Firebase Flutter documentation](https://firebase.flutter.dev/)
2. Check the [Firebase Console](https://console.firebase.google.com/) for error messages
3. Review Flutter and Firebase logs when running the app
