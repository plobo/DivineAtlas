#!/usr/bin/env python3
"""Fetches licence metadata for curated Wikimedia Commons images and applies approved ones.

Workflow (standard library only):

    python3 scripts/fetch_commons_media.py --fetch    # query Commons, cache metadata
    python3 scripts/fetch_commons_media.py --review   # write curation/MEDIA_REVIEW.md
    # A person reviews MEDIA_REVIEW.md and sets "approved": true in curation/media.json
    python3 scripts/fetch_commons_media.py --apply    # write approved images into entities.json

A record may override the caption fields with "creator" and "dateText" when
Commons metadata is unsuitable for display (e.g. a photo's upload timestamp
instead of the artwork's date). Overrides must not change who is credited
for licensing purposes.

Only approved records whose licence is on the allowlist are applied. Entities
listed in curation/media.json that are not approved have their imageAssets
cleared, so un-approving an image removes it on the next --apply.
"""
import argparse
import datetime
import html
import json
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
CURATION = ROOT / "curation" / "media.json"
METADATA = ROOT / "curation" / "commons_metadata.json"
REVIEW = ROOT / "curation" / "MEDIA_REVIEW.md"
ENTITIES = ROOT / "DivineAtlas" / "Resources" / "SeedData" / "entities.json"

API = "https://commons.wikimedia.org/w/api.php"
# Wikimedia's User-Agent policy asks for a contact. TODO(Milestone 6): add the support address.
USER_AGENT = "DivineAtlasCuration/0.1 (iOS app content curation script; contact pending)"
THUMB_WIDTH = 1280
BATCH = 50

# Mirrors MediaLicense.isAccepted in DivineEntity.swift.
ACCEPTED_LICENSE = re.compile(r"^(public domain|pd-.+|cc0.*|cc by(-sa)? [234]\.[05]( [a-z]+)?)$", re.IGNORECASE)


def api_get(params, attempt=0):
    url = API + "?" + urllib.parse.urlencode({**params, "format": "json", "formatversion": 2})
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": USER_AGENT}), timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 429 and attempt < 5:
            time.sleep(int(error.headers.get("Retry-After") or 5 * (attempt + 1)))
            return api_get(params, attempt + 1)
        raise


def clean(value):
    """Strips HTML, Wikidata date annotations, and doubled labels from extmetadata values."""
    text = re.sub(r"<[^>]+>", " ", value or "")
    text = html.unescape(re.sub(r"\s+", " ", text)).strip()
    text = re.split(r"\s*date QS:", text)[0].strip()
    text = re.sub(r"\(\s*[^()]*\bQS:P\d+[^()]*\)", "", text).strip()     # "( … QS:P2348,Q12560 )" qualifiers
    text = re.sub(r"(\d) (st|nd|rd|th)\b", r"\1\2", text)                 # "19<sup>th</sup>" → "19th"
    doubled = re.fullmatch(r"(.+?)\s*\1", text)
    return doubled.group(1).strip() if doubled else text


def artwork_date(record, meta):
    """Curated override, else the Commons date unless it is an upload/photo timestamp."""
    if "dateText" in record:
        return record["dateText"]
    date = meta.get("date", "")
    if not date or re.match(r"^\d{4}-\d{2}-\d{2}", date) or date.lower() in {"unknown date", "unknown", "undated"}:
        return None
    return date


def load_json(path):
    return json.loads(path.read_text())


