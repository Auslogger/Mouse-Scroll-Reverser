<p align="center">
  <img width="500" height="500" alt="MouseScrollReverser" src="https://github.com/user-attachments/assets/d35f8ce0-6139-4423-8c0e-2a5ce94c6e89" />
</p>

# Mouse Scroll Reverser

A utility developed initially for personal use, because MacOS doesn't allow you to natively specify scroll behaviour for different devices. This no-fuss utility allows you to use the trackpad with the natural scroll direction, and the mouse with the "direct" one, without you to ever having to bother about changing the settings back and forth, or having to make-do with only 1 scroll direction for both devices. Very quality of life.

## How it works

- Reverses vertical, line based scroll wheel events.
- Works for Wired and Wireless mice with standard scroll wheels (won't work for the magic mouse).
- Continuous/pixel-based scrolling (trackpad input) is left unchanged.
- Runs as a menu-bar app with a menu.
- Requires Accessibility permissions to be enabled for this app in System Settings.
- Works on macOS 13 or later.
- The app runs natively on both Apple Silicon and Intel Macs (tested on Apple Silicon).
- Provides a Start At Login option in the menu for even more convenience!     

## Installation (for users)

Download the `MouseScrollReverser.zip` file from the GitHub release.

This build is open source and ad-hoc signed, but it is not notarised by Apple.
After moving `MouseScrollReverser.app` to `/Applications`, open it.
Then open **System Settings → Privacy & Security**, scroll to **Security**, and
choose **Open Anyway**. Confirm the warning, then grant the app Accessibility
permission when requested. Enjoy!!

## Build (for developers)

Requirements:

- macOS 13 or later
- Full Xcode installation selected with `xcode-select`

Run:

```sh
cd <path to project directory>
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

The build is ad-hoc signed, so each changed build has a new code identity, so remove the old Accessibility entry and add the newly built `.app` if macOS continues to show permission as required after a rebuild.

## Test (for developers)

```sh
make test
```

The tests construct synthetic Core Graphics scroll events and verify disabled, vertical, and continuous event behavior.

## Source layout

- `Sources/ScrollTap.c`: event tap and C transformation logic.
- `Sources/AppDelegate.m`: menu bar UI, permissions, and login item.
- `Sources/main.m`: application entry point.
- `Tests/ScrollTapTests.c`: synthetic event tests.
- `Resources/Info.plist`: application metadata.
- `Resources/AppIcon.png`: original app icon artwork.
- `Resources/Assets.xcassets`: macOS icon sizes.
- `Resources/AppIcon.icns`: compiled icon copied into the app bundle.
- `Makefile`: local build, signing, test, and verification commands.

## License

Mouse Scroll Reverser is available under the MIT License. See `LICENSE` for
the complete terms.

