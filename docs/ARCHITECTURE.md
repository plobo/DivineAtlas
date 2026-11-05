# Architecture

MVVM with a repository layer and constructor-based dependency injection. No
architecture framework is used.

## Dependency flow

```text
SwiftUI Views (Features/*, Core/DesignSystem)
    │  read state, send intents; push typed `Route`s
    ▼
ViewModels (@MainActor @Observable)
    │  own LoadState, call repositories, apply domain use cases
    ▼
Domain use cases (pure, synchronous, Sendable)
    EntityQuery · EntityDetail · ReligionOverview
    ▼
Repository protocol: ContentRepository (Sendable, async)
    ▼
SeedContentRepository (actor) ── SeedDataLoader ── SeedDataValidator
    ▼
Resources/SeedData/*.json
```

Rules:

- **Views never create services.** They receive view models. `RootTabView`
  resolves navigation destinations through `DependencyContainer`.
- **No global singletons.** `DivineAtlasApp` creates one `DependencyContainer`
  and passes it down explicitly. (`PreviewSupport.container` exists only for
  SwiftUI previews.)
- **Domain logic is pure.** Filtering, search, relationship resolution, and
  grouping live in `Domain/UseCases` and are unit-tested without SwiftUI.
- **No sample data in view files.** All content comes from the repository.

## Concurrency

- Swift 6 language mode with `SWIFT_STRICT_CONCURRENCY = complete`.
- Every domain model is a `Sendable` value type.
- `SeedContentRepository` is an `actor`: it loads and validates seed data once,
  off the main actor, and caches the result.
- View models are `@MainActor`. They load from SwiftUI's `.task`, so loads are
  cancelled when the view disappears. A `CancellationError` returns the view
  model to `.idle` instead of showing an error.
- Independent repository calls run concurrently with `async let`.

## Screen state

`LoadState<Value>` has the cases `idle`, `loading`, `loaded(Value)`, and
`failed(message:)`. Each view model decides what "empty" means for its screen,
and every screen renders `LoadingView`, `EmptyStateView`, or `ErrorStateView`
(with retry) as appropriate. `UserFacingError` maps errors to short messages and
logs full diagnostics with `os.Logger`.

## Navigation

- A `TabView` holds four tabs, each with its own `NavigationStack`, so every
  tab keeps its navigation state when the user switches away.
- `Route` (`.entity(id:)`, `.religion(TraditionID)`) is the only navigation
  currency. Feature views push routes, and `RouteDestinationView` builds the
  destination through the container. Any screen can therefore open an entity
  (lists, religion pages, Discover, related figures) without knowing how it is
  built.

## Features

