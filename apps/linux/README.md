# CAOCAP for Linux

Rust GTK 4 + libadwaita Hello World shell. Explore, Build, Collaborate, the floating Agent, and computer use are not implemented.

This client is the planned desktop counterpart to macOS. Product development still starts with iOS and macOS.

Prefer the Flatpak/GNOME SDK path so the app is built against a known GTK and libadwaita, not whatever the host distro ships.

## Setup with Flatpak (recommended)

1. Install [Flatpak](https://flatpak.org/setup/) and [flatpak-builder](https://docs.flatpak.org/en/latest/flatpak-builder.html).
2. Install the GNOME 48 SDK, Platform, and Rust extension:

```sh
flatpak install flathub org.gnome.Platform//48 org.gnome.Sdk//48 org.freedesktop.Sdk.Extension.rust-stable
```

3. From [caocap/](caocap/):

```sh
flatpak-builder --user --install --force-clean build-dir com.ficruty.caocap.yml
flatpak run com.ficruty.caocap
```

The manifest allows network during `cargo build` so contributors do not need a vendored `Cargo.lock` source list. Pinning crate sources for offline Flathub builds is later work.

## Setup with system packages

Install a Rust toolchain and GTK 4 / libadwaita development packages, then from [caocap/](caocap/):

```sh
cargo run
```

Package names vary. On Fedora: `gtk4-devel libadwaita-devel`. On Debian/Ubuntu: `libgtk-4-dev libadwaita-1-dev`. Host library versions can drift from the crates; use Flatpak if `cargo` cannot find a new enough GTK.

A macOS Homebrew GTK install is optional and is not a supported contributor target.

## What you should see

A single window titled **CAOCAP** that shows **Hello, world!**

## What is not implemented

Explore, Build, Collaborate, Firebase, device presence, the floating Agent, and computer use are not present. This is a launchable shell, not the platform.
