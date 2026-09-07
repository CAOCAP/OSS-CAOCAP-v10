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

## Continuous integration

GitHub Actions workflow [`.github/workflows/windows.yml`](../../.github/workflows/windows.yml) builds Debug|x64 on `windows-latest` with the .NET 8 SDK, then launches the unpackaged exe and uploads the build output plus a screenshot artifact of the **CAOCAP** Hello World window. The capture step uses a small Windows.Graphics.Capture helper under [scripts/wgc-capture](scripts/wgc-capture) because GDI `BitBlt` / `PrintWindow` often record WinUI content as a blank frame.

The job uses sparse checkout of `apps/windows` only. A full clone fails on NTFS because `docs/research/WALLYELDIN E./` ends with a dot (a Windows-invalid directory name). Research files are left as imported; they are not required to compile this shell.

That job is compile-and-capture CI. It is not a substitute for local Visual Studio 2022, and it does not run Explore, Build, or Collaborate (those are not implemented).

## What you should see

A single window titled **CAOCAP** that shows **Hello, world!**

## What is not implemented

Explore, Build, Collaborate, Firebase, device presence, the floating Agent, and computer use are not present. This is a launchable shell, not the platform.
