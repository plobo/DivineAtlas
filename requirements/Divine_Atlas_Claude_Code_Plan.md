# Divine Atlas --- iOS App Development Plan for Claude Code

> **Project:** Divine Atlas\
> **Platform:** iOS\
> **Primary technology:** Swift 6 + SwiftUI\
> **Architecture:** MVVM with repository pattern and dependency
> injection\
> **Initial traditions:** Christianity, Judaism, Islam, Hinduism\
> **Product goal:** A respectful, source-backed, multimedia encyclopedia
> for exploring divine, angelic, demonic, and other supernatural or
> religious figures.

------------------------------------------------------------------------

## 1. Product vision

Build a polished iOS app that lets users discover and research religious
and mythological figures across multiple traditions. Users should be
able to browse categories, filter by tradition, search, read detailed
histories, view attributed artwork, follow references, watch related
educational videos, and save favorites.

The app is an educational reference product. It must represent
traditions accurately and respectfully, distinguish primary religious
teachings from later folklore and modern interpretations, and avoid
presenting contested claims as universal facts.

### Working title

**Divine Atlas**

Possible future names: Mythos, Celestial Chronicles, Divine & Beyond,
The Sacred Archive.

### Product principles

1.  **Respectful representation:** Do not flatten different traditions
    into one shared taxonomy.
2.  **Evidence and attribution:** Historical and theological claims must
    have traceable sources.
3.  **Clear context:** Identify the tradition, text, period, and
    interpretive context for each claim where known.
4.  **Media rights:** Store image creator, license, source URL, and
    required attribution.
5.  **Data-driven design:** Adding a new religion or category should not
    require rewriting screens.
6.  **Offline-friendly:** Core entity information and favorites should
    remain available offline after being cached.
7.  **Accessibility:** Support Dynamic Type, VoiceOver, contrast, and
    accessible controls from the beginning.

------------------------------------------------------------------------

## 2. Initial scope

### In scope for the MVP

-   Four main tabs:
    1.  Gods & Angels
    2.  Demons
    3.  Religions
    4.  Discover
-   Search by entity name and alternative names.
-   Filter by religion/tradition and entity category.
-   Entity detail pages with images, overview, history, roles, symbols,
    related entities, references, and video links when available.
-   Favorites.
-   Local sample/seed data.
-   Local persistence and basic offline access.
-   Loading, empty, and error states.
-   Unit tests for core logic and view models.

### Out of scope for the first release

-   User-generated content.
-   Public comments or ratings.
-   AI-generated religious answers.
-   Accounts and social profiles.
-   Complex interactive maps.
-   Automated, unreviewed content ingestion.
-   In-app video hosting.

These can be evaluated after the core product and content quality are
established.

------------------------------------------------------------------------

## 3. Information architecture

### 3.1 Main tabs

#### Tab 1 --- Gods & Angels

Browse divine and celestial figures, including gods, goddesses, angels,
archangels, and other tradition-specific categories.

Each list card should show:

-   Primary artwork or a clearly labelled placeholder.
-   Display name.
-   Category.
-   Associated tradition(s).
-   One- or two-sentence summary.
-   Optional featured indicator.

Interactions:

-   Search.
-   Filter by tradition.
-   Filter by category.
-   Sort alphabetically or by featured/recently added.
-   Tap to open entity details.
-   Save/remove favorite.

#### Tab 2 --- Demons

Browse figures described in particular sources or traditions as demons,
adversaries, evil spirits, fallen angels, jinn, asuras, rakshasas, or
related beings.

**Important:** Do not automatically equate these categories. For
example, an asura, rakshasa, jinn, Shaytan, demon, and fallen angel are
not interchangeable concepts. Use tradition-specific classifications and
explain them.

The screen should support the same search, filter, sort, detail, and
favorite behavior as Gods & Angels.

#### Tab 3 --- Religions

Show the initial four traditions:

-   Christianity
-   Judaism
-   Islam
-   Hinduism

Each tradition landing page should include:

-   Short introduction and historical context.
-   Available entities grouped by tradition-specific category.
-   Relevant texts and sources.
-   Notes explaining that beliefs and interpretations may vary within
    the tradition.

