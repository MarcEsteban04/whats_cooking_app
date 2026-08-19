# What's Cooking? — Component Specifications

| Field | Value |
| ----- | ----- |
| **Status** | Approved — Sprint 04 |
| **Implements** | `core/widgets/`, Sprint 08 |
| **Related** | [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md) · [design_ui.md](design_ui.md) · [USER_FLOWS.md](USER_FLOWS.md) |

Every component below is specified to the point where Sprint 08 can build it without
inventing a value. All measurements reference tokens from [DESIGN_SYSTEM.md](DESIGN_SYSTEM.md).

**Universal requirements** — every interactive component must satisfy these before it is
considered done:

* Press feedback: scale 0.97 over `durationFast`
* Touch target ≥ 48 × 48 even when the visual is smaller
* Disabled state that is visibly disabled *and* excluded from the semantics tree as tappable
* A semantic label — icon-only controls always
* Survives 1.3× text scale without truncation
* Renders correctly in light and dark

---

## 1. AppButton

The primary CTA is the strongest element on any screen it appears on (`design_ui.md` §36).

### Variants

| Variant | Fill | Text | Border | Use |
| ------- | ---- | ---- | ------ | --- |
| `primary` | `primary600` | `#FFFFFF` | none | The one main action per screen |
| `secondary` | `surface` | `textPrimary` | 1 px `outline` | Alternative actions |
| `tertiary` | transparent | `primary600` | none | Low-emphasis, inline |
| `destructive` | `error` | `#FFFFFF` | none | Delete, leave household, remove |
| `brand` | `primary500` | `#0F2E1D` | none | **SPIN only.** Brand green with dark text — 4.81:1 |

### Sizes

| Size | Height | H-padding | Radius | Text | Icon |
| ---- | -----: | --------: | ------ | ---- | ---- |
| `large` | 56 | 32 | `radiusFull` | `label` | `iconMd` |
| `medium` | 48 | 24 | `radiusFull` | `label` | `iconSm` |
| `small` | 40 | 16 | `radiusFull` | `labelSmall` | `iconXs` |

Large is the default for a screen's primary action and matches the 52–58 px range in
`design_ui.md` §36.

### States

| State | Treatment |
| ----- | --------- |
| Default | As specified, `shadowSm` on `primary` and `brand` only |
| Pressed | Fill → `primary700`, scale 0.97, shadow removed |
| Disabled | Fill `neutral200`, text `neutral400`, no shadow, no press |
| Loading | Text replaced by a 20 px indicator in the text colour; **width held constant**; disabled |
| Full-width | `double.infinity` with the screen margin applied by the parent |

Width must not change on entering the loading state — a button that resizes under the
thumb causes mis-taps.

### API

```text
AppButton({
  required String label,
  required VoidCallback? onPressed,   // null = disabled
  AppButtonVariant variant = primary,
  AppButtonSize size = large,
  IconData? leadingIcon,
  IconData? trailingIcon,
  bool isLoading = false,
  bool isFullWidth = false,
})
```

---

## 2. AppTextField

| Property | Value |
| -------- | ----- |
| Height | 56 (single line) |
| Padding | 16 horizontal, 16 vertical |
| Radius | `radiusMd` — the reference’s inputs are less rounded than its buttons |
| Fill | `surface` |
| Border | 1 px `outline` |
| Focused border | 2 px `primary600` |
| Error border | 2 px `error` |
| Text | `bodyMedium`, `textPrimary` |
| Placeholder | `bodyMedium`, `textDisabled` |
| Label | `labelSmall`, `textSecondary`, above the field, 8 px gap |
| Helper / error | `bodySmall`, 6 px below, `textTertiary` or `error` |

**Rules**

* Validation fires on **blur**, not on every keystroke. Errors while typing are hostile.
* The error message replaces the helper text in place — the field must not shift the layout
  when an error appears. Reserve the line height.
* Password fields carry a visibility toggle, minimum 48 px touch target.
* Multi-line grows from 56 up to 5 lines, then scrolls internally.

### SearchField

A variant, not a separate component. `radiusFull`, `surfaceMuted` fill, no border,
`shadowXs`, leading `search` icon at `iconSm` in `textTertiary`, trailing clear button once
non-empty. Debounced at **300 ms**. Placeholder: *"Search meals, ingredients, or cuisines"*.

