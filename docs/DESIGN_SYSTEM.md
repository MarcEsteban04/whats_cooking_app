# What's Cooking? — Design System

| Field | Value |
| ----- | ----- |
| **Status** | Approved — Sprint 04 |
| **Implements** | `core/theme/`, Sprint 07 |
| **Related** | [design_ui.md](design_ui.md) (visual direction) · [COMPONENTS.md](COMPONENTS.md) · [NAVIGATION_MAP.md](NAVIGATION_MAP.md) |

`design_ui.md` describes how the app should *feel*. This document supplies the **numbers** —
every value Sprint 07 needs to write `core/theme/` without making a single judgement call.

**Rule:** no colour, size, radius, duration or shadow may appear as a literal in feature
code. Everything comes from a token defined here.

---

## 1. Foundations

### 1.1 Design principles, in enforcement terms

| Principle | Mechanical rule |
| --------- | --------------- |
| Soft, warm, premium | Background is warm off-white, never pure white. Surfaces float above it. |
| Hierarchy from type and space | Borders are a last resort. Separate with whitespace and weight. |
| Restrained colour | Ink carries interaction; one terracotta accent carries SPIN. Pastels are backgrounds, never fills for text. |
| Generous breathing room | 20 px screen margins minimum, 24 px card padding, 32 px between sections. |
| Soft geometry | Nothing sharper than 8 px. Interactive pills are fully rounded. |
| Barely-there elevation | Large blur, very low opacity, no visible edge. |

### 1.2 Base grid

**4 px.** Every spacing, size and radius token is a multiple of 4, with two deliberate
exceptions noted where they occur.

---

## 2. Colour

### 2.1 Neutral scale — warm grey

The warmth is what separates this from a generic Material app. Every neutral carries a
slight yellow-green cast.

| Token | Hex | Use |
| ----- | --- | --- |
| `neutral0` | `#FFFFFF` | Card and sheet surfaces |
| `neutral50` | `#F7F7F5` | **App background** |
| `neutral100` | `#F1F1EE` | Muted surface, skeleton base, unselected chip |
| `neutral200` | `#E5E5E0` | Dividers, borders, skeleton highlight |
| `neutral300` | `#D4D4CE` | Disabled surfaces, inactive tracks |
| `neutral400` | `#A8A8A1` | Disabled text, placeholder icons |
| `neutral500` | `#8A8A80` | Decorative only — **never body text on light** |
| `neutral600` | `#6B6B63` | Tertiary text, metadata |
| `neutral700` | `#5A5A52` | Secondary text |
| `neutral800` | `#2A2A26` | Strong text on muted surfaces |
| `neutral900` | `#1A1A17` | **Primary text** |

### 2.2 Ink, and one accent

**There is no brand green.** `design_ui.md` §2 specified `#3FA66B` and it has been removed
from the app: the palette is warm near-black on warm white, and interaction is expressed by
**weight** rather than by hue. A filled ink pill is the primary action, an outline is the
secondary, and neither needs a colour to say which. The auth screens already worked this way
(`login_reference.webp`), and `reference_design/dashboards_ref.webp` carries its whole
structure in ink — this makes the rest of the app agree with both.

One accent survives, because an app about food that is *entirely* monochrome reads as a
spreadsheet. It is the terracotta the dashboards reference itself uses for the figure it
wants read first, and it is spent on exactly two things: the **SPIN** button and the leading
**data series**. Anywhere else is a review failure.

| Token | Hex | Role |
| ----- | --- | ---- |
| `ink50` | `#F2F2EF` | Selected chip background, tinted container |
| `ink100` | `#E4E4DF` | Tinted container, one step stronger |
| `ink200` | `#C7C7C0` | Decorative, dark-theme dividers |
| `ink300` | `#9C9C94` | Dark-theme accents |
| `ink400` | `#6E6E66` | Disabled fills, inactive tracks |
| `ink500` | `#3A3A34` | Ink at reading weight |
| `ink600` | `#232320` | **Interactive fill.** Buttons, active nav, selected states. White text = 15.76:1 ✅ |
| `ink700` | `#141412` | Pressed state |
| `ink800` | `#1A1A17` | Text on a tinted container |
| `ink900` | `#0D0D0B` | Strongest ink — still warm, never `#000000` |
| `brand` | `#E8622A` | **SPIN button and leading data series only.** Dark text = 5.16:1 ✅ |
| `brandDark` | `#FF8551` | The same, lifted for a dark surface |

