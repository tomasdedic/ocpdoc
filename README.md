# Massage salon page - Hugo + Bootstrap 5, EN and CZ

Static site in two languages. No theme, no npm build, no YAML: the words are markdown
files, Bootstrap 5.3.8 is copied into `static/`, and the interface labels are two small
translation files.

Published by GitHub Pages through `.github/workflows/deploy.yaml`.

## Run and build

```bash
hugo server          # http://localhost:1313  (Czech: http://localhost:1313/cs/)
hugo --gc --minify   # writes the site to public/
```

Needs Hugo 0.156 or newer. CI builds with Hugo 0.168.0 extended.

## Two languages

| | English | Czech |
|---|---|---|
| Address | `/` | `/cs/` |
| Content files | `content/name.md` | `content/name.cs.md` |
| Interface words | `i18n/en.toml` | `i18n/cs.toml` |
| Menu and site name | `[languages.en]` in `hugo.toml` | `[languages.cs]` in `hugo.toml` |

English is the default (`defaultContentLanguage = "en"`), so it lives at the root and Czech
under `/cs/`. A page appears in a language only if that language's file exists: delete
`content/hours.cs.md` and the hours card is gone from the Czech page only. The header switcher
(EN / CS) hides itself when a page has no translation, so keep both files of a pair if the
page is linked from the menu.

## Where the text lives

| What you see on the site | English | Czech |
|---|---|---|
| Hero heading, lead, "O studiu / The studio" text | `content/_index.md` | `content/_index.cs.md` |
| Three short reasons under the hero | `content/strip.md` | `content/strip.cs.md` |
| Services and prices, one block per treatment | `content/services.md` | `content/services.cs.md` |
| Opening hours, in the card next to the studio text | `content/hours.md` | `content/hours.cs.md` |
| Parking and payment text, plus the "How to book a visit" card title and note | `content/contact.md` | `content/contact.cs.md` |
| FAQ page | `content/faq.md` | `content/faq.cs.md` |
| News list page | `content/blog/_index.md` | `content/blog/_index.cs.md` |
| One news post | `content/blog/2026-10-horky-kamen/index.md` | same folder, `index.cs.md` |
| Phone, e-mail, address, map link, social, menu, site name | `hugo.toml` (`[params]` and `[languages]`) | |
| Call, Write an e-mail, Get directions, back link | `i18n/en.toml` | `i18n/cs.toml` |

`content/strip.*`, `content/services.*`, `content/hours.*` and `content/contact.*` have
`headless = true` in their front matter: they are parts of the top page and get no URL of
their own.

## How to write the content

Plain markdown, TOML front matter between two lines of `+++`. Most of it is ordinary prose:
paragraphs and bullet lists. Four things use a little structure because they are laid out as
boxes, not as text.

A service card:

```markdown
{{< cards >}}

{{< card title="Deep tissue" time="60 min" price="250 CZK" sub="Strong pressure for chronic tension." >}}

Slow, firm work on deep muscle layers and fascia.
This paragraph is the body of the card.

{{< /card >}}

{{< /cards >}}
```

A FAQ item:

```markdown
{{< folds >}}

{{< fold q="Can I cancel?" >}}

Free of charge up to 12 hours before.
{{< /fold >}}

{{< /folds >}}
```

Rules worth knowing:

- Keep one empty line between a shortcode line and its text, otherwise markdown swallows
  the paragraph.
- `title`, `time`, `price` and `sub` are the four card labels, `sub` is optional. Czech
  prices use `Kč`, English ones `CZK`.
- The strip under the hero is a normal bullet list, one bullet per column, and the bold
  words at the start of a bullet become its title.
- Opening hours are a bullet list too: `- Mon - Fri **09:00 - 20:00**`. Inside a card, bold
  becomes the right aligned value.
- `content/faq.md` has `type = "faq"`, which is why it uses `layouts/faq/single.html`
  (full width accordion). `layouts/_default/single.html` is the fallback for any new page:
  a narrow reading column, no template work needed.
- The booking card in the contact section reads its title and note from `bookTitle` and
  `bookNote` in that file's front matter. Clear both and the card disappears, buttons and
  all.
