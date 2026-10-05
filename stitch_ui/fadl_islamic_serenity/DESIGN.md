---
name: Fadl Islamic Serenity
colors:
  surface: '#f1fcf7'
  surface-dim: '#d1ddd8'
  surface-bright: '#f1fcf7'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#ebf6f1'
  surface-container: '#e5f0eb'
  surface-container-high: '#dfebe6'
  surface-container-highest: '#dae5e0'
  on-surface: '#141e1b'
  on-surface-variant: '#404945'
  inverse-surface: '#28332f'
  inverse-on-surface: '#e8f3ee'
  outline: '#717975'
  outline-variant: '#c0c8c3'
  surface-tint: '#3b6758'
  primary: '#013428'
  on-primary: '#ffffff'
  primary-container: '#1e4b3e'
  on-primary-container: '#8cbaa9'
  inverse-primary: '#a1d0bf'
  secondary: '#176b4d'
  on-secondary: '#ffffff'
  secondary-container: '#a4f3cd'
  on-secondary-container: '#207153'
  tertiary: '#3b2b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#564000'
  on-tertiary-container: '#cdac61'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#bdeddb'
  primary-fixed-dim: '#a1d0bf'
  on-primary-fixed: '#002018'
  on-primary-fixed-variant: '#224e41'
  secondary-fixed: '#a4f3cd'
  secondary-fixed-dim: '#88d6b2'
  on-secondary-fixed: '#002115'
  on-secondary-fixed-variant: '#005138'
  tertiary-fixed: '#ffdf99'
  tertiary-fixed-dim: '#e5c375'
  on-tertiary-fixed: '#251a00'
  on-tertiary-fixed-variant: '#5a4300'
  background: '#f1fcf7'
  on-background: '#141e1b'
  surface-variant: '#dae5e0'
typography:
  headline-xl:
    fontFamily: Noto Serif
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 48px
  headline-lg:
    fontFamily: Noto Serif
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 38px
  headline-md:
    fontFamily: Noto Serif
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 30px
  headline-sm:
    fontFamily: Noto Serif
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 26px
  scripture-lg:
    fontFamily: Noto Serif
    fontSize: 24px
    fontWeight: '500'
    lineHeight: 48px
  scripture-md:
    fontFamily: Noto Serif
    fontSize: 19px
    fontWeight: '400'
    lineHeight: 38px
  body-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 16px
    fontWeight: '500'
    lineHeight: 26px
  body-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 22px
  body-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 10px
    fontWeight: '600'
    lineHeight: 14px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  gutter-mobile: 0.75rem
  margin: 1.25rem
  margin-mobile: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.875rem
  space-lg: 1.25rem
  space-xl: 2rem
---

## Brand & Style

The design system embodies spiritual tranquility, reverent minimalism, and timeless Islamic warmth. It is crafted primarily for Muslim users seeking daily devotion, Quranic recitation, Athkar, prayer tracking, and dedicated charity/remembrance prayers (Sadaqah Jariyah). 

The emotional response should evoke serenity, inner peace, dignity, and visual purity. The interface avoids clutter, aggressive contrasts, and jarring animations. Instead, it relies on modern organic minimalism infused with subtle Arabesque warmth, delicate Islamic arches, fine hairline geometry, and generous breathable margins. 

Key attributes:
- **RTL-First Architecture:** Tailored fundamentally for seamless Arabic reading and right-to-left layout flows, with balanced optical alignment for Arabic ligatures.
- **Spiritual Comfort:** Off-white parched parchment foundations contrasted with deep forest emeralds and warm sand-gold accents.
- **Dignified Typography:** Respectful separation between classical scripture (Naskh/Amiri styling for Quran and Hadith) and contemporary legible typography for navigational labels and metric data.

## Colors

The palette draws inspiration from sacred sanctuaries, ancient paper manuscripts, deep oasis greenery, and desert dawn warmth. 

