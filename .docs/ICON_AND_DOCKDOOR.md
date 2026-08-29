# YouGlass icon and external dock refresh

## Bundle contract

The 2.0 app bundle uses the stable bundle identifier `com.kevinhowe.YouGlass`
and the stable logical icon name `YouGlass`. A release must include both:

- the layered `Sources/YouTubeMac/Resources/YouGlass.icon` source for `actool`;
- `Sources/YouTubeMac/Resources/YouGlassIcon.icns` as the packaging fallback.

`script/build_and_run.sh` compiles the Icon Composer source into `Assets.car`
and `YouGlass.icns` when the installed Xcode toolchain supports it. The
fallback ICNS keeps older or incompatible build environments usable.

## LaunchServices refresh

`YouGlassAppIconRefresh` runs from
`YouGlassAppDelegate.applicationDidFinishLaunching`. It calls the public
`NSWorkspace` filesystem-notification and icon lookup APIs for the running
bundle. Sparkle launches the newly installed bundle, so this runs after an
update as well as after a normal launch. This prompts macOS LaunchServices to
re-read the current icon without changing the bundle identifier or requiring
credentials.

The refresh is deliberately best-effort. YouGlass cannot invalidate a private
icon cache owned by another application. DockDoor stores the pinned YouGlass
entry by bundle identifier and application path, and the local inspected entry
had no custom icon override. Its preview updated after DockDoor itself was
restarted, confirming that the stale image was an external cache rather than a
missing icon in `dist/YouGlass.app`.

## Cross-Mac expectation

Every Sparkle release carries the icon resources in the signed app archive, and
the updated YouGlass process asks LaunchServices to refresh them on launch. If
DockDoor is already running and continues to display the previous preview, the
reliable user action is to quit and reopen DockDoor (or refresh/reselect the
YouGlass item in DockDoor's Apps & Profiles view). YouGlass cannot guarantee a
live refresh of DockDoor's private cache on another Mac unless DockDoor exposes
an invalidation API or refreshes its cache when the bundle changes.

Do not add a custom icon path to DockDoor as a workaround: that would make the
preview independent from Sparkle's signed YouGlass bundle and could preserve a
stale asset indefinitely.

## Verification checklist

1. Build the staged bundle with `./script/build_and_run.sh build`.
2. Confirm `CFBundleIdentifier`, `CFBundleIconName`, `CFBundleIconFile`, and
   both `Assets.car` and `YouGlass.icns` in `dist/YouGlass.app`.
3. Relaunch the staged app and inspect the lifecycle diagnostics for
   `Refreshed application icon registration`.
4. If validating DockDoor, quit and reopen DockDoor before comparing its pinned
   YouGlass preview. Do not delete DockDoor preferences or its caches as part
   of normal release validation.
