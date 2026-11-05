# Data Model

Swift definitions: `DivineAtlas/Domain/Models`. Seed files:
`DivineAtlas/Resources/SeedData`.

## Seed file envelope

Every seed file has the same structure:

```json
{ "schemaVersion": 1, "records": [ ... ] }
```

The loader rejects any other `schemaVersion`. Bump the version whenever a change
would break older readers.

JSON Schema files for editor tooling (autocomplete and inline errors in VS
Code and similar editors) live in [`docs/schema/`](schema/). Run
`scripts/validate_seed_schema.py` to check the seed files against them. The
schemas cover shape and formats. `SeedDataValidator` remains the authoritative
check and also enforces referential integrity.

| File | Record type |
| --- | --- |
| `religions.json` | `Religion` |
| `entities.json` | `DivineEntity` |
| `sources.json` | `SourceReference` |

There is no `media.json` yet. Media metadata is stored on each entity in
`imageAssets` until a shared media library is needed.

## Core types

### `DivineEntity`

| Field | Type | Notes |
| --- | --- | --- |
| `id` | String | Stable kebab-case ID; never reuse or rename |
| `name` | String | Primary display name |
| `alternativeNames` | [String] | Spellings and transliterations; searchable. Optional, defaults to `[]`. |
| `summary` | String | One or two neutral sentences |
| `classifications` | [EntityClassification] | At least one |
| `imageAssets` | [MediaAsset] | Optional |
| `sections` | [EntityContentSection] | Optional |
| `relationships` | [EntityRelationship] | Optional |
| `videoLinks` | [VideoLink] | Optional |
| `isFeatured` | Bool | Optional, default `false` |
| `reviewStatus` | `draft` \| `reviewed` | Optional, default `draft` |
| `lastReviewedAt` | ISO-8601 date | Optional |
| `addedAt` | ISO-8601 date | When the entry was added to the dataset. Drives "Recently added" sorting and the Discover section. Undated entries sort last. |

`traditionIDs` is **derived** from `classifications`, not stored. This prevents
the two from disagreeing.

### `EntityClassification` (one per tradition view of a figure)

| Field | Notes |
| --- | --- |
| `traditionID` | `christianity` \| `judaism` \| `islam` \| `hinduism` |
| `category` | Coarse `EntityCategory`, used for filtering and grouping |
| `group` | `divineAndCelestial` \| `adversarial` \| `other`. Decides which tab the figure appears in **for this tradition**. |
| `label` | Tradition-specific wording, shown in preference to the category |
| `explanation` | Optional context |
| `citations` | [Citation] |

Why `group` is stored separately from `category`: categories do not map neatly
to "good" or "evil". The Qur'an describes believing and disbelieving jinn, and
*asura* has different meanings in Vedic and Puranic texts. A figure can also be
understood differently by different traditions. For example, *ha-satan* in Job
is classified `other` under Judaism, while Satan is `adversarial` under
Christianity. Filters require group, tradition, and category to match **the same
classification**, so filtering the Demons tab to Judaism does not show Satan.

### `Citation`

`{ "sourceID": "src-tanakh", "locator": "Daniel 10:13" }`. `locator` is
optional and narrows the citation to a passage. Citations replace the plan's
`sourceIDs: [String]`, so a single source record (e.g. the Tanakh) can be cited
at many passages.

### Other types

- `EntityContentSection`: `id`, `title`, `body`, `kind` (`overview`, `history`,
  `roles`, `symbols`, `texts`, `interpretations`, `other`), `citations`.
- `EntityRelationship`: `id`, `relatedEntityID`, `relationshipType` (free text
  for now), **required** `explanation`, `citations`.
- `MediaAsset`: `id`, `url`, **required** `altText`, **required** `license`,
  **required** `sourceURL`, `creator` and/or `attributionText` (at least one is
  required), `isArtisticReconstruction`.
- `VideoLink`: `id`, `title`, `url`, `provider`, `channelName`, `thumbnailURL`,
  `reviewedAt`.
- `SourceReference`: `id`, `title`, `author`, `publisher`, `publicationDate`,
  `url`, `sourceType` (`primaryText`, `commentary`, `scholarship`,
  `referenceWork`, `folklore`, `other`), `notes`.
- `Religion`: `id` (TraditionID), `name`, `summary`, `introduction`,
  `interpretiveNote`, `sourceIDs`.

Unknown enum values (e.g. a misspelled category) fail decoding, and the error
names the file and JSON path.

## Validation rules (`SeedDataValidator`)

Loading fails with **every** issue listed, not just the first:

- Duplicate IDs for religions, entities, or sources.
- Blank names, summaries, introductions, classification labels, relationship
  explanations, or media alt text.
- Entities with no classifications.
- Classifications that reference a tradition with no religion record.
- Relationships that point to an unknown entity or to the entity itself.
- Citations that reference an unknown source.
- Non-HTTPS URLs on sources, media, or videos.
- **Uncited claims:** a classification with an `explanation` but no citations.
- Media without a licence, source URL, or creator/attribution text.
- Videos without a title or provider.
- Duplicate relationship IDs within an entry.

The unit test suite loads the real bundled seed data on every run, so invalid
content fails CI.

## Citation conventions

Each source's `notes` field records how its locators are numbered:

| Source | Locator format | Note |
| --- | --- | --- |
| Tanakh | `Book chapter:verse` | Hebrew (Masoretic) numbering, e.g. Malachi 3:23, Job 40:25–41:26 |
| Old Testament | `Book chapter:verse` | English Bible numbering, e.g. Malachi 4:5. Used for Christian classifications. |
| Qur'an | `surah:ayah` | Standard Cairo edition |
| Babylonian Talmud | `Tractate folio` | e.g. Bava Metzia 86b |
| Rigveda | `mandala.hymn[.verse]` | e.g. 1.32, 2.41.16 |
| Puranas | `book.chapter` or a named section | e.g. Bhagavata Purana 7.8; Shiva Purana Rudra Samhita, Kumara Khanda |
| Epics | Book name | e.g. Yuddha Kanda, Adi Parva |
| Hadith collections | Book (kitab) name | Hadith numbering varies between editions |

Hebrew Bible passages are cited from `src-tanakh` in Jewish classifications and
from `src-old-testament` in Christian ones, because their numbering can differ.
