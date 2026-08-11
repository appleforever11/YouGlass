# YouGlass Versioning and Release Path

YouGlass uses Semantic Versioning and Git tags with a leading `v`.

## Release line

| Version shape | Meaning | Examples |
| --- | --- | --- |
| `1.0.0` | First stable GitHub release | `v1.0.0` |
| `1.0.x` | Patch, bug fix, security, or compatibility release | `v1.0.1`, `v1.0.2` |
| `1.0.x.n` | Same-line rebuild with a higher Sparkle build number; the user-facing release may use a suffix such as `(a)` | `v1.0.5.1` -> `1.0.5(a)` |
| `1.x.0` | Backward-compatible feature release | `v1.1.0` |
| `2.0.0` | Breaking change or migration | `v2.0.0` |

The first release from this repository is `1.0.0`. The prior internal `0.1.0` build is treated as a development predecessor, not as a public update baseline.

## Every release

1. Update `CFBundleShortVersionString` and the numeric `CFBundleVersion` in `Sources/YouTubeMac/Info.plist`. Supplemental rebuilds keep the base short version and use a higher numeric build.
2. Add `RELEASE_NOTES/<tag-version>.md` with end-user-facing notes: what changed, what was fixed, and any action required. The notes may use a display label such as `1.0.5(a)`.
3. Run `swift test`.
4. Run `./script/build_and_run.sh --verify` with audio muted during local playback checks.
5. Run `./script/package_release.sh <version>` and validate the app bundle and ZIP.
6. Create and push the matching tag: `git tag -a v<version> -m "YouGlass <version>" && git push origin v<version>`. Supplemental builds use a fourth numeric tag component so Sparkle can distinguish them.
7. Confirm the GitHub release contains the arm64 ZIP, DMG, appcast, and the same release notes.
8. Install the release on the MacBook Neo and M4 Mac mini, then use **YouGlass > Check for Updates...** to verify the next update path.

## Sparkle rules

- `SUPublicEDKey` is stable for the lifetime of the default update channel.
- `SUFeedURL` points to the latest GitHub release appcast, not to a local file.
- Update archives must be signed with Sparkle Ed25519 and Apple Developer ID code signing.
- Never commit the Ed25519 private key, Developer ID certificate, notarization key, OAuth client secret, API key, or account token.
- If the signing key must be rotated, follow Sparkle's key-rotation procedure and publish the transition as a carefully reviewed release.