Do not imply that every tradition has the same concept of God, angels,
demons, or supernatural beings. For example, Islamic descriptions of
Allah, Christian understandings of the Trinity, Jewish understandings of
God, and Hindu traditions' diverse understandings of divinity require
distinct contextual treatment.

#### Tab 4 --- Discover

Provide curated discovery content:

-   Featured entity.
-   Recently added entities.
-   Popular or frequently viewed entities (only when usage data exists).
-   Editorial collections.
-   Related figures.
-   Optional daily discovery.

Avoid inventing popularity metrics before the app has real usage data.

### 3.2 Entity detail screen

Recommended sections:

1.  Hero image, with image credit/attribution accessible.
2.  Name and alternative names.
3.  Tradition(s) and tradition-specific classification.
4.  Short overview.
5.  Historical background and development over time.
6.  Role, attributes, symbols, and associations, where supported.
7.  Relevant primary texts or passages.
8.  Interpretations and differences across traditions, where relevant.
9.  Related entities and relationship descriptions.
10. Educational videos, when a suitable result exists.
11. Sources and further reading.

Each section should be optional. Do not show empty sections or fabricate
information to fill the screen.

------------------------------------------------------------------------

## 4. Initial content targets

Start with a curated dataset of approximately **60--80 entries**. The
exact distribution should be decided during content research; counts are
targets, not claims that traditions have equivalent categories.

Potential research examples include:

-   Christianity: God, Jesus, Holy Spirit, Michael, Gabriel, Satan, and
    selected biblical or later-tradition figures.
-   Judaism: God, Michael, Gabriel, Satan/the adversary in relevant
    textual contexts, and figures from later Jewish folklore where
    clearly labelled.
-   Islam: Allah, prophets, Jibril, Mikail, Iblis, and jinn-related
    concepts, with careful distinctions.
-   Hinduism: Brahma, Vishnu, Shiva, Devi, selected devas, asuras, and
    rakshasas.

### Content curation rules

-   Treat primary texts and authoritative tradition-specific sources as
    the basis for claims.
-   Use academic or reputable reference works for historical context.
-   Wikipedia may help discover references but should not be the sole
    source for published content.
-   Keep separate claims when traditions interpret a shared name or
    figure differently.
-   Distinguish scripture, commentary, folklore, devotional belief,
    historical scholarship, and modern popular culture.
-   Use neutral wording such as "In \[source/tradition\]..." rather than
    asserting contested theological claims as universal fact.
-   Do not label a figure a "demon" merely because another tradition or
    modern source does so.
-   Include uncertainty or disagreement notes where relevant.
-   Do not invent scripture quotations, dates, historical origins, or
    relationships.

------------------------------------------------------------------------

## 5. Technical architecture

Use a modular, testable architecture with clear separation between UI,
domain logic, and data access.

### Recommended stack

  -----------------------------------------------------------------------
  Area                                Technology
  ----------------------------------- -----------------------------------
  Language                            Swift 6

  UI                                  SwiftUI

  Presentation                        MVVM using `Observable` /
                                      `@Observable` where appropriate

  Concurrency                         Swift Concurrency (`async`/`await`,
                                      actors, task cancellation)

  Persistence                         SwiftData

  Networking                          `URLSession`

  Serialization                       `Codable`

  Images                              A reusable async image-loading and
                                      caching layer

  Video                               Open original video links using
                                      Safari/appropriate system
                                      experience; AVKit only when
                                      playback requirements justify it

  Testing                             XCTest; add UI tests for critical
                                      flows

  Dependencies                        Swift Package Manager

  Minimum iOS version                 Choose and document a target after
                                      checking required SwiftData and
                                      SwiftUI APIs
  -----------------------------------------------------------------------

Do not add a large architecture framework for the MVP. MVVM, repository
protocols, use cases where they add value, and constructor-based
dependency injection are sufficient. Keep boundaries clean so a more
formal state-management approach can be introduced later if necessary.

### Architecture flow