def fetch():
    records = load_json(CURATION)["records"]
    titles = [r["commonsFile"] for r in records if r.get("commonsFile")]
    metadata = {}
    for start in range(0, len(titles), BATCH):
        if start:
            time.sleep(1.5)
        data = api_get({
            "action": "query", "titles": "|".join(titles[start:start + BATCH]), "prop": "imageinfo",
            "iiprop": "url|size|extmetadata", "iiurlwidth": THUMB_WIDTH,
            "iiextmetadatafilter": "LicenseShortName|LicenseUrl|Artist|Credit|DateTimeOriginal|AttributionRequired|UsageTerms",
        })
        normalized = {n["to"]: n["from"] for n in data["query"].get("normalized", [])}
        for page in data["query"]["pages"]:
            requested = normalized.get(page["title"], page["title"])
            if page.get("missing") or not page.get("imageinfo"):
                metadata[requested] = {"missing": True}
                continue
            info = page["imageinfo"][0]
            md = {key: clean(value.get("value", "")) for key, value in info.get("extmetadata", {}).items()}
            metadata[requested] = {
                "url": info.get("thumburl") or info["url"],
                "sourceURL": info["descriptionurl"],
                "width": info.get("width"),
                "height": info.get("height"),
                "license": md.get("LicenseShortName", ""),
                "licenseURL": md.get("LicenseUrl", "").replace("http://", "https://", 1) or None,
                "artist": md.get("Artist", ""),
                "credit": md.get("Credit", ""),
                "date": md.get("DateTimeOriginal", ""),
                "attributionRequired": md.get("AttributionRequired", "") == "true",
            }
    METADATA.write_text(json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    missing = [t for t in titles if metadata.get(t, {}).get("missing", t not in metadata)]
    print(f"Fetched metadata for {len(titles) - len(missing)} of {len(titles)} files → {METADATA.relative_to(ROOT)}")
    for title in missing:
        print(f"  MISSING on Commons: {title}")
    return 1 if missing else 0


def status(record, metadata):
    if not record.get("commonsFile"):
        return "excluded"
    meta = metadata.get(record["commonsFile"])
    if meta is None:
        return "not fetched"
    if meta.get("missing"):
        return "missing on Commons"
    if not ACCEPTED_LICENSE.match(meta["license"]):
        return f"licence rejected ({meta['license']})"
    return "approved" if record.get("approved") else "awaiting approval"


def review():
    records = load_json(CURATION)["records"]
    metadata = load_json(METADATA) if METADATA.exists() else {}
    lines = [
        "# Media Review",
        "",
        "Generated by `scripts/fetch_commons_media.py --review`. Do not edit by hand.",
        "",
        "To approve an image, open its Commons page, check the image and its licence, then set",
        '`"approved": true` (and optionally `"approvedAt": "YYYY-MM-DD"`) for that entity in',
        "`curation/media.json`, and run `--apply`. ⚠️ marks items that need particular attention.",
        "",
        "| Entity | Status | Image | Licence | Artist · Date | Provenance / notes |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    counts = {}
    for record in records:
        state = status(record, metadata)
        counts[state.split(" (")[0]] = counts.get(state.split(" (")[0], 0) + 1
        if not record.get("commonsFile"):
            lines.append(f"| `{record['entityID']}` | excluded | — | — | — | {record['reason']} |")
            continue
        meta = metadata.get(record["commonsFile"], {})
        name = record["commonsFile"].removeprefix("File:")
        image = f"[{name[:48]}{'…' if len(name) > 48 else ''}]({meta['sourceURL']})" if meta.get("sourceURL") else name
        size = f" ({meta['width']}×{meta['height']})" if meta.get("width") else ""
        attention = f" ⚠️ {record['reviewerAttention']}" if record.get("reviewerAttention") else ""
        who = " · ".join(x for x in [record.get("creator") or meta.get("artist", ""), artwork_date(record, meta) or ""] if x)
        lines.append(
            f"| `{record['entityID']}` | {state} | {image}{size} | {meta.get('license', '')} | {who} | "
            f"{record['note']}{attention} |".replace("\n", " ")
        )
    summary = ", ".join(f"{count} {state}" for state, count in sorted(counts.items()))
    lines[3:3] = [f"**Summary:** {summary}.", ""]
    REVIEW.write_text("\n".join(lines) + "\n")
    print(f"Wrote {REVIEW.relative_to(ROOT)} — {summary}")
    return 0


def apply():
    records = load_json(CURATION)["records"]
    metadata = load_json(METADATA)
    document = load_json(ENTITIES)
    by_id = {e["id"]: e for e in document["records"]}
    applied, cleared = 0, 0
    today = datetime.date.today().isoformat()
    for record in records:
        entity = by_id[record["entityID"]]
        if status(record, metadata) != "approved":
            if entity.pop("imageAssets", None):
                cleared += 1
            continue
        meta = metadata[record["commonsFile"]]
        creator = record.get("creator") or meta["artist"] or "Unknown artist"
        date_text = artwork_date(record, meta)
        approved_at = record.get("approvedAt", today)
        asset = {
            "id": f"{record['entityID']}-image",
            "url": meta["url"],
            "altText": record["altText"],
            "creator": creator,
            "license": meta["license"],
            "sourceURL": meta["sourceURL"],
            "attributionText": f"{creator}, {meta['license']}, via Wikimedia Commons",
            "isArtisticReconstruction": record.get("isArtisticReconstruction", False),
            "reviewedAt": f"{approved_at}T00:00:00Z",
        }
        if meta.get("licenseURL"):
            asset["licenseURL"] = meta["licenseURL"]
        if date_text:
            asset["dateText"] = date_text
        entity["imageAssets"] = [asset]
        applied += 1
    ENTITIES.write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    print(f"Applied {applied} approved image(s); cleared {cleared} unapproved. Run the unit tests to validate.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--fetch", action="store_true")
    group.add_argument("--review", action="store_true")
    group.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    return fetch() if args.fetch else review() if args.review else apply()


if __name__ == "__main__":
    sys.exit(main())
