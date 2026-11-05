# Content Guidelines

Divine Atlas is an educational reference. Accuracy, attribution, and respect
for each tradition take priority over coverage.

## Sourcing

1. Base claims on primary texts and authoritative tradition-specific sources.
   Record the exact work and passage (`Citation.locator`). Before an entry is
   marked `reviewed`, record the edition or translation in the source's
   `notes` or `publisher` fields.
2. Use academic or reputable reference works for historical context.
3. Wikipedia can help you find references, but it must never be the sole
   source for published content.
4. Do not scrape websites or copy copyrighted descriptions. Write original
   summaries.
5. **Never invent** scripture quotations, dates, origins, relationships,
   citations, or URLs. If something cannot be sourced, leave it out.
6. Prefer paraphrase over quotation. Add a quotation only after checking it
   against the specific translation, and cite that translation.

## Unreviewed external content (YouTube results)

The original plan excluded automated, unreviewed content. Live YouTube search
results (Milestone 5b) are a **deliberate, limited exception**:

- They appear only in their own "Videos on YouTube" section, under a visible
  notice that they are not reviewed and may not represent the tradition.
- They are never stored as entity content and never mixed with editor-curated
  "Recommended Videos".
- Searches use `safeSearch=strict` and topic-specific queries.

Results vary in quality. A spot check for "Vishnu Hinduism" returned
explainers, devotional recitations, and some sensational titles. Where an
entry needs dependable video, add curated `videoLinks` instead.

## Representation

- Do not flatten traditions into one taxonomy. Give each tradition's view of a
  figure its own `EntityClassification`, with a tradition-specific `label` and
  `explanation`.
- Do not label a figure a "demon" just because another tradition or a modern
  source does so. The `adversarial` group is assigned per tradition.
- Asura, rakshasa, jinn, Shaytan, demon, and fallen angel are **not**
  interchangeable. Explain each term in its own context.
- Where traditions share a name but differ in meaning, either keep separate
  classifications on one entry (e.g. Michael) or create separate entries
  linked by a `comparedWith` relationship (e.g. Satan and Iblis).
- Use neutral attribution: "In the Book of Daniel…", "In Vaishnava
  traditions…". Do not state contested theological claims as universal fact.
- Distinguish scripture, commentary, folklore, devotional belief, historical
  scholarship, and modern popular culture. Use `SourceType` and clear wording
  to do this.
- Note uncertainty or scholarly disagreement where it exists (e.g. whether
  Iblis was originally an angel or a jinn).
- Every religion record has an `interpretiveNote` stating that beliefs vary
  within the tradition.

## Editorial workflow

1. Add new entries with `reviewStatus: "draft"`. The app shows a visible
   "pending editorial review" notice on draft entries.
2. A reviewer checks every claim against its cited source and confirms the
   edition or translation.
3. On approval, set `reviewStatus: "reviewed"` and `lastReviewedAt`.
4. Run the test suite. The seed data must pass validation.
5. Tick the entry off in [CONTENT_REVIEW.md](CONTENT_REVIEW.md), which lists
   every classification and relationship with its citations.

## Depictions

Islam is largely aniconic, and Judaism avoids depicting God. The app's policy
(confirmed 2026-11-04):

| Entry | Policy |
| --- | --- |
| The Prophet Muhammad | **No image.** The labelled placeholder is the intended presentation. A unit test enforces this. |
| Figures who are prophets only in Islam | No figurative image. |
| Allah | Calligraphy only. |
| Islamic angels and jinn | Historical Islamic manuscript art (e.g. al-Qazwini's *Wonders of Creation*), labelled with its source and period. Never European art that frames them through another tradition. |
| Shared figures (Abraham, Moses, Elijah, Jesus) | Jewish or Christian historical art, captioned with the tradition it comes from. Avoid images that show these figures in an Islamic context. |
| God in Judaism | Non-figurative only (e.g. a manuscript showing the divine name), or the placeholder. |
| Scenes that include an Islamic prophet (e.g. Adam with Iblis) | Avoid. Choose a crop or a different work. |

Other rules:
- Prefer historical works from the tradition itself, such as Hindu
  devotional, Pahari, and Kalighat painting for Hindu figures, or Orthodox
  icons. Label later or outside interpretations with their source, e.g. 19th-century
  European demonology or a Victorian painting.
- Don't let an image contradict the entry. If a file's framing conflicts with
  the tradition's classification (e.g. "fallen angels" for Harut and Marut),
  choose another image or exclude it.
- Flag violent scenes, such as an avatar slaying an asura, in the review
  notes so the reviewer can confirm they are suitable.

## Current dataset (Milestone 3)

- **67 draft entries** across the four traditions: 90 tradition-specific
  classifications and 43 relationships, citing 23 sources.
- Every classification explanation cites at least one source. The validator
  enforces this.
- Wording is paraphrase. There are no direct quotations.
- **Spot-checked during drafting:** all 27 cited Qur'an verses were compared
  with the Sahih International translation, and selected Hebrew Bible and
  Talmud citations (Genesis 20:7, Malachi 3:23, Isaiah 34:14, Leviticus 16:8,
  Numbers 13:33, 2 Kings 1:2, Daniel 8:16, Bava Metzia 86b, Gittin 68a,
  Shabbat 151b, Sanhedrin 38b, Avodah Zarah 3b) were compared with the Sefaria
  English texts. Other citations (New Testament, Tobit, 1 Enoch, Hindu texts)
  are from the author's knowledge and **need verification**.
- Representation choices worth reviewer attention:
  - Satan, Lucifer, Beelzebub, Belial, and Azazel carry separate Jewish and
    Christian classifications, because the traditions read the same texts
    differently.
  - Jinn and Ifrit are grouped as `other`, not adversarial. Only Iblis and
    the shayatin appear on the Demons tab for Islam.
  - Mahabali (asura) and Vibhishana (rakshasa) are grouped as `other`, to show
    that these categories are not inherently evil.
  - Abaddon (Revelation) is grouped as `other`, because interpreters differ
    on whether the angel of the abyss serves God.
  - Prophets and patriarchs are grouped as `other` and appear under
    Religions and Search rather than in the Gods & Angels tab, except where a
    tradition regards the figure as divine (Jesus in Christianity).
  - There is no Jewish classification for Jesus and no Christian or Jewish
    classification for Muhammad. Representing how a tradition views a figure
    it does not venerate needs its own editorial decision.