> **The rule:** ink for everything that is interactive, `brand` for the one action the whole
> app exists to offer. White on `brand` reaches only **3.38:1**, which is why the SPIN label
> is dark — the same trade the brand green made before it, at the same place in the scale.

### 2.3 Pastel accents

Backgrounds only. Each pairs with a fixed foreground that reaches AA.

| Token | Background | Foreground | Contrast | Suggested use |
| ----- | ---------- | ---------- | -------- | ------------- |
| `accentPeach` | `#FFE8D6` | `#7A4322` | 6.70:1 | Comfort food, breakfast |
| `accentButter` | `#FFF3CC` | `#6E5410` | 6.45:1 | Snacks, desserts |
| `accentStone` | `#EBE7DE` | `#5A5346` | 6.16:1 | Healthy, vegetarian |
| `accentLavender` | `#E8E4F5` | `#413672` | 8.44:1 | Surprise me, AI |
| `accentCoral` | `#FFDDD6` | `#8A3524` | 6.33:1 | Spicy, meat |
| `accentSky` | `#DDEBF7` | `#1F4E75` | 7.19:1 | Seafood, light meals |

Never place a pastel on a pastel, and never use one as a button fill.

### 2.4 Semantic

| Token | Hex | On-colour | Surface | On-surface |
| ----- | --- | --------- | ------- | ---------- |
| `success` | `ink600` `#232320` | `#FFFFFF` | `ink50` `#F2F2EF` | `ink800` `#1A1A17` |
| `warning` | `#A66214` | `#FFFFFF` | `#FFF3CC` | `#6E5410` |
| `error` | `#C4362C` | `#FFFFFF` | `#FDECEA` | `#8A2119` |
| `info` | `#2F6FB0` | `#FFFFFF` | `#E8F1FA` | `#1F4E75` |

All four exceed 4.5:1 with white text. Error and warning are always paired with an icon and
words — colour alone never carries meaning.

### 2.5 Light theme roles

| Role | Token |
| ---- | ----- |
| `background` | `neutral50` `#F7F7F5` |
| `surface` | `neutral0` `#FFFFFF` |
| `surfaceMuted` | `neutral100` `#F1F1EE` |
| `surfaceInverse` | `neutral900` `#1A1A17` |
| `outline` | `neutral200` `#E5E5E0` |
| `outlineStrong` | `neutral300` `#D4D4CE` |
| `textPrimary` | `neutral900` — 16.26:1 on background |
| `textSecondary` | `neutral700` — 6.48:1 |
| `textTertiary` | `neutral600` — 5.01:1 |
| `textDisabled` | `neutral400` — decorative only |
| `textOnPrimary` | `#FFFFFF` |
| `primary` | `ink600` |
| `primaryBrand` | `brand` `#E8622A` |
| `primaryContainer` | `ink50` |
| `onPrimaryContainer` | `ink800` |

### 2.6 Dark theme roles

Warm-shifted, matching the light palette's cast. Elevation is expressed as **lighter
surfaces**, not shadows — shadows are invisible on dark.

| Role | Hex | Note |
| ---- | --- | ---- |
| `background` | `#141412` | Warm near-black, never `#000000` |
| `surface` | `#1E1E1B` | Cards |
| `surfaceMuted` | `#262622` | Elevated / muted |
| `surfaceHigh` | `#2E2E29` | Sheets, dialogs |
| `outline` | `#35352F` | |
| `outlineStrong` | `#45453E` | |
| `textPrimary` | `#F2F2EE` | 16.43:1 |
| `textSecondary` | `#B0B0A6` | 8.44:1 |
| `textTertiary` | `#8A8A80` | 5.29:1 |
| `textDisabled` | `#5A5A52` | |
| `primary` | `#F2F2EE` | Inverted, not tinted — a near-white pill with `#1A1A17` text (15.54:1) |
| `primaryBrand` | `brandDark` `#FF8551` | Pair with `#1A0B04` text (7.98:1); 7.66:1 on background |
| `primaryContainer` | `#2E2E29` | |
| `onPrimaryContainer` | `#F2F2EE` | |
| `error` | `#E5695E` | Lightened for dark contrast |
| `success` | `#F2F2EE` | Ink, not a colour — the tick carries the meaning |
| `warning` | `#D99A3E` | |
| `info` | `#6FA8D8` | |

Pastels in dark mode drop to ~14% opacity over `surface`, with the foreground swapped to the
corresponding `*200` tint. They are never used at full saturation.

