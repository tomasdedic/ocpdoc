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
| Headline and lead at the top, "The studio" text and its bullet list | `content/_index.md` |
| "Services and prices", one `##` block per treatment | `content/services.md` |
| Opening hours, parking, payment, next to the address | `content/contact.md` |
| FAQ page | `content/faq.md` |
| Privacy page | `content/privacy.md` |
| Phone, e-mail, address, map link, social links, menu | `hugo.toml` |

`content/services.md` and `content/contact.md` have `headless = true` in their front
matter. They are parts of the top page and get no URL of their own.

## How to write the content

Plain markdown. Front matter, between two lines of `+++`, holds only the few values the
design needs:

```markdown
+++
title = "Services and prices"
headless = true
+++

## Deep tissue - 60 min - 250 zl

Slow, firm work on deep muscle layers and fascia.
```

- `title` is the heading the section shows.
- `## Name - duration - price` is one service. The price is part of the line on purpose,
  so nothing has to be kept in sync in two places.
- `content/faq.md` is a real page at `/faq/`. Its menu entry comes from the `[menu.main]`
  block in its own front matter, so deleting the file deletes the link.
- Extra markdown pages you add on your own are published by `layouts/_default/single.html`
  with no template work.

## Add a section to the top page

Three steps, no YAML:

1. New `content/mine.md` with `title` and `headless = true` in the front matter, then the text.
2. In `layouts/index.html`, copy one block such as the `{{ with site.GetPage "/services" }}`
   section, change `/services` to `/mine` and `id="services"` to `id="mine"`.
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
5. Contact details in `hugo.toml` are shown in the header, the hero, the contact section
   and the footer. Edit them once, they are right everywhere.

## Design

`static/css/brand.css` holds every choice: colors, fonts, button, section spacing, and the
`.prose` rules that give markdown its rhythm. It only sets Bootstrap variables, so
Bootstrap classes still work everywhere.

## Links to a phone number

Phone links use `{{ . | safeURL }}`. Without it Go's template sanitizer rejects the `tel:`
scheme and quietly rewrites every phone link to `href="#ZgotmplZ"`. Keep the filter when you
add a new phone link.