``` text
SwiftUI Views
    |
    v
ViewModels (@Observable, @MainActor where appropriate)
    |
    v
Use Cases / Domain Services
    |
    v
Repository Protocols
    |
    +--------------------+
    |                    |
    v                    v
Local Data Source     Remote Data Source
SwiftData / JSON      URLSession / APIs
    |                    |
    +---------+----------+
              |
              v
        Domain Models
```

### Dependency injection

Create a composition root, such as `DependencyContainer`, that
constructs repositories, services, and view models. Views should not
instantiate network clients or persistence services directly.

Use protocols for dependencies that need substitution in tests. Avoid
creating protocols for every trivial type without a testing or
architectural reason.

------------------------------------------------------------------------

## 6. Domain models

Use one shared entity concept rather than separate models for Gods,
Angels, and Demons. The classification should be extensible and
tradition-aware.

A starting point:

``` swift
enum TraditionID: String, Codable, CaseIterable, Identifiable {
    case christianity
    case judaism
    case islam
    case hinduism

    var id: String { rawValue }
}

enum EntityCategory: String, Codable, CaseIterable, Identifiable {
    case god
    case goddess
    case angel
    case archangel
    case demon
    case fallenAngel
    case jinn
    case asura
    case rakshasa
    case spirit
    case prophet
    case other

    var id: String { rawValue }
}

struct DivineEntity: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var alternativeNames: [String]
    var summary: String
    var traditionIDs: [TraditionID]
    var classifications: [EntityClassification]
    var imageAssets: [MediaAsset]
    var sections: [EntityContentSection]
    var relationships: [EntityRelationship]
    var videoLinks: [VideoLink]
    var sources: [SourceReference]
    var isFeatured: Bool
    var lastReviewedAt: Date?
}

struct EntityClassification: Codable, Hashable {
    var traditionID: TraditionID
    var category: EntityCategory
    var label: String
    var explanation: String?
}

struct EntityContentSection: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var body: String
    var sectionType: String
    var sourceIDs: [String]
}

struct EntityRelationship: Codable, Hashable, Identifiable {
    var id: String
    var relatedEntityID: String
    var relationshipType: String
    var explanation: String
    var sourceIDs: [String]
}

struct MediaAsset: Codable, Hashable, Identifiable {
    var id: String
    var url: URL
    var creator: String?
    var license: String?
    var sourceURL: URL?
    var attributionText: String?
    var isArtisticReconstruction: Bool
}

struct VideoLink: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var url: URL
    var provider: String
    var channelName: String?
    var thumbnailURL: URL?
    var reviewedAt: Date?
}

struct SourceReference: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var author: String?
    var publisher: String?
    var publicationDate: String?
    var url: URL?
    var sourceType: String
    var notes: String?
}
```

This is a starting contract, not a requirement to copy it unchanged.
Refine it after implementing decoding, persistence, and sample data.
Prefer stable string IDs for seeded and remotely sourced content.
Consider storing individual sourced claims separately if the content
model needs to attribute different paragraphs to different references.

### Data model requirements

-   A figure may have multiple tradition-specific classifications.
-   One name may have multiple spellings and transliterations.
-   Relationships must include a type and explanation, not only an ID.
-   Content sections should cite source IDs.
-   Media metadata must preserve attribution and licensing.
-   Video links must be optional and validated.
-   Avoid storing a single universal category if it would misrepresent a
    tradition.

------------------------------------------------------------------------

## 7. Data and content strategy

### MVP approach: curated JSON seed data

Start with local JSON bundled in the app. This allows the UI and
architecture to be completed without depending on third-party APIs.

Suggested files:

``` text
Resources/
  SeedData/
    religions.json
    entities.json
    sources.json
    media.json
```

Create a seed-data loader that:

-   Decodes JSON with useful error reporting.
-   Validates IDs and references.
-   Detects duplicate entity IDs.
-   Verifies relationship references.
-   Handles missing optional media.
-   Provides deterministic sample data for previews and tests.

### Potential external sources

Investigate each source's current terms, API limits, licensing, and
suitability before integration.