---

## 3. Typography

**Family:** Inter (via `google_fonts`), falling back to the platform UI font.
`design_ui.md` §3 prefers SF Pro on iOS; Inter is metrically close enough that one scale
serves both.

**Weights used:** 400 Regular · 500 Medium · 600 SemiBold · 700 Bold. Nothing else — §3
explicitly warns against weight sprawl.

| Token | Size / Line | Weight | Tracking | Use |
| ----- | ----------- | ------ | -------- | --- |
| `displayLarge` | 40 / 44 | 700 | −0.5 | Result screen meal name, celebration |
| `displayMedium` | 34 / 40 | 700 | −0.4 | Roulette reveal |
| `headlineLarge` | 28 / 34 | 700 | −0.3 | "Good evening, Marc 👋" |
| `headlineMedium` | 24 / 30 | 600 | −0.2 | Screen titles |
| `headlineSmall` | 20 / 26 | 600 | −0.2 | "What are we eating tonight?" |
| `titleLarge` | 18 / 24 | 600 | −0.1 | Card titles, section headers |
| `titleMedium` | 16 / 22 | 600 | 0 | Meal card name, list row title |
| `titleSmall` | 15 / 20 | 600 | 0 | Dense titles |
| `bodyLarge` | 16 / 24 | 400 | 0 | Primary reading text, instructions |
| `bodyMedium` | 15 / 22 | 400 | 0 | Default body |
| `bodySmall` | 13 / 18 | 400 | 0 | Supporting text |
| `label` | 15 / 20 | 600 | 0 | **Button text** |
| `labelSmall` | 13 / 16 | 600 | +0.1 | Chips, pills, tabs |
| `metadata` | 13 / 18 | 500 | 0 | "30 min · ₱220 · 2 servings" — `textTertiary` |
| `overline` | 11 / 14 | 600 | +0.8 | UPPERCASE micro-labels — use sparingly |
| `numeric` | 15 / 20 | 600 | 0 | Costs and quantities — **tabular figures** |

**Rules**

* Body text never drops below 13 px. Metadata at 13 px sits on `textTertiary` (4.8:1) — the
  floor, deliberately chosen to stay AA.
* `numeric` enables `fontFeatures: [FontFeature.tabularFigures()]` so prices don't jitter
  during roulette animation.
* Text scales with the OS setting, clamped to **0.85×–1.3×**. Every layout must survive
  1.3× without truncating a price, a time or a button label.
* Headlines use negative tracking; small text uses zero or positive. This is what makes
  large type read as designed rather than merely large.

---

## 4. Spacing

Base 4 px.

| Token | px | Typical use |
| ----- | -: | ----------- |
| `space0` | 0 | |
| `space1` | 4 | Icon-to-label, tightest pairs |
| `space2` | 8 | Inside chips, between metadata pills |
| `space3` | 12 | Between related rows, list item gaps |
| `space4` | 16 | Default gap, compact card padding |
| `space5` | 20 | **Screen horizontal margin** |
| `space6` | 24 | **Card internal padding** |
| `space7` | 32 | **Between sections** |
| `space8` | 40 | Around hero elements |
| `space9` | 48 | Empty-state breathing room |
| `space10` | 64 | Top of celebration screens |

### Layout constants

| Constant | Value |
| -------- | ----: |
| Screen horizontal margin | 20 |
| Screen top padding (below safe area) | 8 |
| Card padding | 24 |
| Compact card padding | 16 |
| Gap between cards in a list | 12 |
| Gap between grid cells | 12 |
| Section gap | 32 |
| Bottom nav height | 64 |
| Bottom nav floating inset | 16 horizontal, 12 above safe area |
| **Scroll bottom padding** | 96 — content must clear the floating nav |
| Minimum touch target | 48 × 48 |
| Content max width (tablet) | 560 — centred |

---

## 5. Radius

| Token | px | Applies to |
| ----- | -: | ---------- |
| `radiusXs` | 8 | Skeleton bars, tiny badges |
| `radiusSm` | 12 | Inputs, small tiles, ingredient chips |
| `radiusMd` | 16 | Compact cards, list rows, images inside cards |
| `radiusLg` | 20 | Standard cards, text fields |
| `radiusXl` | 24 | Meal cards, category cards |
| `radius2xl` | 28 | **Feature cards, bottom sheets, dialogs** |
| `radius3xl` | 32 | Roulette card, hero surfaces |
| `radiusFull` | 999 | Pills, chips, buttons, avatars, FABs |

