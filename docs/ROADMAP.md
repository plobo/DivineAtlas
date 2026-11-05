# Roadmap

## Milestone 1 — Foundation ✅ (2026-11-01)

- [x] Xcode project (XcodeGen `project.yml`) with app, unit-test, and UI-test targets
- [x] iOS 17.0 deployment target (needed for SwiftData and `@Observable`)
- [x] Swift 6 language mode with complete strict concurrency; builds with no warnings
- [x] App entry point and `DependencyContainer` composition root
- [x] Domain models, `ContentRepository` protocol, and use cases (`EntityQuery`, `EntityDetail`, `ReligionOverview`)
- [x] Seed JSON loader with schema versioning, detailed decoding errors, and referential validation
- [x] Design tokens (`Theme`) and shared components (state views, entity row, chips, artwork placeholder, section header)
- [x] Four-tab shell with a separate `NavigationStack` per tab and typed `Route` navigation
- [x] Small deterministic draft sample dataset (4 religions, 9 entities, 7 sources)
- [x] 41 unit tests and 4 UI tests, all passing

Delivered early, ahead of Milestone 2: basic list → detail navigation, a
religion landing page, Discover (featured entries plus traditions), and an
entity detail screen. These were built to show the shell working and will be
expanded in Milestone 2.

## Milestone 2 — Browse and detail UI ✅ (2026-11-04)

- [x] Search in each browse tab (`.searchable`, bound to `EntityQuery`) and global search in Discover (`Features/Search`)
- [x] Tradition and category filter chips. Category options narrow to the selected tradition, and an incompatible category is cleared.
- [x] "Featured only" toggle and sort order (alphabetical / featured first) in a toolbar menu
- [x] Active-filter summary with result count and **Reset**; a "No Matches" state with a reset action
- [x] Components: `FilterChip`, `FilterChipBar`, `TraditionFilterView`, `CategoryFilterView`, `ActiveFilterSummaryView`, `VideoLinkCard`, `MediaAttributionView`
- [x] Entity detail: sections ordered by kind, video section (opens externally), artwork when available with placeholder fallback, "Image credit" sheet, artistic-reconstruction label
- [x] `StaticContentRepository` plus previews for the loaded, empty, error, and loading states
- [x] Debug-only UI-test scenarios (`-uiTestEmptyContent`, `-uiTestFailingContent`)
- [x] 57 unit tests and 10 UI tests, all passing

Deferred, with reasons:
- *Sort by recently added:* added in Milestone 3, along with `addedAt`.
- *`FavoriteButton`:* added in Milestone 4.
- *`SearchFieldView`:* the native `.searchable` field is used instead, for system accessibility and keyboard behaviour.
- *Artwork caching:* added in Milestone 4 (`ImagePipeline`).

## Milestone 3 — Seed content ✅ (2026-11-04)

- [x] JSON schemas (`docs/schema/`) and the `scripts/validate_seed_schema.py` checker
- [x] Four religion records, with source lists updated
- [x] **67 draft entries** (90 classifications, 43 relationships) across all four traditions
- [x] 23 source references, each recording its citation numbering convention
- [x] Media attribution requirements enforced by the validator (licence, source URL, creator/attribution). No media has been added yet.
- [x] New validation rules: uncited claims, incomplete media attribution, video fields, duplicate relationship IDs
- [x] `addedAt` field, "Recently Added" sort option, and a "Recently Added" section in Discover
- [x] Generated editorial checklist: [CONTENT_REVIEW.md](CONTENT_REVIEW.md) (`scripts/generate_content_review.py`)
- [x] 66 unit tests and 10 UI tests, all passing. The UI tests now search instead of assuming an entry is on screen.