| Folder | Contents |
| --- | --- |
| `Features/Browse` | `EntityBrowseView` + `EntityBrowseViewModel`, shared by **Gods & Angels** and **Demons**. The two tabs differ only by `EntityGroup`, so the plan's two separate folders were merged to avoid duplication. |
| `Features/Religions` | Religion list, religion landing page (entities grouped by that tradition's categories, texts, interpretive note) |
| `Features/Discover` | Featured entries and "Explore by tradition". Hosts global search. Popularity and "recently added" sections are left out until real data exists. |
| `Features/Search` | `SearchViewModel` + `SearchView`: search across every entity regardless of group, shown in Discover while a query is active |
| `Features/EntityDetail` | Detail screen. Every section is optional and hidden when empty. Has the favorite toggle and records views. |
| `Features/Favorites` | Saved entries (swipe or context menu to remove) and cleanup of unavailable IDs. Opened from Discover. |

## Search and filters

`EntityQuery` (domain) holds group, tradition, category, featured-only,
search text, and sort order. Browse view models own a query, so filter
changes re-derive `visibleEntities` from loaded data without reloading.
`EntitySearchIndex` holds each entity's search text pre-normalised. It is built
once per load, off the main actor, so a keystroke only normalises the query. Each
tab keeps its own filters while you switch tabs, because the tab-root view
models live in `RootTabView`.

## Test and preview doubles

- `StaticContentRepository` serves fixed content or a fixed error, with an
  optional delay. `PreviewSupport` uses it for previews of the empty,
  failing, and loading states.
- In **Debug builds only**, `DependencyContainer.live()` reads the
  `-uiTestEmptyContent` and `-uiTestFailingContent` launch arguments
  (`UITestScenario`), so UI tests can exercise those states deterministically.
  `-uiTestResetUserData` clears favorites, history, and preferences at
  launch, and every UI test starts this way (`XCUIApplication.launchClean()`).
- Unit tests use `MockContentRepository` (an actor with call counting) and
  synthetic fixtures.

## User data (SwiftData)

```text
Views ──> ViewModels ──> UserLibrary (@MainActor @Observable)
                              │  in-memory state, optimistic updates, revert on failure
                              ▼
                      UserDataStore protocol (@MainActor)
                       ├─ SwiftDataUserDataStore  (Application Support/UserData.store)
                       └─ InMemoryUserDataStore   (previews, tests, fallback)
```

- `UserLibrary` is the single source of truth for favorites, recently viewed
  entries (newest first, capped at 20), and preferences (sort order per tab,
  last selected tab). All view models share one instance, so a favorite
  toggled on the detail screen updates the lists and Discover immediately.
- Only **entity IDs** are stored. Entries removed from the seed data are
  reported on the Favorites screen ("no longer in the collection") with a
  Remove action. Opening a removed entry shows the detail screen's "no longer
  available" error state.
- If the on-disk store cannot be opened, the app logs the error and continues
  with `InMemoryUserDataStore`, which works but does not persist.
- No account is needed. All user data stays on the device.

## Networking and images

- `HTTPClient` is HTTPS-only GET with status validation, a response size cap,
  and typed `NetworkError` (`offline`, `httpStatus`, `insecureURL`, …).
  Cancellation surfaces as `CancellationError`. The `HTTPTransport` protocol
  lets tests substitute a stub. URLSession's own cache is disabled.
- `ImagePipeline` (actor) layers:
  1. `NSCache` memory cache, bounded at 64 MB of decoded image data.
  2. `DiskCache` in `Library/Caches/ImageCache`, bounded at 150 MB with
     least-recently-used eviction. It also serves images **offline**.
  3. The network via `HTTPClient`.

  Concurrent requests for the same URL and size share a single download.
  Images are downsampled with ImageIO to the requested display size, rounded
  up to a bucket (128, 256, 512, 1024, 1600 px). Each bucket is cached
  separately in memory, so thumbnails don't hold full-size bitmaps. The disk
  cache holds the original bytes once per URL.
- Injected through the `imageLoader` environment value from `RootTabView`.
  The default value never loads, so previews and tests make no network calls.
  `EntityArtworkView` falls back to a labelled placeholder on any failure.

## Offline behavior

| Data | Offline? |
| --- | --- |
| Entity, religion, and source content | Always: bundled seed JSON |
| Favorites, recently viewed, preferences | Always: on-device SwiftData |
| Artwork | Once viewed: from the disk cache; otherwise a placeholder |
| Curated videos | Need a connection; they open externally. If a link cannot be opened, an alert is shown. |
| YouTube results | Cached results (up to 30 days old) are listed offline; the videos themselves need a connection. |

`ContentRepository` remains the seam for a future remote/cached content source.

## YouTube video search

```text
EntityDetailViewModel ──(on load)──> EntityVideosViewModel(entity, videoSearch)
                                            │  .task when EntityVideosSection scrolls into view
                                            ▼
                               VideoSearchService (protocol)
                                ├─ YouTubeSearchService (actor)  key configured
                                │     ├─ DiskCache "VideoSearchCache" (24 h fresh, ≤30 days stale fallback)
                                │     └─ HTTPClient.response(for:) → YouTubeSearchMapper
                                ├─ UnavailableVideoSearchService  no key / UI tests
                                └─ StubVideoSearchService         Debug, -uiTestStubVideos
```

- **Secrets:** `Config/Secrets.xcconfig` (gitignored; template in
  `Secrets.example.xcconfig`) defines `YOUTUBE_API_KEY`.
  `Config/App.xcconfig` includes it optionally. XcodeGen writes
  `Config/Info.plist` with `YouTubeAPIKey = $(YOUTUBE_API_KEY)`, which is
  merged into the generated Info.plist. `YouTubeSearchService.live()` returns
  nil when the value is empty or unexpanded.
- **Quota:** each uncached search costs 100 units (free tier: 10,000 a day).
  Lazy loading and the cache keep usage per user low.
- **Errors:** `HTTPClient.response(for:)` returns 4xx bodies so the mapper can
  tell `quotaExceeded` (serve stale results) from a rejected or invalid key
  (surface the error). Every failure leaves the "Search on YouTube" button
  working.

## Accessibility building blocks

- `AdaptiveStack` is an HStack that becomes a VStack at accessibility text
  sizes. Use it for any label + trailing-control row.
- `favoriteContextMenu` adds both a context menu and a named accessibility
  action.
- Navigation title fonts are capped (40 pt large, 28 pt inline), and filter
  chip rows at `accessibility2`. All other text scales without limit.
- Thumbnails in rows are decorative. Hero artwork carries the label.

## Project generation

`project.yml` (XcodeGen) is the source of truth for targets and build settings.
Run `xcodegen generate` after adding files.