---

## 3. AppCard

The foundational surface (`design_ui.md` §34).

| Property | Value |
| -------- | ----- |
| Fill | `surface` |
| Radius | `radiusXl` (24) |
| Padding | `space6` (24), or `space4` (16) compact |
| Shadow | `shadowSm`, or `shadowMd` when raised |
| Border | none — elevation does the separating |

Variants: `standard` · `compact` (16 padding, `radiusMd`) · `feature` (`radius2xl`,
`shadowLg`, may carry imagery) · `tappable` (adds press feedback and a semantic button role).

Cards never nest more than one level. A card inside a card inside a card is a layout that
lost an argument with itself.

---

## 4. MealCard

Three forms, one component.

### `feed` — the Meals tab

```text
┌──────────────────────────┐
│                          │  4:3 image, radiusXl top
│        FOOD IMAGE        │  heart button floating top-right
│                       ♥  │
├──────────────────────────┤
│ Chicken Katsu            │  titleMedium, max 2 lines
│ Japanese · 30 min        │  metadata, 1 line
│ ₱220                     │  numeric, textPrimary
└──────────────────────────┘
```

Full available width, image 4:3, content padding 16, gap between cards 12. The heart is a
36 px circle on `#FFFFFF` at 90% with `shadowXs`, and always keeps a 48 px touch target.

### `compact` — history, planner, search

64 px square image at `radiusMd`, title and metadata stacked to its right, optional trailing
action. Row height 88, padding 12, radius `radiusMd`.

### `result` — the roulette payoff

1:1 image at `radius3xl`, `displayMedium` name centred beneath, a row of metadata pills, and
an optional context line — *"⭐ Loved by both of you"* — in `labelSmall` on `primary600`.
This form gets `shadowXl`; it is the most important surface in the app.

**All forms:** the whole card is tappable to detail. The heart is an independent target and
must not trigger navigation. Optimistic toggle with a scale-1.3-then-settle animation over
`durationFast`.

---

## 5. Chips and pills

### FilterChip — horizontal scrolling filters (`design_ui.md` §16)

| State | Fill | Text | Border |
| ----- | ---- | ---- | ------ |
| Unselected | `surface` | `textSecondary` | 1 px `outline` |
| Selected | `primary600` | `#FFFFFF` | none |
| Disabled | `surfaceMuted` | `textDisabled` | none |

Height 36, padding 16 horizontal, `radiusFull`, `labelSmall`. Optional leading icon at
`iconXs`, and a trailing count badge. Rows scroll horizontally with 8 px gaps and a 20 px
leading inset matching the screen margin.

### CuisineChip

As above but with the cuisine's assigned pastel background and paired foreground from
§2.3 when selected — the one place pastels carry a selected state, because cuisine is
categorical rather than binary.

### IngredientChip — pantry

Height 40, `radiusFull`, `surfaceMuted` fill, `labelSmall` on `textPrimary`, optional
quantity in `textTertiary`, trailing 20 px remove target inside a 48 px hit area. Wraps into
multiple lines with 8 px gaps.

### MetadataPill — the "₱220 · 30 min · 2 servings" row

Height 32, padding 12 horizontal, `radiusFull`, `surfaceMuted` fill, `labelSmall` on
`textSecondary`, optional leading `iconXs`. Non-interactive. Laid out in a row with 8 px
gaps; wraps rather than truncates.

---

## 6. CategoryCard — Home quick picks

Square, aspect 1:1, `radiusXl`, pastel fill from §2.3, `shadowXs`. A 28 px emoji or icon
centred in the upper area, label in `labelSmall` on the pastel's paired foreground beneath.
Three across on compact, four on medium, 12 px gaps.

Tapping a category **starts a spin with that filter pre-applied** (`USER_FLOWS.md` §6) — it
is not a browse entry point. The semantic label must say so: *"Comfort food — spin"*.

---

## 7. RouletteCard — the Home centrepiece

The single most important composition in the app (`design_ui.md` §11).

```text
┌────────────────────────────────┐
│  🎰                            │
│  What are we eating tonight?   │  headlineSmall
│  Let us decide for you.        │  bodyMedium, textSecondary
│                                │
│  ₱300 · 2 people               │  metadata pills
│                                │
│  ┌──────────────────────────┐  │
│  │          SPIN            │  │  AppButton.brand, large, full width
│  └──────────────────────────┘  │
└────────────────────────────────┘
```