- **Primary (`#1E4B3E`):** Deep Forest Emerald. Serves as the core visual anchor, used for primary navigation headers, Quranic cards, focal hero cards, and high-emphasis devotional containers.
- **Secondary (`#2E7D5E`):** Vibrant Sage / Jade Green. Used for active interaction states, success badges, primary call-to-action buttons, daily prayer progress rings, and active audio player states.
- **Tertiary (`#C7A75C`):** Desert Sand Gold. Reserved for reverent accents, active prayer time highlights, surah frame borders, bookmark ribbons, and decorative Quranic dividers. A lighter tint (`#E6C687`) provides subtle ambient gradients and glowing indicators.
- **Neutral Surface & Canvas:** The background avoids stark digital white, utilizing warm parchment tones: Base Canvas (`#F9FAF8`), Elevated Container Surface (`#FFFFFF`), and Muted Sub-surface (`#F4F6F0`).
- **Typography & Neutral Text (`#1A2421`):** Deep charcoal-slate with an organic green undertone, providing high legibility and soft contrast against parchment backgrounds without the eye fatigue caused by pure black.
- **Dark Mode Extension:** When active, the canvas transitions to obsidian green (`#0F1B17`), with elevated surfaces at deep cypress (`#152822`) and text rendered in soft ivory (`#EAEFEA`).

## Typography

The typography strategy unites reverent classical Arabic calligraphic forms with balanced contemporary UI geometry:

1. **Scriptural & Display Typography (Mapped to Noto Serif / Amiri / Noto Naskh Arabic):**
   - Applied to Surah titles, Ayah text, daily Hadith cards, and commemorative headers.
   - Arabic scripture demands vertical space; Ayah lines feature a generous line-height multiplier (1.8x to 2.0x) to accommodate Tashkeel (diacritics), Sukūn, and Waqf marks without clipping.

2. **Interface & Operational Typography (Mapped to Plus Jakarta Sans / Tajawal / Cairo):**
   - Applied to navigation labels, action buttons, counters, timestamps, settings, and search fields.
   - Low stroke contrast and open counters ensure legibility even at compact mobile sizes (11px–13px) in prayer times tables and index lists.

3. **Numerals:**
   - Both Eastern Arabic numerals (١، ٢، ٣) and standard Arabic-Indic numerals are supported contextually, switching smoothly between Surah verse numbers and countdown timers.

## Layout & Spacing

The layout model is anchored on an 8-point rhythmic grid with 4-point micro-adjustments for Arabic diacritic balance.

- **Mobile Canvas (Primary Target):** Single-column layout with `margin-mobile: 1rem` and internal component padding of `space-md` (14px) to `space-lg` (20px). Horizontal swipe carousels utilize edge-bleed with trailing padding to ensure continuous content discovery.
- **Tablet / Large Screen Layout:** Dual-pane split hierarchy (Quran text on leading right pane, translation/tafsir on trailing left pane in RTL mode) conforming to a 6 or 12-column fluid grid with `gutter: 1rem`.
- **Vertical Rhythm:** Devotional reading requires deliberate, spacious pacing. Quranic verse blocks maintain `space-lg` vertical spacing between segments, preventing cognitive crowding during recitation.
- **RTL Directionality:** All components invert across the vertical axis: back buttons face right (`arrow_forward` in LTR is `arrow_back` in RTL), chevron indicators point left for forward navigation, and progress bars fill right-to-left.

## Elevation & Depth

Visual hierarchy is established using soft tonal layering and subtle, diffused ambient shadows. Harsh drop shadows are strictly avoided to sustain an airy, spiritually serene atmosphere:

