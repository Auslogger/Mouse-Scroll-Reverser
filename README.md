# Mouse Scroll Reverser

A small native macOS menu-bar utility that reverses ordinary mouse-wheel
scrolling while leaving precise/continuous trackpad scrolling untouched.

## Current first-version behavior

- Reverses vertical, line-based scroll-wheel events.
- Passes continuous/pixel-based scrolling through without modifying it.
- Runs as a menu-bar app without a Dock icon.
- Enables mouse-wheel reversal by default on first launch.
- Provides all controls and status information in its menu-bar menu; there is
  no settings window.
- Requests Accessibility permission when the utility is first enabled. The
  separate Accessibility Settings item only opens System Settings.
- Can register the app to start at login on macOS 13 or later.             
- Immediately tears down its event tap if Accessibility permission is revoked.

The conservative classifier protects trackpad scrolling, but a high-resolution
or vendor-smoothed mouse wheel may also be classified as continuous and left
unchanged. Magic Mouse support is intentionally outside this first version.

## Install a release

Download the `universal-unnotarized.zip` file from the GitHub release, not one
of GitHub's automatically generated source-code archives. The same app runs
natively on both Apple Silicon and Intel Macs.

This build is open source and ad-hoc signed, but it is not notarized by Apple.
After moving `MouseScrollReverser.app` to `/Applications`, try to open it once.
Then open **System Settings → Privacy & Security**, scroll to **Security**, and
choose **Open Anyway**. Confirm the warning, then grant the app Accessibility
permission when requested.

Do not disable Gatekeeper globally. A managed work or school Mac may prevent
unnotarized applications from being opened.

## Build

Requirements:

- macOS 13 or later
- Full Xcode installation selected with `xcode-select`

Run:

```sh
make
```

The default build is a universal macOS binary containing both Apple Silicon
(`arm64`) and Intel (`x86_64`) code. To build only one architecture while
developing, override `ARCHS`, for example:

```sh
make clean
make ARCHS=arm64
```

Run `make clean` before changing `ARCHS` so object files from a previous build
cannot be reused.

The app will be created at:

```text
build/MouseScrollReverser.app
```

The build is ad-hoc signed when no Apple Development identity is configured.
That is sufficient for local testing, but each changed build has a new code
identity. Remove the old Accessibility entry and add the newly built `.app` if
macOS continues to show permission as required after a rebuild. A stable Apple
Development or Developer ID signature avoids this repeated approval.

## First launch

1. Open `build/MouseScrollReverser.app`. Reversal is enabled by default and
   its icon appears in the menu bar.
2. The system permission prompt appears because the utility is trying to
   enable reversal. Follow it to **System Settings → Privacy & Security →
   Accessibility** and enable the current build.
3. Return to the utility. It detects the permission state and starts its event tap
   automatically.
4. Keep macOS Natural Scrolling enabled so the trackpad retains its normal
   direction.
5. Use the menu-bar menu to disable/re-enable reversal, open Accessibility
   settings, control Start at Login, or quit.

Choosing **Open Accessibility Settings…** never presents a second permission
prompt, so the prompt and System Settings do not overlap. If access is missing,
choosing **Enable Reverse Mouse Scrolling…** requests it.

If a previous build is already running, quit it from the menu-bar item before
testing a newly built copy. Rebuilding changes the ad-hoc signature, so macOS
may require you to remove/re-add the app or toggle its Accessibility entry off
and on before the new executable becomes trusted.

For reliable **Start at login** behavior, copy the final app to `/Applications`
before enabling that option. Login-item registration depends on the app's path
and code signature remaining stable.

## Test the transformation logic

```sh
make test
```

The tests construct synthetic Core Graphics scroll events and verify disabled,
vertical, and continuous-event behavior.

## Source layout

- `Sources/ScrollTap.c`: event tap and C transformation logic.
- `Sources/AppDelegate.m`: menu-bar UI, permissions, and login item.
- `Sources/main.m`: application entry point.
- `Tests/ScrollTapTests.c`: synthetic-event tests.
- `Resources/Info.plist`: application-bundle metadata.
- `Resources/AppIcon.png`: original app icon artwork.
- `Resources/Assets.xcassets`: generated macOS icon sizes.
- `Resources/AppIcon.icns`: compiled icon copied into the app bundle.
- `Makefile`: local build, signing, test, and verification commands.

## License

Mouse Scroll Reverser is available under the MIT License. See `LICENSE` for
the complete terms.


