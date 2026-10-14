# Massage salon page - Hugo + Bootstrap 5

Static site. No theme, no npm build, no YAML: every word visitors read is a markdown
file in `content/`, and Bootstrap 5.3.8 is copied into `static/`.

Published by GitHub Pages through `.github/workflows/deploy.yaml`.

## Run and build

```bash
hugo server          # http://localhost:1313
hugo --gc --minify   # writes the site to public/
```

Needs Hugo 0.156 or newer (the templates use `hugo` accessors and TOML front matter is
standard). Built by CI with Hugo 0.168.0 extended.

## Where the text lives

| What you see on the site | File |
|---|---|
| Headline and lead at the top, "The studio" text | `content/_index.md` |
| Three short reasons under the hero | `content/strip.md` |
| "Services and prices", one block per treatment | `content/services.md` |
| Opening hours, one line per day range, in the card next to "The studio" | `content/hours.md` |
| Parking, payment, how calls are answered, next to the address | `content/contact.md` |
| FAQ page | `content/faq.md` |
| Privacy page | `content/privacy.md` |
| The address card, header phone button, hero buttons, footer links, menu | `hugo.toml` |

`content/strip.md`, `content/services.md`, `content/hours.md` and `content/contact.md`
have `headless = true`
in their front matter. They are parts of the top page and get no URL of their own.

## How to write the content

Plain markdown, TOML front matter between two lines of `+++`. Most of it is ordinary
prose: paragraphs and bullet lists. Two things need a little structure because they are
laid out as boxes, not as text: a service and a FAQ question. They use shortcodes, written
inside the same markdown file, so nothing has to be kept in sync in a second place.

```markdown
{{< cards >}}

{{< card title="Deep tissue" time="60 min" price="250 CZK" sub="Strong pressure for chronic tension." >}}

Slow, firm work on deep muscle layers and fascia.
This paragraph is the body of the card.

{{< /card >}}

{{< /cards >}}
```

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
- `title`, `time`, `price` and `sub` are the four card labels. `sub` is optional.
- The strip under the hero is a normal bullet list, one bullet per box, and the bold words
  at the start of a bullet become its title.
- Opening hours are a bullet list too, one line per day range, with the hours in bold:
  `- Mon - Fri **09:00 - 20:00**`. Inside a card, bold becomes the right-aligned value. `layouts/shortcodes/` holds all four shortcode
  files, each of them between 3 and 12 lines.
- `content/faq.md` has `type = "faq"`, which is why it uses `layouts/faq/single.html`
  (full width accordion) instead of `layouts/_default/single.html` (the narrow reading
  column the privacy page uses).
- The thin rules, the hours rows, the card look and the accordion colors come from
  `static/css/brand.css`, not from the text.

## Add a section to the top page

Three steps, no YAML:

1. New `content/mine.md` with `title` and `headless = true` in the front matter, then the text.
2. In `layouts/index.html`, copy one block such as the `{{ with site.GetPage "/contact" }}`
   section, change `/contact` to `/mine` and `id="contact"` to `id="mine"`.
3. In `hugo.toml`, add a `[menu.main]` entry with `url = "#mine"` and a `weight` that sets
   its place in the header. `weight` only orders the menu; the order on the page is the
   order of the blocks in `layouts/index.html`.

## Before launch, check these

1. `baseURL` in `hugo.toml` - the Pages workflow replaces it with the real site URL anyway.
2. Photos - replace `static/img/hero.svg` with a real photo (`hero.jpg`, about 900x640 px)
   and set `image = "img/hero.jpg"` in `content/_index.md`.
3. Czech text - set `locale = "cs"` in `hugo.toml`, translate the markdown files and put
   Czech diacritics back into the address, for example `Vodickova` -> `Vodičkova`.
4. Map - the "Get directions" link points at Mapy.com (`params.mapsUrl`). To show a map on
   the page, take the embed `src` URL from Mapy.com or Google Maps and put it in
   `params.mapEmbed`. An embedded map loads code from someone else, so say so on the
   privacy page.
5. Contact details in `hugo.toml` are shown in the header button, the hero buttons, the
   address card and the footer. Edit them once, they are right everywhere. The phone is
   deliberately shown once per section, not twice.

## Design

`static/css/brand.css` holds every choice: colors, fonts, button, section spacing, and the
`.prose` rules that give markdown its rhythm. It only sets Bootstrap variables, so
Bootstrap classes still work everywhere.

## Links to a phone number

Phone links use `{{ . | safeURL }}`. Without it Go's template sanitizer rejects the `tel:`
scheme and quietly rewrites every phone link to `href="#ZgotmplZ"`. Keep the filter when you
add a new phone link.