Nested corners: an inner radius should be the outer minus its padding, floored at
`radiusSm`. A 24 px card with 24 px padding takes an inner image radius of 16, not 24 —
concentric corners are what make the nesting read as intentional.

---

## 6. Elevation

Very low opacity, large blur, no visible edge (`design_ui.md` §5). Shadow colour is always
`#1A1A17` at the stated alpha — never pure black.

| Token | Offset | Blur | Spread | Alpha | Use |
| ----- | ------ | ---: | -----: | ----: | --- |
| `shadowXs` | 0, 1 | 2 | 0 | 0.04 | Chips, small pills |
| `shadowSm` | 0, 2 | 8 | 0 | 0.05 | Standard cards, text fields |
| `shadowMd` | 0, 4 | 16 | −2 | 0.06 | Raised cards, floating badges |
| `shadowLg` | 0, 8 | 28 | −4 | 0.08 | **Bottom navigation**, feature cards |
| `shadowXl` | 0, 16 | 40 | −8 | 0.10 | Sheets, dialogs, roulette card |

**Dark theme:** all shadows resolve to `none`. Elevation is carried by `surface` →
`surfaceMuted` → `surfaceHigh` instead. Sprint 07 must branch on brightness, not reuse the
light shadow list at lower alpha.

Scrims: `#1A1A17` at 32% light, 56% dark.

---

## 7. Motion

| Token | ms | Curve | Use |
| ----- | -: | ----- | --- |
| `durationInstant` | 0 | — | Tab switches |
| `durationFast` | 150 | `easeOut` | Press feedback, chip toggles, checkboxes |
| `durationNormal` | 250 | `easeOutCubic` | Standard transitions, fades |
| `durationSlow` | 400 | `easeOutCubic` | Sheets, dialogs, page transitions |
| `durationCelebrate` | 600 | `easeOutBack` | Result reveal, confetti |
| `durationSpin` | 2400 | custom | Roulette cycling — **hard cap 3000** |

**Roulette timing** — the product's signature moment:

| Phase | ms | Behaviour |
| ----- | -: | --------- |
| Wind-up | 200 | Button press, scale to 0.96, light haptic |
| Fast cycle | 1200 | ~80 ms per meal, linear |
| Deceleration | 800 | `easeOutQuart`, cards visibly slow |
| Reveal | 400 | Spring settle, **medium-impact haptic**, confetti |

Tapping during the spin **skips to reveal immediately**. Suspense is a gift to the user, not
a toll — and the 60-second budget has no room for a toll.

**Reduce motion:** cycling is replaced by a 250 ms cross-fade to the result; confetti is
suppressed; hero transitions become fades. **Haptics are retained** — they carry the
satisfaction when animation cannot.

Press feedback on every tappable surface: scale to 0.97 over 100 ms, release over 150 ms.

---

## 8. Iconography

* **Material Symbols Rounded**, weight 400, grade 0, optical size 24. Rounded matches the
  geometry; sharp icons fight it.
* Outlined for inactive, **filled for active** — this is how bottom-nav selection reads
  without a colour change carrying the whole load.

| Token | px | Use |
| ----- | -: | --- |
| `iconXs` | 16 | Inline with `bodySmall`, inside chips |
| `iconSm` | 20 | Metadata rows, text-field affixes |
| `iconMd` | 24 | **Default** — nav, buttons, app bar |
| `iconLg` | 28 | Feature cards, empty states |
| `iconXl` | 48 | Empty and error illustrations |

Icons default to `textSecondary`; interactive icons use `primary`. An icon-only control is
always ≥ 48 px in touch size regardless of the glyph size, and always carries a semantic
label.

**Emoji** are content, not iconography. They appear in meal and category data
(🍗 🍜 🥗 🎲) and in headline copy, never as functional controls.

---

## 9. Imagery

> **No emoji anywhere in the interface.** They were used as cheap illustration — empty
> states, tile glyphs, the wordmark, the promise cards — and every one has been replaced with
> a themed icon. Two reasons: they arrive full-colour and platform-specific, which beside a
> monochrome palette reads as clip art dropped into a design system; and an icon inherits the
> ink, so it is dark on light and light on dark without anyone thinking about it. Anywhere a
> glyph is wanted, it comes from `AppIcons`.
>
> There is also no meal imagery at all — see COMPONENTS §4. The table below is the brief for
> when there is.