`radius3xl`, `shadowXl`, `space6` padding, `surface` fill with an optional subtle food image
or gradient at low opacity. Budget and party-size pills are **tappable** and open the filter
sheet directly — the fastest possible path to adjusting a constraint.

Minimum height 260. On a 320 px-wide device it must be fully visible without scrolling.

---

## 8. Bottom navigation

Floating capsule, not a Material `NavigationBar` (`design_ui.md` §7).

| Property | Value |
| -------- | ----- |
| Height | 64 |
| Inset | 16 horizontal, 12 above the safe area |
| Radius | `radiusFull` |
| Fill | `surface` |
| Shadow | `shadowLg` |
| Items | 5, equal width |

| State | Icon | Label |
| ----- | ---- | ----- |
| Active | Filled, `primary600`, `iconMd` | `overline`, `primary600` |
| Inactive | Outlined, `textTertiary`, `iconMd` | `overline`, `textTertiary` |

Active items additionally carry a `primary50` pill behind the icon at 32 px height. Icon
transitions cross-fade over `durationFast`; there is no sliding indicator.

Scrollable content requires 96 px bottom padding so nothing is ever trapped behind the bar.

---

## 9. AppBottomSheet

| Property | Value |
| -------- | ----- |
| Radius | `radius2xl` top corners |
| Fill | `surface` |
| Shadow | `shadowXl` |
| Handle | 40 × 4, `neutral300`, `radiusFull`, 12 from top |
| Padding | 20 horizontal, 8 top, 24 + safe area bottom |
| Max height | 90% of screen |
| Scrim | `#1A1A17` at 32% |

Title in `titleLarge`, optional subtitle in `bodySmall` on `textSecondary`, both left
aligned. Drag-to-dismiss is always enabled. When a sheet has a confirming action it is a
full-width `AppButton.primary` pinned at the bottom, above the safe area.

Sheets are **routes** (`NAVIGATION_MAP.md` §9), not imperative calls.

Used for: filters, budget, cuisine selection, adding ingredients, adding grocery items,
household actions (`design_ui.md` §37).

---

## 10. ConfirmationDialog

| Property | Value |
| -------- | ----- |
| Width | Screen minus 40, max 340 |
| Radius | `radius2xl` |
| Padding | 24 |
| Fill | `surface` |
| Shadow | `shadowXl` |

Optional 48 px icon in a tinted circle, title in `titleLarge` centred, body in `bodyMedium`
on `textSecondary` centred, then actions stacked full width with 12 px between: confirm on
top, cancel beneath as `secondary`.

Destructive confirmations use `AppButton.destructive` and name the consequence explicitly —
*"Delete this meal? It will be removed from your history."* Never a bare "Are you sure?".

---

## 11. Loading states

Never a full-screen spinner (`design_ui.md` §30).

### Skeleton

Base `neutral100`, highlight `neutral200`, shimmer sweeping left-to-right over 1200 ms with
an 800 ms pause. Radius matches the element being replaced. Text lines are 12 px tall at
`radiusXs`, with the final line at 60% width.

Every list has a matching skeleton that **mirrors its real layout** — same card heights,
same gaps — so nothing shifts when content arrives. A skeleton that doesn't match its
content is worse than none.

### Inline indicator

20 px, 2 px stroke, `primary600`. Used inside buttons and for pagination footers only.

### Optimistic actions

Favourite, dislike and grocery check apply immediately with no loading state, and revert
with a snackbar if the write fails.

---

## 12. EmptyState

Centred, `space9` vertical padding.

| Element | Spec |
| ------- | ---- |
| Illustration | 48 px emoji or `iconXl` in `textTertiary` |
| Title | `titleLarge`, `textPrimary`, centred |
| Body | `bodyMedium`, `textSecondary`, centred, max 280 wide |
| Action | `AppButton.primary`, `medium` |

Copy is warm and specific, and the action always points back toward the core loop
(`design_ui.md` §29):

