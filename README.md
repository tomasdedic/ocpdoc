# Massage salon page - Hugo + Bootstrap 5

Published by GitHub Pages through `.github/workflows/deploy.yaml`.

Static one-page site. Bootstrap 5.3.8 CSS and JS are vendored in `static/`, so there is
no npm build, no CDN dependency and nothing to install except Hugo (extended, 0.156 or newer).

## Run and build

```bash
hugo server          # http://localhost:1313
hugo --gc --minify   # writes the site to public/
```

## Where the owner edits text

| What | File |
|---|---|
| Name, phone, e-mail, address, hours, hero text | `hugo.toml` (`[params]`) |
| Treatments with price and duration | `data/services.yaml` |
| Short "why us" row under the hero | `data/why.yaml` |
| FAQ answers, shown on `/faq/` | `data/faq.yaml` |
| "About the studio" paragraph | `content/_index.md` |
| FAQ page text above the list | `content/faq.md` |
| Privacy page | `content/privacy.md` |

Section links (Services, About, Contact) live in `[menu.main]` in `hugo.toml`. The FAQ
link comes from the front matter of `content/faq.md`, because FAQ is a separate page, not a
section of the top page.

Empty value means the part is hidden. Clear `mapEmbed` and there is no map. Clear
`formAction` and the contact form is replaced by a "call or write" card.

## Before launch, check these

1. `baseURL` in `hugo.toml` - set the real domain.
2. Photos - replace `static/img/hero.svg` with a real photo (`hero.jpg`, about 900x640 px)
   and change `params.hero.image` to `img/hero.jpg`.
3. Czech text - set `locale = "cs"` in `hugo.toml`, translate the content files and put
   Czech diacritics back into the address, for example `Vodickova` -> `Vodičkova`.
4. Contact form - the page asks visitors to call or write. A form appears only if
   `params.formAction` is set, with Formspree, Basin or Netlify Forms as the receiver.
   A booking-system button can be added later in `layouts/index.html` and
   `layouts/partials/nav.html`, one guarded line each.
5. Map - the "Get directions" link points at Mapy.com (`params.mapsUrl`). To show a map on
   the page, take the embed `src` URL from Mapy.com or Google Maps and put it in
   `params.mapEmbed`. An embedded map loads code from someone else, so say so on the
   privacy page.

## Deploy

Push to `master`. The workflow installs Hugo 0.168.0 extended, runs `hugo --gc --minify
--baseURL <pages url>/` and uploads `public` to Pages. The Pages site keeps its own domain
setting, so the address in `hugo.toml` is only used for local builds. Building by hand needs
Hugo 0.156 or newer, because the templates use `hugo.Data`.

## Design

Phone links use `{{ . | safeURL }}`. Without it Go's template sanitizer rejects the `tel:`
scheme and quietly rewrites every phone link to `href="#ZgotmplZ"`. Keep the filter when you
add a new phone link.

`static/css/brand.css` holds every choice: colors, fonts, button, section spacing.
It only sets Bootstrap variables, so Bootstrap classes still work everywhere.

## Not a theme, on purpose

No Hugo theme is a good fit for a small salon. The maintained Bootstrap-based themes
(hugo-universal-theme, sicily-hugo-theme, hugo-bootstrap-theme) all force their own
content types, blog and page structure on you. This project is about 10 template lines
per section and can be read in one sitting.
