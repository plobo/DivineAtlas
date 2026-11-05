# Media Licensing

## Images

- **Never** take images from general web image search. The only source is
  Wikimedia Commons, through the curation workflow below.
- **Accepted licences:** public domain (including `PD-*` tags), CC0, and
  Creative Commons **BY** and **BY-SA** 2.0–4.0. NonCommercial (NC),
  NoDerivatives (ND), GFDL-only, and "No restrictions" Flickr tags are
  rejected. `MediaLicense.isAccepted` (app) and the fetch script enforce the
  same list.
- Every `MediaAsset` records:
  - `url` (a Commons thumbnail, 1280 px)
  - `altText`
  - `license`, plus `licenseURL` when there is one
  - `sourceURL` (the Commons file page)
  - `creator` and/or `attributionText`
  - `dateText`
  - **`reviewedAt`**: the date a person approved the image and its licence.
    Licence review is separate from the entry's content review.
- **The seed validator rejects assets that:**
  - are missing a licence, source, or credit
  - use a licence that isn't accepted
  - have not been reviewed
  - use a non-HTTPS URL
- Attribution appears directly under the hero image as a credit line
  ("Artist, date · Licence"). Tapping it opens the full credit sheet, with links
  to the licence and the Commons file page. This satisfies the attribution
  requirement of CC BY and BY-SA.
- Set `isArtisticReconstruction: true` for modern reconstructions, so the UI
  labels them as artistic interpretations.
- The app does not depend on remote URLs staying available. A labelled
  placeholder is shown whenever artwork is missing or fails to load. Viewed
  images stay in a bounded on-device cache (150 MB, least-recently-used
  eviction) and work offline.
- App requests send a descriptive `User-Agent`, as Wikimedia's policy requires.
  **Milestone 6:** replace the placeholder contact in `HTTPClient.userAgent`
  and in `scripts/fetch_commons_media.py`.

### Curation workflow

```text
curation/media.json            hand-mapped Commons file per entity (or an exclusion + reason)
        │  python3 scripts/fetch_commons_media.py --fetch
        ▼
curation/commons_metadata.json licence, artist, date, URLs from the Commons API (cached)
        │  python3 scripts/fetch_commons_media.py --review
        ▼
curation/MEDIA_REVIEW.md       table for a human reviewer
        │  reviewer sets "approved": true (and optionally "approvedAt") in media.json
        │  python3 scripts/fetch_commons_media.py --apply
        ▼
entities.json imageAssets      only approved, allowlisted images; unapproved ones are removed
```

- **Why not automatic?** Name lookups on Wikidata are unreliable ("Michael"
  matched a given name, "Metatron" a video game), and file titles can carry
  framing a tradition does not share. Every image is chosen and approved by a
  person.
- Records may override the caption `creator` or `dateText` when Commons
  metadata is unsuitable for display, for example a photo's upload timestamp
  instead of the artwork's date. Overrides must not change who is credited
  under the licence: for photographs of old works under CC BY-SA, the
  photographer must stay credited.
- After `--apply`, run the unit tests. The validator re-checks every asset.

## Videos

### Curated videos ("Recommended Videos")

- Curate educational videos by hand. Do not add them automatically without
  review.
- Store `title`, `provider`, `channelName`, original `url`, `thumbnailURL`,
  and `reviewedAt`.
- Open the original URL in the system browser or the provider's own app. Do
  not download or rehost video.
- Handle removed, private, or region-restricted videos gracefully, and hide
  the video section when an entry has no links.

### Live YouTube results ("Videos on YouTube")

Compliance with the YouTube API Services Terms and Developer Policies:

- **Display only:** show YouTube's own title, channel, and thumbnail without
  modification. Label each row "YouTube". Videos open on YouTube (app or
  Safari). Nothing is downloaded, embedded, rehosted, or cached as video.
- **Stored API data:** search results (metadata only) are cached on the
  device for 24 hours and never served after 30 days.
- **Not entity content:** results are never written into the dataset and are
  labelled "Not reviewed by Divine Atlas".
- **Safety:** `safeSearch=strict` plus topic-specific queries.
- **Keys:** use a key restricted to iOS apps with the app's bundle ID and to
  the YouTube Data API only. The current development key is shared with
  another project; replace it before release.
- **Privacy (Milestone 6):** searches send the query and the device's IP
  address to Google. The privacy policy must disclose YouTube API use and link
  the Google Privacy Policy, and the App Store privacy details must be
  reviewed accordingly.

## Religious sensitivities

See [CONTENT_GUIDELINES → Depictions](CONTENT_GUIDELINES.md#depictions).
In short:
- No image of the Prophet Muhammad (enforced by a unit test).
- Calligraphy only for Allah.
- Labelled historical manuscript art for Islamic angels and jinn.
- Shared figures may use Jewish or Christian art, captioned with the
  tradition it comes from.

## Current status (Milestone 5a)

- **56 of 67 entries ship with artwork** (approved 2026-11-04). Each is
  licence-reviewed, on an accepted licence, and credited under the image.
- **4 candidates are held** (Metatron, God in Judaism, Ravana, Shurpanakha).
  See `heldReason` in `curation/media.json`. To ship one, set
  `"approved": true` and run `--apply`.
- **7 entries are excluded** and keep the placeholder; the reasons are in
  `curation/MEDIA_REVIEW.md`.

## Release checklist (Milestone 6)

- [ ] Every image has a verified licence, creator, source URL, and attribution.
- [ ] Every video link has been reviewed and still resolves.
- [ ] Attribution text renders correctly in the app.
- [ ] The User-Agent contact is filled in.
