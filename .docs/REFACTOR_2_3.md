# YouGlass 2.3 responsibility review

The existing codebase is already organized into App, Models, Stores, Services, and Views. This pass preserves those boundaries and SwiftPM target identity rather than replacing the application architecture or rewriting stable playback code.

| Boundary | Result |
| --- | --- |
| App composition | Existing scene, commands, window ownership, and persisted identities retained |
| Recommendations | Feed values, ranking, interest signals, and source rotation separated |
| Store | Feed presentation and recommendation query construction extracted from persistence |
| Network models | Video/search, account, and community response families separated; display formatting moved to Models |
| Home and Library | Continue Watching, personal Library composition, and note editor separated |
| Appearance | Theme identity/metadata separated from concrete Light/Dark palettes |
| Player | Existing playback ownership retained; explicit scroll viewport sizing added after a live layout stall |
| Release | Existing Developer ID, notarization, and Sparkle pipeline retained |

Behavioral changes are covered by regression tests for independent interest budgets, channel identity, contextual ranking, current-video exclusion, freshness versus diversity, bounded source rotation, generic/duplicate signals, and full feed partitioning. All Swift files remain below 500 lines.

This is a responsibility-focused refactor, not a claim that every source file was rewritten. Future changes should preserve these seams and continue to validate the rebuilt app's actual interactions.
