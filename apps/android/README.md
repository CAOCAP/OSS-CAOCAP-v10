# CAOCAP for Android

Kotlin + Jetpack Compose Hello World shell. Explore, Build, Collaborate, sign-in, and agent chat are not implemented.

This client is the planned phone counterpart to iOS. Product development still starts with iOS and macOS.

## Setup

1. Install [Android Studio](https://developer.android.com/studio) with the Android SDK (API 36) and a JDK 17.
2. Open [caocap/](caocap/) as a Gradle project.
3. Let Android Studio sync packages, then select the `app` run configuration and an API 26 or later emulator or device.
4. Run with the **Run** button.

From the repository root:

```sh
./apps/android/caocap/gradlew -p apps/android/caocap :app:assembleDebug
```

Do not commit `local.properties`. Point Gradle at your SDK with `ANDROID_HOME` or Android Studio’s local SDK path.

## What you should see

A single activity titled **CAOCAP** that shows **Hello, world!**

## What is not implemented

Explore, Build, Collaborate, Firebase, device presence, and CoCaptain are not present. This is a launchable shell, not the platform.