-   **Wikidata:** structured identifiers and entity metadata.\
    https://www.wikidata.org/wiki/Wikidata:Data_access
-   **Wikimedia Commons:** historical artwork and media, subject to each
    file's license and attribution requirements.\
    https://commons.wikimedia.org/wiki/Commons:Reusing_content_outside_Wikimedia/en
-   **Britannica and academic references:** background research; do not
    assume content can be republished.
-   **Primary religious texts:** use reputable editions/translations and
    record the exact work, section, and translation where applicable.
-   **YouTube Data API:** search or curate educational videos, subject
    to API policies and quotas.\
    https://developers.google.com/youtube/v3/docs/search

Do not scrape websites or republish copyrighted descriptions. Do not
assume an API's availability implies permission to redistribute its
content.

### Image handling

-   Never use random Google Images as a content source.
-   Prefer media with clear reuse permissions.
-   Store creator, license, source URL, and attribution text.
-   Identify modern artistic interpretations and reconstructions.
-   Provide a fallback image when no suitable licensed artwork is
    available.
-   Cache images with size limits and appropriate eviction.
-   Do not make the app dependent on image URLs remaining permanently
    available.

### Video handling

-   Curate relevant educational videos where possible.
-   Store title, provider, channel, original URL, thumbnail URL, and
    review date.
-   Open the original video URL using the system browser or approved
    provider experience.
-   Handle removed, private, region-restricted, or unavailable videos
    gracefully.
-   Do not download or rehost video content without permission.
-   Do not show an empty video section when no suitable link exists.

------------------------------------------------------------------------

## 8. SwiftUI screen and component plan

Build reusable components and keep feature-specific state in the
appropriate view model.

### Shared components

-   `EntityCardView`
-   `EntityRowView`
-   `EntityArtworkView`
-   `CategoryChipView`
-   `TraditionFilterView`
-   `SearchFieldView`
-   `EmptyStateView`
-   `ErrorStateView`
-   `LoadingView`
-   `SourceReferenceRow`
-   `VideoLinkCard`
-   `RelatedEntityCard`
-   `FavoriteButton`
-   `SectionHeaderView`

### Feature screens

``` text
Features/
  GodsAndAngels/
    GodsAndAngelsView.swift
    GodsAndAngelsViewModel.swift

  Demons/
    DemonsView.swift
    DemonsViewModel.swift

  Religions/
    ReligionsView.swift
    ReligionDetailView.swift
    ReligionsViewModel.swift

  Discover/
    DiscoverView.swift
    DiscoverViewModel.swift

  EntityDetail/
    EntityDetailView.swift
    EntityDetailViewModel.swift

  Search/
    SearchView.swift
    SearchViewModel.swift

  Favorites/
    FavoritesView.swift
    FavoritesViewModel.swift
```

### Navigation

-   Use `TabView` for the four primary destinations.
-   Use `NavigationStack` for navigation within each tab.
-   Use typed routes or a small route model where it simplifies deep
    navigation.
-   Support opening an entity from search, a religion page, Discover,
    and related entities.
-   Preserve sensible navigation state when switching tabs.

------------------------------------------------------------------------

## 9. Design direction

### Visual identity

Use a premium editorial encyclopedia aesthetic:

-   Dark charcoal or deep navy backgrounds.
-   Restrained antique-gold accents.
-   Readable serif display typography paired with a clean system
    sans-serif.
-   High-quality artwork with consistent image treatments.
-   Subtle borders and restrained visual effects.
-   Clear distinction between primary content, source notes, and
    metadata.

Avoid making all religious traditions look like fantasy game content.
The design should feel like a serious cultural and historical reference
app.

### Accessibility

-   Support Dynamic Type.
-   Give meaningful accessibility labels to artwork and controls.
-   Ensure VoiceOver can reach navigation titles and key actions.
-   Use semantic headings and grouping.
-   Do not communicate category or status using color alone.
-   Respect Reduce Motion.
-   Maintain sufficient text and control contrast.
-   Test on real devices with VoiceOver.

------------------------------------------------------------------------

## 10. Search, filters, and favorites

### Search

