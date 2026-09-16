# Logo assets

Source: Figma Web-Assets, **Logo / Version=Default** (node `41:618` under Logo `41:619`).

| File | What |
| --- | --- |
| `buzzsprout-logo.svg` | Full Default wordmark (logo mark + “Buzzsprout”), as exported |
| `buzzsprout-wordmark.png` | Same lockup as a PNG preview |
| `buzzsprout-logo-mark.svg` | Logo mark only (bolt + leaves), for the intro frames |
| `frames.json` | Pre-rendered braille animation loaded by `Buzzsprout::Animation` |

Default is the source of truth for v0. Light/Dark variants can be added later without changing the loader.

Regenerate terminal frames (needs `rsvg-convert` or the PNG, plus Python Pillow):

```bash
script/generate_logo_frames
```