Still needs a human (it can't be automated):
- [ ] Choose an edition or translation for each source and record it in `sources.json`
- [ ] Review every row in CONTENT_REVIEW.md, verifying the unchecked citations first (see CONTENT_GUIDELINES)
- [ ] Decide how to represent a tradition's view of figures it does not venerate (e.g. Jesus in Judaism)

## Milestone 4 — Persistence and media ✅ (2026-11-04; unit tests pass, UI tests not yet run)

- [x] SwiftData user data (`UserDataStore` / `SwiftDataUserDataStore`), with an in-memory fallback
- [x] Favorites: `FavoriteButton` on the detail screen, a heart on list rows, a context-menu toggle, a Favorites screen, and handling of removed entries
- [x] Recently viewed (capped at 20); "Your Favorites" and "Recently Viewed" sections in Discover
- [x] Preferences: sort order per tab and the last selected tab, saved across launches
- [x] `HTTPClient` networking layer with typed errors and a test transport
- [x] `ImagePipeline`: bounded memory and disk caches (LRU), request de-duplication, downsampling; replaces `AsyncImage`
- [x] Video cards show an alert when a link cannot be opened
- [x] Offline behaviour documented and covered by unit tests (disk-cached images served without network)
- [x] New unit tests (library on both stores, HTTP client, disk cache, image pipeline, favorites/Discover/detail view models) and UI tests (favorite toggle, persistence across relaunch, Favorites empty state, recently viewed, tab restoration). All compile.

**Verification status:** the full test suite has **not** been run for this
milestone. The run was stopped on request partway through. Unit tests have since
passed in Milestone 5. Run the UI tests:

```sh
xcodebuild -project DivineAtlas.xcodeproj -scheme DivineAtlas \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Still open: curate the first licensed artwork and reviewed video links. This
needs human licence review (see MEDIA_LICENSING).

## Milestone 5 — Quality ✅ code review complete (2026-11-04); manual checks pending

See [QUALITY_REVIEW.md](QUALITY_REVIEW.md) for findings, fixes, and measurements.

- [x] Unit tests for repositories and view models. **108 unit tests, all passing.** These cover all Milestone 4 code, and that run found and fixed four faulty Milestone 4 tests.
- [x] UI tests for critical journeys, plus new accessibility audits at default and largest text sizes. Written and compiling; **not yet run**.
- [x] Dynamic Type review: adaptive layouts, capped title and chip sizes, simulator check at AX-XXXL
- [x] VoiceOver review (code): decorative thumbnails, named favourite actions, headings
- [x] Error and cancellation handling reviewed; save errors now appear at the root
- [x] Performance and memory: search index, size-bucketed image decoding, cached lookups, measured timings
- [x] Content: Shvetashvatara locator added; `ContentLintTests` enforce mechanical editorial rules
- [ ] Run the UI test suite and accessibility audits
- [ ] VoiceOver walkthrough on a real device
- [ ] Instruments profiling on a device
- [ ] Human content review (CONTENT_REVIEW.md)

## Milestone 5a — Entity images ✅ (2026-11-04)

Goal: licensed artwork for every entity where a suitable image exists.

- [x] `curation/media.json`: a hand-mapped Wikimedia Commons file for each of the 67 entities. **60 candidates, 7 exclusions** with reasons (Muhammad by policy; Azrael, Ifrit, Kiraman Katibin, and Tarakasura because no suitable historical image exists; Shayatin and Nephilim because the available images would misrepresent them)
- [x] `scripts/fetch_commons_media.py` (`--fetch` / `--review` / `--apply`): throttled and batched, retries on 429, licence allowlist, caption overrides, and drops timestamp-style dates
- [x] `MediaAsset` gains `licenseURL`, `dateText`, and `reviewedAt`; the validator enforces the allowlist and `reviewedAt`; JSON Schema updated
- [x] Detail hero credit line ("Artist, date · Licence") linked to the credit sheet, which now shows the date and a licence link; `HTTPClient` sends a User-Agent and supports per-request headers
- [x] Depiction policy documented in CONTENT_GUIDELINES; a unit test ensures Muhammad has no image
- [x] Verified end to end by a trial apply of all 60 candidates (schema OK, 114 unit tests passed, images loaded in the simulator), then reverted
- [x] Tests: licence allowlist, rejected licences, unreviewed media, extended field decoding, credit line, HTTP headers; the "missing artwork" UI test now uses Muhammad so it stays deterministic
- [x] **56 images approved and shipped** (approved 2026-11-04; metadata re-fetched before applying; 134 unit tests pass)
- [ ] **User:** decide the 4 held candidates, which stay on the placeholder for now: Metatron (image from a different tradition), God in Judaism (shows the divine name), Ravana (public-domain status: the artist died in 1965), and Shurpanakha (depicts her mutilation episode). The reason for each is recorded as `heldReason` in `curation/media.json`.
- [ ] **User (Milestone 6):** a contact for the User-Agent

## Milestone 5b — YouTube videos per entity ✅ (2026-11-04; UI tests not yet run)

Goal: a "Videos on YouTube" list on each entity page, e.g. results for "Vishnu Hinduism".

- [x] `VideoSearchService` protocol and `YouTubeSearchService` actor (YouTube Data API v3 `search.list`, `type=video`, `safeSearch=strict`, `relevanceLanguage=en`, 10 results), DTOs, an error-envelope mapper (quota vs. rejected), and an HTML-entity decoder for titles
- [x] Topic-specific queries: name plus its traditions for one or two traditions ("Vishnu Hinduism"); otherwise name plus category ("Gabriel Angel")
- [x] On-device cache per query: fresh for 24 h; stale results served only on temporary failures (offline, quota); never older than 30 days (API policy)
- [x] `EntityVideosSection`:
  - built lazily (the detail screen now uses a `LazyVStack`), so no quota is spent unless you scroll to it
  - thumbnails go through `ImagePipeline`
  - shows title and "Channel · YouTube"
  - opens videos in the YouTube app or Safari
  - carries an "unreviewed results" notice
- [x] An always-visible **Search on YouTube** fallback, with clear messages for no key, quota, offline, and errors
- [x] The key flows from a gitignored `Config/Secrets.xcconfig` through `Config/App.xcconfig` into Info.plist; the app builds and falls back cleanly without it. Requests send `X-Ios-Bundle-Identifier`.
- [x] Curated videos renamed "Recommended Videos" to distinguish them from unreviewed results
- [x] Debug `-uiTestStubVideos` scenario. Any UI-test launch otherwise disables the live service, so tests never call the API.
- [x] 20 new unit tests (query building, request parameters and headers, mapping, error mapping, cache TTL, stale-serving rules, view model states); 134 unit tests pass. New `VideosUITests` written, **not yet run**.
- [x] Development key: reused from another project (verified working with this bundle ID)
- [ ] **Milestone 6:** create a dedicated key restricted to iOS apps with this bundle ID and to the YouTube Data API only. The reused key shares quota with the other project, and any key shipped in an app binary can be extracted.

## Milestone 6 — Release preparation

- [ ] App icon (the asset catalog slot is currently empty) and screenshots
- [ ] Privacy disclosures, privacy policy, and support information
  - Include YouTube API use: requests go to Google, and the YouTube API Terms require linking the Google Privacy Policy
- [ ] Media licence audit, TestFlight build, and App Store metadata
- [ ] Final Wikimedia User-Agent contact and YouTube API key restriction for the release bundle ID

## Open decisions

- Final bundle identifier and development team (currently `com.divineatlas.DivineAtlas`, unsigned)
- Whether the app is iPhone-only (current setting) or also supports iPad
- Whether to replace XcodeGen with a checked-in `.xcodeproj`

## Future (post-MVP)

Cross-tradition comparison pages, a relationship explorer, timelines, more
traditions, localisation, audio narration, editorial collections, and a CMS
backend. AI question answering only once source attribution and review are
reliable.
