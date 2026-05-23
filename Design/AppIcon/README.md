# App Icon

This directory contains the editable source for the LanguageSwitchingDemo app icon.

## Concept

- Subject: language globe plus bidirectional refresh arrows.
- Meaning: app-local language switching, LTR/RTL direction changes, and live UI refresh.
- Style: Apple-like rounded geometry, high contrast, restrained glass highlight.
- Avoided: readable text, flags, country-specific symbols, and complex detail that fails at small sizes.

## Color Tokens

| Variant | Background | Globe | Arrows |
| --- | --- | --- | --- |
| Light | `#7DE3FF -> #0A84FF -> #065DD8` | white glass with blue grid | white / ice cyan |
| Dark | `#12314A -> #062B4E -> #020918` | cyan glass | cyan / white |
| Tinted | grayscale only | grayscale silhouette | grayscale silhouette |

## Exported Assets

The Xcode asset catalog uses single-size 1024 px iOS app icons:

- `AppIcon-Light.png`
- `AppIcon-Dark.png`
- `AppIcon-Tinted.png`

The tinted asset is intentionally grayscale so iOS 26 can apply the user's selected theme color.