- The thin rules, the hours rows, the card look and the accordion colors come from
  `static/css/brand.css`, not from the text.

## Writing a news post

A post is a folder with markdown and its own pictures. Copy an existing folder:

```
content/blog/2026-10-horky-kamen/
  index.md        the English post
  index.cs.md     the Czech post, optional
  kamen.png       the picture shown on the card and at the top of the post
  studia.png      a second picture, used inside the text
```

```markdown
+++
title = "Hot stone is back on the menu"
date = 2026-10-05T09:00:00+02:00
image = "kamen.png"
preview = "Back on the menu for the winter: 75 minutes of warm basalt stones, 280 CZK."
+++

First paragraph, shown on the card when there is no `preview`.

{{< photo src="studia.png" alt="The room, lamps off, stones warming" >}}

Rest of the post.
```

- Newest first on the list, ten per page, then the Newer and Older links.
- `image` is the card picture and the banner at the top of the post. Without it the first
  picture found in the folder is used, and without any picture the card has no image.
- `preview` is the sentence on the card. Leave it out and put `<!--more-->` after your first
  paragraph instead; if you do neither, Hugo puts the whole post on the card.
- `{{< photo >}}` resizes and converts to WebP by itself: a 5 MB photo from a phone becomes a
  1200 px wide picture of a few hundred kilobytes. A plain `![alt](file.png)` also works, but
  sends the original file, so prefer the shortcode.
- A post in one language only is fine: it appears in that language and not in the other.
- Date format on the cards and posts comes from `dateFormat` in `i18n/en.toml` and
  `i18n/cs.toml`.
- The list is at `/blog/` and `/cs/blog/`, and there is a feed at `/blog/index.xml`.

## Add a section to the top page

1. New `content/mine.md` and `content/mine.cs.md`, both with `title` and `headless = true`
   in the front matter, then the text.
2. In `layouts/index.html`, copy one block such as the `{{ with site.GetPage "/hours" }}`
   section, change `/hours` to `/mine` and the `id` to match.
3. In `hugo.toml`, add a `[[languages.en.menu.main]]` and a `[[languages.cs.menu.main]]`
   entry with `url = "#mine"` and a `weight` that sets its place in the header. `weight`
   only orders the menu; the order on the page is the order of the blocks in
   `layouts/index.html`.

## Before launch, check these

1. Photos - replace `static/img/hero.svg` with a real photo (`hero.jpg`, about 900x640 px),
   `image = "img/hero.jpg"` is set in both `_index` files.
2. Real data - address, phone and e-mail in `[params]`, once, for both languages. The price
   numbers are placeholders from the Polish version and are far too low for Prague.
3. `params.legal` is not on the page: a registered business normally states its name and
   ID number somewhere, and a Czech site usually has an information obligation about
   personal data. Both were removed on request, so add them back if the friend is a
   registered provider.
4. Map - the "Get directions" link points at Mapy.com (`params.mapsUrl`) and loads nothing
   until a visitor clicks it. Putting an embed `src` into `params.mapEmbed` does load code
   from Mapy.com or Google for every visitor.
5. Contact details in `hugo.toml` are used by the header button, the hero buttons and the
   address card. Edit once, right everywhere. The footer holds only the Facebook and
   Instagram links, and disappears by itself when both of those params are empty.
6. Read the Czech aloud. It was written by a machine; a native speaker will change endings
   and word order, especially the gendered forms ("řekněte", "zeptejte se" are neutral on
   purpose).

## Deploy

Push to `master`. The workflow installs Hugo 0.168.0 extended, runs `hugo --gc --minify
--baseURL <pages url>/` and uploads `public` to Pages. Pages keeps its own domain setting,
so the address in `hugo.toml` is only used for local builds.

## Design

`static/css/brand.css` holds every choice: colors, fonts, button, section spacing, the
markdown rhythm, the hours rows and the accordion colors. It only sets Bootstrap variables,
so Bootstrap classes still work everywhere.

## Links to a phone number

Phone links use `{{ . | safeURL }}`. Without it Go's template sanitizer rejects the `tel:`
scheme and quietly rewrites every phone link to `href="#ZgotmplZ"`. Keep the filter when you
add a new phone link.