| Screen | Title | Body | Action |
| ------ | ----- | ---- | ------ |
| Favourites | Nothing saved yet | Spin the wheel and find something you love. | What's Cooking? |
| History | No meals yet | Your decisions will show up here. | Spin |
| Pantry | Your fridge is empty | Add what you have and we'll find something to cook. | Add ingredient |
| Grocery | Nothing to buy | Accept a meal and we'll fill this in for you. | Spin |
| Search | No meals found | Try a different search, or loosen your filters. | Clear filters |
| My meals | No meals of your own yet | Add the food you actually cook. | Add a meal |

---

## 13. ErrorState

Same structure as `EmptyState`, with `error` semantics. Never exposes exception text
(`design_ui.md` §31).

| Element | Spec |
| ------- | ---- |
| Icon | `iconXl`, `error` at 60% opacity |
| Title | `titleLarge` — *"Hmm, something went wrong."* |
| Body | `bodyMedium`, `textSecondary` — what failed, in plain words |
| Action | `AppButton.primary` — *"Try Again"* |
| Secondary | `tertiary` — *"Go back"* where a back path exists |

| Condition | Title | Body |
| --------- | ----- | ---- |
| Network | No connection | Check your internet and try again. |
| Server | Something went wrong | We couldn't load your meals right now. |
| Not found | We couldn't find that | It may have been removed. |
| Permission | You don't have access | This belongs to another household. |
| Unknown | Something went wrong | Try again in a moment. |

An error code may appear in `bodySmall` on `textDisabled` **beneath** the action, for
support purposes only — never in the primary message.

### Inline error banner

For non-blocking failures: 48 px tall, `errorSurface` fill, `radiusMd`, 20 px `error` icon,
`bodySmall` on `onErrorSurface`, optional retry. Slides in over `durationNormal`.

---

## 14. Progress and match indicators

### MatchIndicator — pantry results (`design_ui.md` §19)

A horizontal track 6 px tall at `radiusFull`. Track `neutral200`; fill `primary500`.
Percentage label to the right in `numeric` on `textPrimary`.

| Range | Fill | Label |
| ----- | ---- | ----- |
| 100% | `primary600` | You have everything |
| 70–99% | `primary500` | *n*% available |
| 40–69% | `warning` | *n*% available |
| < 40% | `neutral400` | *n*% available |

Colour is reinforced by the words — the percentage is always stated, never colour alone.

### GroceryProgress

*"6 of 10 items"* in `labelSmall` on `textSecondary`, with a 4 px track beneath filled in
`primary600`, animating over `durationNormal` on change.

---

## 15. List rows

### GroceryRow

Height 56, padding 16 horizontal, `radiusMd`, `surface` fill, 8 px between rows. A 24 px
checkbox at the leading edge with a 48 px touch target; name in `bodyMedium`; quantity in
`metadata` on `textTertiary` trailing.

Checked: text drops to `textDisabled` with a strikethrough, the row fades to 60% over
`durationNormal`, and it **stays in place** (`design_ui.md` §23). Completed items move to a
collapsed section only on explicit "clear completed".

Swipe left reveals delete on `error`; swipe right toggles the check.

### IngredientRow — meal detail

Name left in `bodyMedium`, quantity right in `numeric` on `textSecondary`, 44 px tall, 1 px
`outline` divider between rows. Items already in the pantry carry a 16 px `check` in
`success` before the name.

### InstructionStep

Step number in `displayMedium` on `neutral200` — large, decorative, and the anchor for
scanning. Instruction text in `bodyLarge` beneath. 32 px between steps.

---

## 16. Avatars and household

| Size | px | Use |
| ---- | -: | --- |
| `small` | 32 | Home header, list rows |
| `medium` | 48 | Couple screen, member lists |
| `large` | 96 | Profile header |

Circular, `radiusFull`, 2 px `surface` ring when overlapping. Fallback is initials in
`titleMedium` on `primary100` with `primary800` text.

**CoupleAvatars:** two avatars overlapping by 12 px with a 20 px heart between them, names
beneath in `titleMedium`, and the match percentage in `headlineSmall` on `primary600`
(`design_ui.md` §20).

---

## 17. SectionHeader

Title in `titleLarge` on `textPrimary`, optional trailing text action in `labelSmall` on
`primary600`. 32 px above, 16 px below. Optional `bodySmall` subtitle on `textSecondary`
between title and content.

---

## 18. AppSnackbar

Floating above the bottom navigation, 16 px horizontal inset, `radiusMd`, `shadowLg`,
`bodySmall` on the fill's paired foreground, 4 s default duration.

