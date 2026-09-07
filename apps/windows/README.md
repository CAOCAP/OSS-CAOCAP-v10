# CAOCAP for Windows

C# WinUI 3 Hello World shell. Explore, Build, Collaborate, the floating Agent, and computer use are not implemented.

This client is the planned desktop counterpart to macOS. Product development still starts with iOS and macOS.

## Setup

1. On Windows, install [Visual Studio 2022](https://visualstudio.microsoft.com/) with the **WinUI application development** workload (Windows App SDK).
2. Install the .NET 8 SDK if the workload does not include it.
3. Open [caocap/caocap.sln](caocap/caocap.sln).
4. Select the `caocap` project, an **x64** (or ARM64) configuration, and run with **F5**.

From a Developer Command Prompt in this folder:

```bat
dotnet build caocap\caocap.sln -c Debug -p:Platform=x64
```

This project is unpackaged (`WindowsPackageType` is `None`). It does not build or run on macOS.

## What you should see

A single window titled **CAOCAP** that shows **Hello, world!**

## What is not implemented

Explore, Build, Collaborate, Firebase, device presence, the floating Agent, and computer use are not present. This is a launchable shell, not the platform.