Search should match:

-   Primary name.
-   Alternative names.
-   Transliteration and spelling variants.
-   Short description.
-   Tradition name.
-   Category label.

For the MVP, local search over the cached dataset is sufficient. Add
server-side search only when a backend exists and the dataset requires
it.

### Filters

Allow users to combine:

-   Tradition.
-   Category.
-   Featured status, where relevant.

Show active filters and provide a clear reset action.

### Favorites

-   Persist favorites locally with SwiftData.
-   Keep favorites available offline.
-   Handle an entity being removed or updated in seed data.
-   Avoid requiring an account for MVP favorites.

------------------------------------------------------------------------

## 11. Persistence and networking

### SwiftData

Use SwiftData for:

-   Cached entity data if appropriate for the chosen model.
-   Favorite entity IDs.
-   User preferences.
-   Recently viewed entities, if included.

Keep remote DTOs separate from persistence/domain models when their
responsibilities differ. Do not tightly couple the API response format
to SwiftUI views.

### Networking

Create a small networking layer around `URLSession`:

-   Typed request and response handling.
-   `Codable` decoding.
-   HTTP status validation.
-   Cancellation support.
-   Clear error types.
-   Safe URL validation.
-   Unit-testable transport abstraction.

Do not add a remote backend in the first milestone. Keep repository
protocols ready for one.

### Image caching

Implement or adopt a maintained image-loading solution only after
checking its licensing, maintenance, and compatibility. If implementing
internally, isolate it behind a service and use bounded caching. Avoid
putting image networking logic directly inside list views.

------------------------------------------------------------------------

## 12. Testing strategy

### Unit tests

Test:

-   JSON decoding and seed-data validation.
-   Repository behavior.
-   Search matching and alternative names.
-   Combined filters.
-   Favorite persistence.
-   Relationship resolution.
-   Missing optional images and videos.
-   Error mapping.
-   View model loading, success, empty, and failure states.

### UI tests

Cover:

-   App launches and displays four tabs.
-   User can browse Gods & Angels.
-   User can browse Demons.
-   User can filter by tradition.
-   Search finds an entity by alternative name.
-   Tapping a card opens its detail screen.
-   User can add and remove a favorite.
-   Missing media does not break the detail screen.

Use deterministic fixtures and mock repositories. Tests must not rely on
live external APIs.

------------------------------------------------------------------------

## 13. Suggested project structure

``` text
DivineAtlas/
├── App/
│   ├── DivineAtlasApp.swift
│   ├── AppCoordinator.swift
│   └── DependencyContainer.swift
│
├── Core/
│   ├── DesignSystem/
│   ├── Networking/
│   ├── Persistence/
│   ├── ImageLoading/
│   ├── Routing/
│   └── Utilities/
│
├── Domain/
│   ├── Models/
│   ├── Repositories/
│   └── UseCases/
│
├── Data/
│   ├── Local/
│   ├── Remote/
│   ├── DTOs/
│   ├── Mappers/
│   ├── Repositories/
│   └── SeedData/
│
├── Features/
│   ├── GodsAndAngels/
│   ├── Demons/
│   ├── Religions/
│   ├── Discover/
│   ├── EntityDetail/
│   ├── Search/
│   └── Favorites/
│
├── Resources/
│   ├── Assets.xcassets/
│   └── SeedData/
│
└── Tests/
    ├── DivineAtlasTests/
    └── DivineAtlasUITests/
```

Adjust the structure as the implementation evolves; avoid creating empty
abstractions or folders without a concrete use.

------------------------------------------------------------------------

## 14. Development milestones

A focused MVP can be planned as a six-week effort. Actual duration
depends on content research, available artwork, testing, and developer
time.

### Milestone 1 --- Foundation

-   [ ] Create the Xcode project.
-   [ ] Set the iOS deployment target.
-   [ ] Configure Swift 6 and project settings.
-   [ ] Create app entry point and dependency container.
-   [ ] Define domain models and repository protocols.
-   [ ] Add design tokens and shared components.
-   [ ] Build the four-tab shell.