- **Level 0 (Flat Canvas):** `#F9FAF8` parchment surface.
- **Level 1 (Card Base):** Pure `#FFFFFF` or pale `#F4F6F0` elevated container with a delicate border outline: `1px solid rgba(30, 75, 62, 0.06)` and a gentle ambient shadow: `box-shadow: 0 2px 12px -2px rgba(23, 56, 46, 0.04)`.
- **Level 2 (Active & Floating Elements):** Floating audio player bars, active prayer time highlight cards, and sticky bottom navigation bars. Utilizes `box-shadow: 0 8px 24px -4px rgba(23, 56, 46, 0.08)` combined with a subtle frosted glass effect (`backdrop-filter: blur(12px)` over `rgba(255, 255, 255, 0.92)`).
- **Level 3 (Modals & Sheets):** Tafsir sheets, Tasbih goal dialogs, and share drawers. Rendered with a warm dimming backdrop (`rgba(23, 56, 46, 0.35)`) and upward elevation: `box-shadow: 0 -8px 32px rgba(23, 56, 46, 0.12)`.

## Shapes

The shape system utilizes `roundedness: 2` (base 0.5rem / 8px, cards 1rem / 16px, large containers 1.5rem / 24px) reflecting organic, architectural warmth reminiscent of gentle Islamic arches and courtyard contours.

- **Buttons & Small Chips:** Border radius set to `0.75rem` (12px) or full pill shape (`9999px`) for filter chips (e.g., Athkar categories: Morning, Evening, After Prayer).
- **Cards & Quick Actions:** Standard radius of `1rem` (16px) for daily remembrance cards, prayer trackers, and Quran surah index items.
- **Featured Banners & Hero Displays:** Generous `1.25rem` to `1.5rem` (20px–24px) radius, sometimes incorporating subtle arched top borders inspired by traditional Mihrab silhouettes.
- **Tasbih & Counter Elements:** Perfect concentric circles (`border-radius: 50%`) with tactile rim insets for digital bead tapping.

## Components

### Buttons & Interactive Controls
- **Primary Button:** Filled with Emerald (`#1E4B3E`) or Sage (`#2E7D5E`), white bold text, `0.75rem` radius, 48px standard touch target height. Subtle hover/active scale down (`0.98`).
- **Secondary / Ghost Button:** Light sand/mint fill (`rgba(46, 125, 94, 0.08)`) with primary emerald label and borderless contour.
- **Gold Accent Action:** Used for memorial gifts or special donations ("أهدي ثوابي لوالدي"); deep emerald container with gold accent border (`#C7A75C`) and sand typography.

### Prayer Times Grid & Cards
- **Current Prayer Card:** Highlighted with soft gold sand background (`rgba(199, 167, 92, 0.12)`), gold border (`#C7A75C`), active indicator dot, and countdown timer in bold primary emerald.
- **Standard Prayer Rows:** Clean horizontal rows displaying prayer name (RTL leading), adhan time (trailing), and subtle sound toggle icons (`bell` / `mute`).

### Chips & Horizontal Filter Selectors
- Pill-shaped (`rounded-full`), padded `space-xs space-md`.
- **Selected State:** Solid emerald fill (`#2E7D5E`) with crisp white label.
- **Unselected State:** Soft parchment background (`#FFFFFF`), subtle border (`1px solid #E5E9E2`), and muted charcoal text (`#5A6863`).

### Quranic Index & Reading Cards
- **Surah Row Item:** Number framed within a delicate octagonal or rounded Islamic star badge in sand gold; Surah title in prominent calligraphic font; trailing metadata (Ayah count, Revelation place: Makki/Madani) in muted caption text.
- **Ayah Verse Container:** Generous line spacing (38px–48px), end-of-ayah circular decorative floral rosette containing the verse number, and tap-to-listen interaction states highlighting the active ayah with soft golden yellow tint (`#FFF9E6`).

### Electronic Tasbih (Digital Counter)
- Centered circular tactile display with primary count in bold numerals; secondary reset and target pills (`33`, `100`, `∞`) arranged ergonomically below for single-thumb one-handed operation.

### Input Fields & Search Bars
- Background filled with `#FFFFFF` or `#F4F6F0`, border `1px solid rgba(30, 75, 62, 0.12)`, radius `0.75rem`.
- Search icons positioned at the right (leading in RTL), clear buttons at the left (trailing in RTL), placeholder text styled in calm muted sage-gray.