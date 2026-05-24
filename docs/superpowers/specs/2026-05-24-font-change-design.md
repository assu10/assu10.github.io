# Font Change Design — IBM Plex Sans

**Date:** 2026-05-24

## Goal

Replace existing Noto Sans KR / Lato font combination with IBM Plex Sans + IBM Plex Sans KR for a modern, technical-document feel suitable for a developer blog.

## Font Selection

- **IBM Plex Sans KR** — Korean text, headings, body
- **IBM Plex Sans** — English/Latin text fallback, menus

Both fonts are available on Google Fonts.

## Changes

### `_config.yml`

| Key | Before | After |
|-----|--------|-------|
| `font_heading` | `'Noto Sans KR', 'sans-serif'` | `'IBM Plex Sans KR', 'IBM Plex Sans', sans-serif` |
| `font` | `'Noto Sans KR', 'sans-serif'` | `'IBM Plex Sans KR', 'IBM Plex Sans', sans-serif` |
| `google_fonts` | `Lato` | `IBM+Plex+Sans+KR:300,400,500,700\|IBM+Plex+Sans:300,400,500,600,700` |

## Area Coverage

- Left menu: IBM Plex Sans (Latin-optimized)
- Headings (h1–h6): IBM Plex Sans KR 700
- Body text: IBM Plex Sans KR 400
- Korean + English mixed: KR variant handles Korean, Sans handles Latin