**Acceptance criteria:** App builds and launches; all four tabs
navigate; architecture has no direct network or persistence calls in
views.

### Milestone 2 --- Browse and detail UI

-   [ ] Gods & Angels listing.
-   [ ] Demons listing.
-   [ ] Religion listing and detail.
-   [ ] Entity detail screen.
-   [ ] Reusable cards and filter chips.
-   [ ] Search UI.
-   [ ] Loading, empty, and error states.

**Acceptance criteria:** Screens work using deterministic
in-memory/sample data and support navigation between list and detail.

### Milestone 3 --- Seed content

-   [ ] Define JSON schemas.
-   [ ] Add four religion records.
-   [ ] Curate initial 60--80 entity records over time.
-   [ ] Add source references.
-   [ ] Add media attribution metadata.
-   [ ] Add data validation and decoding tests.

**Acceptance criteria:** App loads seed content without hardcoded entity
arrays in views; invalid data produces useful diagnostics.

### Milestone 4 --- Persistence and media

-   [ ] Add SwiftData persistence.
-   [ ] Add favorites.
-   [ ] Add recently viewed if retained in scope.
-   [ ] Add image loading and bounded caching.
-   [ ] Add video link cards and external link handling.
-   [ ] Verify offline behavior.

**Acceptance criteria:** Favorites persist across launches; missing or
unavailable media does not break the app.

### Milestone 5 --- Quality

-   [ ] Unit tests for repositories and view models.
-   [ ] UI tests for critical journeys.
-   [ ] VoiceOver review.
-   [ ] Dynamic Type review.
-   [ ] Error and cancellation handling.
-   [ ] Performance and memory review.
-   [ ] Content and source review.

**Acceptance criteria:** Critical journeys pass automated tests; no
known high-impact accessibility or data-integrity issues remain.

### Milestone 6 --- Release preparation

-   [ ] App icon and screenshots.
-   [ ] App privacy disclosures.
-   [ ] Privacy policy and support information.
-   [ ] Content, copyright, and media-license review.
-   [ ] TestFlight build.
-   [ ] Device testing.
-   [ ] App Store metadata and submission preparation.

**Acceptance criteria:** A review-ready build exists with documented
content sources and media rights.

------------------------------------------------------------------------

## 15. Future roadmap

After the MVP, consider:

1.  Cross-tradition comparison pages with careful explanations of
    similarities and differences.
2.  Relationship explorer / graph.
3.  Historical timelines.
4.  More traditions, such as Buddhism, Sikhism, and selected ancient
    traditions.
5.  Multiple languages, with reviewed translations.
6.  Audio narration and educational stories.
7.  Curated editorial collections.
8.  AI-assisted question answering with citations, only after a reliable
    source corpus and safeguards exist.
9.  A content-management backend for editorial review and updates.

Do not build an AI answer feature until source attribution, factual
review, and handling of conflicting traditions are reliable.

------------------------------------------------------------------------

# 16. Instructions for Claude Code

Use this section as the implementation contract.

## Working rules

1.  Inspect the existing repository before changing files.
2.  If no project exists, create a standard SwiftUI iOS app structure.
3.  Do not overwrite existing user work without explaining the change.
4.  Work in small, compiling increments.
5.  Before each milestone, summarize the intended files and changes.
6.  After each milestone, build and run available tests.
7.  Fix compiler errors before proceeding.
8.  Use Swift 6 concurrency correctly; avoid unsafe shared mutable
    state.
9.  Mark UI-facing view models `@MainActor` where appropriate.
10. Use dependency injection; do not use global service singletons.
11. Keep views focused on presentation.
12. Keep sample data out of view files.
13. Use stable IDs for seed content.
14. Handle loading, empty, success, and error states.
15. Do not invent content, citations, media URLs, image licenses, or
    video links.
16. Do not scrape or redistribute copyrighted material.
17. Do not add third-party dependencies without explaining why they are
    needed.
18. Prefer native Apple frameworks where practical.
19. Add tests alongside meaningful domain and data changes.
20. Keep documentation updated when architecture or data contracts
    change.

## Implementation order

