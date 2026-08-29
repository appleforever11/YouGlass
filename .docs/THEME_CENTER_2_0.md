# YouGlass 2.0 Theme Center

## Purpose

The Appearance page is the visual control center for YouGlass. Version 2.0 expands it from the original twelve environment families to 24 paired Light/Dark families while keeping the persisted selection and original palette values compatible with existing installations.

## Catalog contract

- `YouGlassThemeFamily` remains the Codable/Identifiable store value persisted by `YouTubeStore`.
- The original twelve raw values and color definitions remain in `YouGlassThemeCatalog.swift`.
- The twelve new families and their paired colors live in `YouGlassThemeCatalogExpansion.swift` so the compatibility-sensitive catalog remains reviewable.
- Every family provides a title, subtitle, SF Symbol, collection, and stable `isNew`/`isFeatured` metadata.
- `YouGlassThemeCollection.all` is a presentation-only filter and is never persisted as the selected environment.

The collections are Vivid, Calm, Warm, Cool, Nature, and Minimal. Every family belongs to exactly one non-`all` collection. New families are marked NEW; the curated launch set is marked FEATURED.

## Appearance controls

The Theme Center browser exposes:

- a collection menu;
- case-insensitive search over environment name, description, and collection;
- a result count and empty state;
- a Surprise me action that chooses a different family through `YouTubeStore.setVisualTheme`.

The selected environment summary remains visible above the browser, so filtering cannot hide which environment is active. The existing six-digit accent editor stays layered over the family palette and Reset still returns to the environment default.

## Branding assets

The approved Glass Prism artwork is the source of truth for the 2.0 icon preview and is copied into:

- `Sources/YouTubeMac/Resources/YouGlassIconSource.png`;
- the active layer asset under `Sources/YouTubeMac/Resources/YouGlass.icon/Assets/`;
- `Sources/YouTubeMac/Resources/YouGlassIcon.icns` as the local packaging fallback.

The Icon Composer layer name is `YouGlass 2.0 Glass Prism`. Unrelated legacy artwork has been removed and must not be restored as part of YouGlass branding.

## QA contract

Run the focused Theme Center tests and the full `./script/test.sh` suite. Rebuild the staged app with `./script/build_and_run.sh --verify`, then inspect Settings > Appearance in the actual app: the page must open top-aligned, the catalog must scroll through all 24 families, the collection/search controls must narrow the grid, and selecting a new family must update the app palette and persist across relaunch. When the player ambient boundary is changed, run the full 24-family Light/Dark visual sweep required by `AGENTS.md`.