| Context | Ratio | Radius | Fallback |
| ------- | ----- | ------ | -------- |
| Meal card, feed | 4:3 | `radiusXl` top | Pastel block + cuisine emoji |
| Meal detail hero | 3:2 | `radius2xl` bottom | Same |
| Result screen | 1:1 | `radius3xl` | Same |
| Compact / list row | 1:1, 64 px | `radiusMd` | Same |
| Planner day thumb | 1:1, 44 px | `radiusSm` | Same |
| Avatar | 1:1 | `radiusFull` | Initials on `ink100` |

Every image fades in over 250 ms, shows a shimmer skeleton while loading, and degrades to a
deterministic pastel-plus-emoji block keyed off the meal ID — so a missing photo still looks
composed, and looks the *same* on every launch.

Images carry a scrim only where text sits on them: a bottom-up linear gradient from
`#1A1A17` at 55% to transparent across the lower 45%.

---

## 10. Responsive behaviour

| Breakpoint | Width | Layout |
| ---------- | ----- | ------ |
| `compact` | < 600 | Single column. Category grid 3 across. Meal feed 1 across. |
| `medium` | 600–904 | Content capped at 560 and centred. Category grid 4. Meal feed 2. |
| `expanded` | > 904 | Content capped at 560. Meal feed 2–3. Bottom nav may become a rail. |

Never branch on a raw pixel value in feature code — use the breakpoint helper. Small phones
(320 px) must show the full SPIN card without scrolling; that is the hard floor.

---

## 11. Accessibility floor

Non-negotiable, and part of every component's Definition of Done.

| Requirement | Standard |
| ----------- | -------- |
| Text contrast | 4.5:1 normal, 3:1 for ≥ 18 px semibold |
| UI component contrast | 3:1 for borders, icons, focus rings |
| Touch targets | 48 × 48 minimum, 8 px between adjacent targets |
| Text scaling | Functional to 1.3× with no truncation of prices, times or labels |
| Colour independence | Never the sole carrier of meaning — pair with icon or text |
| Semantics | Every icon-only control labelled; decorative images excluded from the tree |
| Focus | Visible 2 px `primary` ring at 2 px offset |
| Motion | Full reduce-motion path; haptics preserved |
| Announcements | Roulette result, grocery check and errors announced to screen readers |

The 13 px `textTertiary` metadata pairing is the tightest text combination in the system at
**5.01:1**. Nothing may go below it.

**Every ratio in this document is computed, not estimated.** Re-verify after any palette
change:

```bash
tool/contrast_check.sh
```

The only pair that intentionally fails is `textDisabled` (`neutral400`) at 2.23:1 — WCAG
exempts disabled controls, and it must never carry meaningful content.

---

## 12. Token naming for Sprint 07

```text
core/theme/
├── app_colors.dart      Raw palette — neutral0..900, ink50..900, the brand accent, pastels, semantics
├── app_theme.dart       ThemeData for light and dark, wiring ColorScheme
├── app_typography.dart  TextTheme built on GoogleFonts.inter
├── app_spacing.dart     space0..10 plus layout constants
├── app_radius.dart      radiusXs..radiusFull, BorderRadius helpers
├── app_shadows.dart     shadowXs..shadowXl, brightness-aware
├── app_motion.dart      Durations and curves, roulette phase constants
├── app_icons.dart       Icon size constants and the semantic icon map
└── app_breakpoints.dart compact / medium / expanded helpers
```

Semantic roles are exposed through a `ThemeExtension` (`AppColorsExtension`) so feature code
reads `context.colors.textTertiary`, not `AppColors.neutral600`. **Raw palette constants are
private to the theme layer.** A feature file that imports `app_colors.dart` directly is a
review failure.

---

## 13. Verification checklist for Sprint 07

- [ ] Light and dark `ThemeData` built entirely from tokens
- [ ] `ColorScheme` populated for both brightnesses; no `Colors.*` outside the theme layer
- [ ] Text theme uses Inter with the exact sizes, weights and tracking above
- [ ] Tabular figures enabled on the `numeric` style
- [ ] Shadows resolve to `none` in dark
- [ ] `MediaQuery` text scale clamped to 0.85–1.3
- [ ] Reduce-motion honoured by every motion token consumer
- [ ] Every pair in §2 verified against its stated contrast ratio
- [ ] A `ThemeExtension` exposes semantic roles; raw palette stays private
