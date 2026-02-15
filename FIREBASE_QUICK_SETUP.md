# Quick Firebase Setup

Your app is configured to use Firebase, but you need to generate the configuration files first.

## Quick Fix (2 minutes)

Run this command in your terminal from the project root:

```bash
flutterfire configure
```

This will:
1. Ask you to log in to Firebase (if not already logged in)
2. Show you a list of your Firebase projects
3. Let you select which project to use
4. Ask which platforms to configure (select iOS)
5. Automatically generate `lib/firebase_options.dart`
6. Download and place `GoogleService-Info.plist` in your iOS project

After running this command, your app should work!

## If you don't have a Firebase project yet:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Follow the setup wizard
4. Then run `flutterfire configure`

## After running flutterfire configure:

The code in `lib/main.dart` is already set up correctly. Just run:

```bash
flutter run
```

And your app should launch successfully!