Implement in this order:

1.  Project setup and build configuration.
2.  Domain models and sample JSON.
3.  Repository protocols and local seed repository.
4.  Dependency container.
5.  Design system and tab navigation.
6.  Gods & Angels list.
7.  Demons list.
8.  Religions screens.
9.  Entity detail.
10. Search and filters.
11. Favorites and SwiftData.
12. Image and video presentation.
13. Tests and accessibility.
14. Release documentation.

Do not attempt all steps in one code-generation pass. Complete and
verify each logical increment.

## Required documentation

Maintain:

-   `README.md` --- project overview and setup.
-   `docs/ARCHITECTURE.md` --- architecture and dependency flow.
-   `docs/DATA_MODEL.md` --- entity schema and data rules.
-   `docs/CONTENT_GUIDELINES.md` --- research, religious context, and
    citation rules.
-   `docs/MEDIA_LICENSING.md` --- image/video sourcing and attribution
    rules.
-   `docs/ROADMAP.md` --- milestone status and future work.

## Definition of done

A feature is complete only when:

-   It builds successfully.
-   It handles loading, empty, and error states where relevant.
-   It follows the architecture and dependency-injection rules.
-   It is accessible.
-   Important logic has tests.
-   It does not introduce fabricated content or unlicensed media.
-   Its documentation is updated where needed.

------------------------------------------------------------------------

# 17. First task prompt for Claude Code

Start by inspecting the repository and then implement **Milestone 1
only**.

Your first response should:

1.  Report the existing project structure and relevant build
    configuration.
2.  Identify any constraints or missing decisions.
3.  Propose the exact files to create or modify.
4.  Implement the foundation, domain model skeleton, dependency
    container, design tokens, and four-tab navigation.
5.  Add a small deterministic sample dataset sufficient to demonstrate
    the tab shell.
6.  Build the project and run available tests.
7.  Summarize completed work, build/test results, and the next
    milestone.

Do not implement external APIs, AI features, or bulk religious content
in this first task. Keep the project compiling and the architecture
simple, extensible, and testable.

------------------------------------------------------------------------

# Addendum (2026-11-04) — Milestones 5a and 5b, before Milestone 6

*Added after Milestone 5. Sections 1–17 above are unchanged. Detailed task
lists are in `docs/ROADMAP.md`.*

## Milestone 5a — Entity images

Add licensed artwork for every entity where a suitable image exists.

-   Source: Wikimedia Commons, hand-mapped per entity, fetched by a
    script that records the licence, creator, source URL, and date, and
    approved by a person before shipping.
-   Accepted licences: public domain, CC0, CC BY, CC BY-SA.
-   Images are remote and cached by the app's bounded image pipeline,
    so they are available offline after first view.
-   Depiction policy: no images of Muhammad or of figures who are
    prophets only in Islam; calligraphy only for Allah; labelled
    historical manuscript art for Islamic angels and jinn.
-   Entities without a suitable image keep the labelled placeholder.

**Acceptance criteria:** every shipped image is licence-reviewed and
attributed in the app; validation rejects unlicensed or unreviewed
media; missing images never break a screen.

## Milestone 5b — YouTube videos per entity

Show a list of YouTube videos on each entity page, from a search on the
entity's name and tradition (e.g. "Vishnu Hinduism").

-   YouTube Data API v3 search with `safeSearch=strict`. Results are
    cached on the device for 24 hours to stay within quota.
-   Videos open in the YouTube app or Safari. There is no in-app
    playback or rehosting (see Section 7).
-   A "Search on YouTube" button is always available as a fallback when
    there is no API key, quota is exhausted, or the device is offline.
-   **Scope change:** live search results are unreviewed content, which
    Section 2 lists as out of scope. This is an accepted exception. The
    results are clearly labelled as unreviewed YouTube results, never
    stored as entity content, and kept separate from editor-curated
    video links.

**Acceptance criteria:** the video list loads only when scrolled into
view; quota, offline, and no-key states degrade to the fallback button;
tests use fixtures and never call the live API; the privacy policy
(Milestone 6) covers the YouTube API.
