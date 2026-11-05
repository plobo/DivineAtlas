# Quality Review (Milestone 5)

Review date: 2026-11-04. Method: a code review of every screen and service,
the unit test suite, timing measurements, and simulator screenshots at the
largest accessibility text size. **Not yet done:** UI tests and the automated
accessibility audits (written, not run), on-device VoiceOver testing, and
Instruments profiling. See [Remaining manual checks](#remaining-manual-checks).

## Findings and fixes

| # | Area | Finding | Fix |
| --- | --- | --- | --- |
| 1 | Performance | Search re-normalised every string of every entity on each keystroke, and recomputed the needle for each entity. | `EntitySearchIndex` pre-normalises text once at load (built off the main actor); the needle is computed once per query. |
| 2 | Performance | `FavoritesViewModel` rebuilt its ID→entity dictionary on every property read. | The dictionary is built once at load. |
| 3 | Memory | Every image was decoded at up to 1600 px, including 72 pt list thumbnails. | `ImagePipeline` decodes per display-size bucket (128–1600 px) and caches each bucket in memory. Original bytes are stored once on disk. |
| 4 | VoiceOver | List thumbnails announced "No artwork available for X" before every entry's name. | Row thumbnails are decorative (`accessibilityHidden`). The detail hero keeps its label. |
| 5 | VoiceOver | Adding a favourite from a list needed a long-press context menu. | Rows also expose a named accessibility action (Actions rotor). |
| 6 | Touch targets | Filter chips were about 36 pt tall. | Minimum height is now 44 pt. |
| 7 | Dynamic Type | Label + trailing-control rows (filter summary, classification header, Discover favourites header, unavailable-favourites row) squeezed at accessibility sizes. | A new `AdaptiveStack` switches these rows to vertical at accessibility sizes. |
| 8 | Dynamic Type | The large navigation title truncated to "Gods…" at the largest size. | Navigation titles scale with Dynamic Type up to 40 pt (large) and 28 pt (inline). |
| 9 | Dynamic Type | A single filter chip filled the screen width at the largest size. | Chip rows cap at `accessibility2` and still scale well above default. |
| 10 | Errors | A save failure from a list's context menu only showed its alert on the detail screen, later and out of context. | The alert moved to `RootTabView` and appears wherever the failure happens. |
| 11 | Content | The Shiva entry cited the Shvetashvatara Upanishad without a passage. | It now cites 3.2, and the source notes its chapter.verse convention. |
| 12 | Content | The no-direct-quotation rule was not enforced. | `ContentLintTests` checks for quotation marks, summary length, duplicate alternative names, relationship ID format, source notes, and that each religion has entries and sources. |
| 13 | Tests | Three image tests and one disk-cache test from Milestone 4 were wrong. The fixture images were drawn at screen scale, and identical eviction blobs made the date helper touch every file. | Fixtures now use scale 1 and distinct blobs. All pass. |

## Error and cancellation handling (reviewed, no change needed)

- Every view model handles `idle → loading → loaded | failed`. A
  `CancellationError` (the view disappeared mid-load) returns the model to
  `idle`, so the next appearance retries instead of showing an error.
- `loadIfNeeded()` prevents duplicate loads. Retry buttons call `load()`.
- `async let` fan-out in Discover, Religion detail, and Entity detail cancels
  sibling requests when one fails.
- `HTTPClient` maps `URLError.cancelled` to `CancellationError` and offline
  codes to `.offline`. It rejects non-HTTPS URLs before any request.
- `ImagePipeline` shares one download between concurrent requests for the same
  image. A cancelled requester doesn't cancel the shared download, so other
  requesters still get the image.
- `UserLibrary` applies changes optimistically and reverts them on failure.
  Recording history is best-effort and only logged.

## Measurements

Simulator (iPhone 17, iOS 26.1, Intel Mac host), XCTest `measure`, 10 runs.

| Operation | Dataset | Average |
| --- | --- | --- |
| Load and validate bundled seed data | 67 entries | 4 ms |
| Search with index (filter + sort) | 5,000 synthetic entries | 35 ms |
| Search without index | 5,000 synthetic entries | 122 ms |
| Build search index (off the main actor) | 5,000 synthetic entries | 269 ms |

At today's 67 entries, search is well under 1 ms per keystroke. The index
keeps search interactive even at about 75× the current dataset.

Memory bounds: decoded images are capped at 64 MB (`NSCache`, which also
evicts under memory pressure) and the disk cache at 150 MB (LRU). Lists are
`LazyVStack`, so off-screen rows are not built.

## Accessibility status

| Check | Status |
| --- | --- |
| Dynamic Type: system text styles throughout | ✅ |
| Layouts adapt at accessibility sizes | ✅ Visually checked at AX-XXXL on the Gods & Angels tab. Other screens use the same components. |
| Semantic headings (section headers, entity name, tradition names) | ✅ |
| Status not conveyed by colour alone (chips, favourites, featured, draft) | ✅ Icons, text, and the `isSelected` trait |
| Meaningful labels for artwork and controls | ✅ |
| Touch targets ≥ 44 pt | ✅ Chips fixed. System controls elsewhere. |
| Reduce Motion | ✅ The app adds no custom animations. Only haptic feedback on favouriting. |
| Contrast | ✅ By design: gold about 8:1 and secondary text about 9:1 on the background. To be confirmed by the audit. |
| Automated audit (`performAccessibilityAudit`) at default and AX-XXXL sizes | ⏳ Written (`AccessibilityUITests`), not yet run |
| VoiceOver on a real device | ⏳ Manual |

## Remaining manual checks

1. Run the UI tests, including the new accessibility audits:
   ```sh
   xcodebuild -project DivineAtlas.xcodeproj -scheme DivineAtlas \
     -destination 'platform=iOS Simulator,name=iPhone 17' test -only-testing:DivineAtlasUITests
   ```
   If the audit flags issues in system controls you don't own, filter them in
   `AccessibilityUITests.audit(_:_:)` with a comment explaining why.
2. VoiceOver on a device: browse each tab, apply and reset a filter, search,
   open an entry, follow a related figure, and add or remove a favourite using
   both the detail button and the row's Actions rotor.
3. Instruments (Time Profiler and Allocations) on a device while scrolling the
   lists, once real artwork exists.
4. Content review: work through [CONTENT_REVIEW.md](CONTENT_REVIEW.md). The
   automated lint checks only mechanical rules.
