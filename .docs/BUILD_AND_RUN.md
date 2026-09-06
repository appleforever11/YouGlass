# YouGlass build, test, run, and package workflow

## Prerequisites

The project currently builds with Swift 6.4 and Xcode 27.0 on Apple Silicon. `Package.swift` declares macOS 14.0 and the Sparkle 2.9.5 exact dependency.

From the repository root:

```sh
swift package resolve
```

## Tests

Use the project script because SwiftPM's test runner needs Sparkle staged into `PackageFrameworks`:

```sh
./script/test.sh
```

The script resolves dependencies, builds the test products, locates Sparkle, stages `Sparkle.framework`, and runs `swift test --skip-build`.

For a narrow compile/test loop, these commands are useful, but the script is the authoritative test entry point:

```sh
swift build --product YouGlass
swift test --filter YouTubeMacTests
```

## Development build and runtime validation

`script/build_and_run.sh` is the authoritative local app loop. It builds the selected configuration, restarts only the executable inside this checkout's `dist/YouGlass.app` for run modes, stages the real app bundle, copies Sparkle, applies the app's `Info.plist`, handles icon resources, signs the bundle when an identity is available, and opens the bundle with LaunchServices. Build-only mode does not stop running apps. Installed and archived copies are never terminated by process name alone.

```sh
./script/build_and_run.sh                 # build and open debug app
./script/build_and_run.sh build           # build/stage without opening
./script/build_and_run.sh --verify        # build, open, process-check, codesign-check
./script/build_and_run.sh --logs          # open and stream process logs
./script/build_and_run.sh --telemetry     # open and stream the app subsystem
```

The supported environment overrides are:

- `YOUGLASS_BUILD_CONFIGURATION=debug|release`
- `YOUGLASS_SIGNING_IDENTITY="..."` to choose a signing identity; otherwise the script chooses a stable available identity or ad-hoc signing.
- `SPARKLE_FRAMEWORK_PATH=/absolute/path/to/Sparkle.framework` when the normal resolved path is unavailable.
- `YOUGLASS_BUILD_BINARY=/absolute/path/to/YouGlass` to stage an already-built binary without compiling.

To include native macOS 27 Home pull-to-refresh in a local build, explicitly select the installed beta SDK for the command:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
YOUGLASS_BUILD_CONFIGURATION=release ./script/build_and_run.sh --verify
```

This leaves global Xcode selection and the GitHub release workflow unchanged. Xcode 26 builds compile out the macOS 27 refresh controller even when launched on macOS 27.

For a UI change, run `./script/build_and_run.sh --verify`, open Settings, select the affected page, resize if relevant, and inspect the real window with Computer Use. A successful Swift build alone is not sufficient evidence for settings layout or scroll behavior.

For the current product foundation milestone, smoke-test the rebuilt bundle at minimum across these paths: Home -> `For You` -> Continue Watching -> resume; card context menu -> Watch Later/queue; Library -> collection and note creation; player -> queue, speed, mini-player, PIP, full screen, and Share; `⌘K` -> palette command; Settings -> Accent editor and recommendation toggles; and offline/cached Home behavior. Verify that local data survives a relaunch. Theme changes should be checked in both Light and Dark, especially at the player media/page boundary.

## Artifacts

- Development/release bundle: `dist/YouGlass.app`
- Release ZIP: `./script/package_release.sh [version] [output.zip]`
- Installable DMG: `./script/package_dmg.sh [output.dmg]`
- Debug export: `./script/export_debug_report.sh [output-directory]`

Release packaging defaults to `YOUGLASS_BUILD_CONFIGURATION=release`, validates the nested code signature, and creates local artifacts. Stable GitHub/Sparkle publication is a separate user-authorized operation.

## Remote development boundary

`script/configure_remote_deploy.sh`, `script/deploy_dev.sh`, and `script/remote_logs.sh` support an optional SSH development copy on another Mac. They are not part of the normal local build loop. Do not use them, create GitHub releases, or push Git changes unless the user explicitly requests that remote action.

## Common failure classification

- Dependency resolution failure: inspect `swift package resolve` and `.build/artifacts/sparkle`.
- Compiler failure: record the first real Swift error and fix source or SDK compatibility.
- Framework staging/link failure: verify the resolved Sparkle framework path and package configuration.
- Signing failure: distinguish local xattrs/identity problems from source/compiler problems; do not alter credentials or Keychain data as a workaround.
- Launch failure: verify the real `.app` bundle, `Info.plist`, process name, and activation policy.
- UI failure: reproduce after a fresh bundle build and inspect runtime state; do not treat build success as behavior success.