| Type | Fill | Icon |
| ---- | ---- | ---- |
| Neutral | `surfaceInverse` | none |
| Success | `success` | `check_circle` |
| Error | `error` | `error_outline` |

One action maximum, in `labelSmall`, uppercase. Snackbars never carry information the user
must act on — that is what an error state is for.

---

## 18b. Onboarding and preferences

Onboarding introduced these; profile now shares them. The progress bar stays
onboarding-only, but the tile and the six preference editors moved to
`core/widgets/preferences/` once a second feature needed them - a user must meet the
same cuisine grid on day one and on day thirty (docs/ARCHITECTURE.md §2.3).

### OnboardingProgress

A 4 px `radiusFull` track above a centred `metadata` counter — *"Step 3 of 7"*.

Fill is `primaryBrand`, the **identity** green rather than the interactive one. This is
the rare case where that is correct: the bar is not tappable, so the 4.5:1 contrast floor
that governs interactive green does not apply, and the identity colour is what makes the
flow feel like part of the brand rather than part of a form.

The counter is not decoration. A bar alone tells you how far along you are but not how
much remains in units you can reason about; *"Step 3 of 7"* is what makes seven questions
feel finite. The pair is announced once, via the counter — the bar is excluded from
semantics so a screen reader does not read the same fact twice.

The bar reaches 100% on the closing screen. Telling someone they are finished underneath
a partial bar is a contradiction, and it is asserted in test.

### SelectableTile

A selectable row: `surface` fill, `radiusLg`, a 44 px tinted leading square holding an
emoji or icon, title in `titleSmall`, optional caption in `metadata`, and a 24 px
selection mark on the right.

| State | Border | Mark |
| ----- | ------ | ---- |
| Unselected | 1 px `outline` | 24 px ring in `outlineStrong` |
| Selected | 2 px `primary` | Filled `primary` circle with a white check |

Selection is carried by the border and the mark, **not** by flooding the card with
colour. A screen of filled cards loses the hierarchy that makes the chosen one obvious —
the same mistake the first pass at this design system made.

The mark occupies its space whether or not it is selected, so choosing an option does not
shift the text beside it.

Used where the answers are few and each deserves reading — budget, cooking time, who you
cook for, and which theme to use. Chips are used instead where the answer set is large and multi-select, because a
chip row reads as *"pick several from many"* and a tile list reads as *"pick one, and read
it properly"*.

---

## 19. Component inventory for Sprint 08

`design_ui.md` §40 requires reusable widgets rather than UI inline in screens.

| Priority | Components |
| -------- | ---------- |
| **Build first** | `AppButton`, `AppTextField`, `SearchField`, `AppCard`, `MealCard`, `FilterChip`, `MetadataPill`, `EmptyState`, `ErrorState`, `AppSkeleton` |
| **Build second** | `CategoryCard`, `RouletteCard`, `AppBottomNav`, `AppBottomSheet`, `ConfirmationDialog`, `IngredientChip`, `GroceryRow`, `SectionHeader`, `AppSnackbar` |
| **Build with their feature** | `MatchIndicator`, `GroceryProgress`, `CoupleAvatars`, `InstructionStep`, `IngredientRow`, `CuisineChip` |

```text
core/widgets/
├── buttons/       app_button.dart, icon_button.dart
├── inputs/        app_text_field.dart, search_field.dart
├── cards/         app_card.dart, meal_card.dart, category_card.dart
├── chips/         filter_chip.dart, cuisine_chip.dart, ingredient_chip.dart, metadata_pill.dart
├── feedback/      empty_state.dart, error_state.dart, app_skeleton.dart, app_snackbar.dart
├── navigation/    app_bottom_nav.dart, app_app_bar.dart
├── overlays/      app_bottom_sheet.dart, confirmation_dialog.dart
└── indicators/    match_indicator.dart, grocery_progress.dart
```

---

## 20. Definition of done, per component

- [ ] Every value comes from a token; no literals
- [ ] Light and dark verified
- [ ] All states implemented: default, pressed, disabled, loading where applicable
- [ ] Touch target ≥ 48 × 48
- [ ] Semantic label present; icon-only controls always labelled
- [ ] Survives 1.3× text scale
- [ ] Reduce-motion path where it animates
- [ ] Widget test covering render and interaction
- [ ] Renders on a 320 px-wide screen
