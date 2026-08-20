# What's Cooking? — Complete UI/UX Design Prompt

Redesign the **entire What's Cooking? mobile application** using the provided visual reference as the primary design inspiration.

The reference demonstrates a premium, modern, minimal iOS-style mobile application with:

* Soft off-white backgrounds
* Large rounded cards
* Floating UI elements
* Generous whitespace
* Subtle shadows
* Clean typography
* Pill-shaped controls
* Rounded navigation
* Large visual hierarchy
* Minimal icons
* Soft pastel accents
* High-quality imagery
* Elegant micro-interactions

**Do not copy the healthcare content, text, layout, branding, or exact screens from the reference.**

Instead, translate its **visual language, spacing, proportions, card treatment, typography, and premium mobile aesthetic** into the **What's Cooking?** food decision-making application.

The result should feel like a polished, professionally designed App Store application rather than a generic Flutter UI.

---

# 1. Overall Design Direction

The visual identity should communicate:

**Premium + Playful + Minimal + Food-focused + Social**

The app should feel:

* Modern
* Friendly
* Premium
* Clean
* Warm
* Fun
* Effortless
* Slightly playful
* Highly polished

Avoid:

* Generic dashboard designs
* Excessive gradients
* Heavy borders
* Excessive shadows
* Dark interfaces by default
* Dense information layouts
* Excessive colors
* Traditional restaurant-app styling
* Cheap-looking illustrations
* Overly cartoonish UI

The application should feel closer to a **premium modern lifestyle app** than a traditional recipe or food-delivery app.

---

# 2. Color System

Use a very light warm background rather than pure white.

### Primary Background

Use an off-white / warm neutral such as:

`#F7F7F5`

or a similar extremely subtle warm gray.

### Surface

Cards should use:

`#FFFFFF`

### Primary Accent

> **Superseded.** The green below was removed from the app in Sprint 29 at the product
> owner's request. The palette is now warm near-black on warm white — interaction reads as
> **weight**, not hue — with a single terracotta accent, `#E8622A`, spent only on the SPIN
> button and the leading data series. DESIGN_SYSTEM §2.2 is the authority; this section is
> kept as the record of what was originally specified.

Use a sophisticated food-inspired green as the primary brand accent.

Suggested direction:

`#3FA66B`

The green should be used sparingly for:

* Primary actions
* Selected states
* Success states
* Important labels
* Progress indicators
* Small decorative elements

### Secondary Accents

Use very subtle pastel colors:

* Soft peach
* Pale yellow
* Soft mint
* Very light lavender
* Muted coral

These should primarily appear in:

* Category cards
* Food tags
* Meal illustrations
* Small badges
* Decorative backgrounds

Do not make the interface overly colorful.

---

# 3. Typography

Use a modern, highly readable sans-serif font.

Prefer:

* SF Pro Display / SF Pro Text on iOS
* Inter as a cross-platform fallback

Typography should have strong hierarchy.

### Large Headlines

Bold or semibold.

Example:

> Good evening, Marc 👋

### Section Titles

Medium/semibold.

Example:

> What are we eating tonight?

### Supporting Text

Muted gray.

Example:

> Pick something based on your mood.

### Metadata

Small, clean, muted typography.

Example:

> 30 min · ₱220 · 2 servings

Avoid excessive font weights.

The interface should use typography and spacing instead of borders to establish hierarchy.

---

# 4. Border Radius

Use generous rounded corners throughout the application.

Suggested:

* Small components: 12–16px
* Buttons: 16–20px
* Cards: 20–28px
* Large feature cards: 28–32px
* Bottom sheets: 28–32px

The UI should feel soft and approachable.

---

# 5. Shadows

Use extremely subtle shadows.

Cards should appear elevated without looking heavy.

Example visual direction:

```text
Very low opacity
Large blur
Large spread
Soft elevation
```

Avoid:

* Hard shadows
* Dark shadows
* Strong outlines
* Neumorphism

The reference's floating-card aesthetic should be reproduced with subtle elevation.

---

# 6. Spacing

Use generous spacing.

The interface should breathe.

Prefer:

* 20–24px screen margins
* 12–20px between cards
* 16–24px internal card padding
* Large spacing between sections

Do not cram information onto the screen.

---

# 7. Navigation

Use a floating rounded bottom navigation bar inspired by the reference.

The navigation should be a rounded capsule/floating container rather than a traditional full-width Material navigation bar.

Suggested tabs:

### 🏠 Home

Main meal decision experience.

### 🍽️ Meals

Browse and search meals.

### 🗓️ Planner

Weekly meal planning.

### 🛒 Grocery

Shared grocery list.

### 👤 Profile

Profile, preferences, household, and settings.

The selected tab should have a subtle filled/active treatment.

Keep icons simple and recognizable.

---

# 8. Home Screen

The Home screen is the most important screen.

It should immediately communicate:

> **What's cooking?**

Use a layout inspired by the reference's doctor-search home screen, but completely adapted to food.

---

## Header

Display:

> Good evening, Marc 👋

Underneath:

> ❤️ Cooking with Princess

or:

> 👤 Just cooking for yourself

On the right:

* Notification icon
* Profile avatar

Use a small circular profile image.

---

# 9. Search / Quick Search

Below the header, add a large rounded search field.

Placeholder:

> Search meals, ingredients, or cuisines

Include a subtle search icon.

The field should have:

* White surface
* Rounded corners
* Minimal border
* Very subtle shadow

---

# 10. Quick Categories

Create a grid of soft rounded category cards.

Example:

```text
🍗              🍜              🍝

Chicken        Asian           Pasta


🍚              🥗              🎲

Rice            Healthy        Surprise
```

Each category should have:

* Small food icon or illustration
* Category name
* Very subtle pastel background

The cards should feel similar to the reference's specialty cards.

Do not use loud saturated colors.

---

# 11. Main Roulette Card

This is the visual centerpiece of the home screen.

Create a large premium rounded card.

Example:

> 🎰
> **What are we eating tonight?**
>
> Let us decide for you.
>
> Budget: ₱300 · 2 people
>
> **SPIN**

The **SPIN** button should be the strongest call-to-action on the entire home screen.

The card can contain a beautiful food image or subtle abstract food imagery.

---

# 12. Roulette Interaction

When the user taps **SPIN**, create a polished animated experience.

The interface should cycle through meal cards quickly.

Example:

```text
🍕 Pizza
↓
🍜 Ramen
↓
🍗 Chicken
↓
🍝 Carbonara
↓
🥘 Curry
↓
🍣 Sushi
```

Slow down the animation.

Then reveal the final meal.

Use:

* Haptic feedback
* Smooth spring animations
* Scale transitions
* Blur/fade effects
* Subtle particle/confetti effect

Do not make it look like a casino slot machine.

It should feel elegant and premium.

---

# 13. Meal Result Screen

The result should feel like a reward.

Large food image at the top.

Below:

> ## Chicken Katsu

Then:

> ⭐ Loved by both of you

Metadata:

> ₱220
> 30 min
> 2 servings

Use small rounded pills.

Example:

```text
₱220      30 min      2 servings
```

Then:

### Primary button

> ❤️ This is it

### Secondary action

> 🎲 Try Again

The result screen should make accepting a meal feel satisfying.

---

# 14. "Dinner Decided" State

After accepting:

Display a celebratory confirmation.

Example:

> 🎉 Dinner decided!
>
> **Chicken Katsu**
>
> You're eating this tonight.

Show:

* Meal image
* Time
* Estimated cost
* Ingredients
* Recipe button

Actions:

> **Start Cooking**

> **Add Ingredients to Grocery**

---

# 15. Meal Discovery Screen

The Meals screen should look like a premium food discovery feed.

Use:

* Large food cards
* Rounded images
* Minimal metadata
* Category filters
* Search

Example card:

```text
┌──────────────────────────────┐
│                              │
│        FOOD IMAGE            │
│                              │
└──────────────────────────────┘

Chicken Katsu
Japanese · 30 min

₱220

❤️
```

Cards should use large visual imagery.

Food photography should be realistic, appetizing, and professionally styled.

---

# 16. Filter UI

Filters should use horizontal pill-shaped controls.

Examples:

```text
All
Filipino
Asian
Quick
Healthy
Budget
Favorites
```

Selected filters use the interactive ink fill (there is no green — see the note in §2).

Unselected filters should remain neutral white/gray.

---

# 17. Meal Details

> **Built without the image.** There is no meal photography in the app, so the screen keeps
> this section's hierarchy and drops its top image: the name sits where the photograph would
> have been at display size, the `Filipino · Easy · 45 min` line runs beneath it, cost is the
> hero figure, ingredients are the two-column list described below, and the steps are the
> large numbered ones. Back and favourite still float at the top, joined by the hide control
> from Sprint 25 and — on a meal you wrote — edit and delete at the foot (Sprint 26). See
> COMPONENTS §4 for why there is no imagery and what restoring it would cost.

Create a large immersive meal-detail screen.

Top:

Large edge-to-edge rounded food image.

Overlay:

Back button
Favorite button

Below:

> Chicken Adobo

Then:

> Filipino · Easy · 35 min

Show estimated cost prominently.

---

## Ingredients

Use clean ingredient cards.

Example:

```text
Chicken              500g
Soy Sauce             3 tbsp
Vinegar               2 tbsp
Garlic                4 cloves
```

---

## Instructions

Use large numbered steps.

```text
01

Marinate the chicken...


02

Heat the pan...


03

Add the sauce...
```

---

# 18. What's In The Fridge?

Create a visually distinct pantry screen.

Header:

> What's in the fridge?

Subtitle:

> Add what you have and we'll find something to cook.

Display ingredients as rounded chips/cards.

Example:

```text
Chicken
Eggs
Rice
Potatoes
Garlic
Onion
```

Primary action:

> **Find Meals**

---

# 19. Ingredient Match

When searching for meals using pantry ingredients, show match percentages.

Example:

### Chicken Adobo

**100% available**

### Chicken Fried Rice

**90% available**

### Chicken Curry

**70% available**

Use a subtle progress indicator.

---

# 20. Couple Mode

The Couple screen should feel warm and personal.

Header:

> ❤️ Our Kitchen

Show both avatars.

Example:

```text
      👤 ❤️ 👤
    Marc & Princess

    87% Food Match
```

Below:

### Shared Favorites

Display favorite meal cards.

### Recently Eaten

Show recent shared meals.

### Our Preferences

Display small tags:

```text
🍗 Chicken
🍜 Asian
🌶️ Mild Spice
💰 Budget Friendly
```

---

# 21. Can't Agree Mode

Design this as a fun interaction.

Header:

> Can't agree?

Subtitle:

> You both pick. We'll find the match.

Display meal cards one at a time.

Buttons:

❌ Pass

❤️ Like

Once both users have voted, show:

> 🎉 You both picked it!

Then reveal the winning meal.

---

# 22. Weekly Planner

Use a clean calendar interface.

Header:

> This Week

Display each day as a rounded card.

Example:

```text
MON
Chicken Adobo

TUE
Carbonara

WED
Sinigang

THU
Chicken Katsu
```

Each meal should use a small food image.

Allow users to tap a day to:

* Add meal
* Replace meal
* Remove meal

---

# 23. Grocery Screen

Use a minimal shared checklist.

Header:

> 🛒 Grocery List

Show progress:

> 6 of 10 items completed

Each item should be a rounded row.

Example:

```text
○ Chicken
○ Garlic
✓ Soy Sauce
✓ Onion
○ Vinegar
```

Completed items should visually fade rather than disappear immediately.

---

# 24. Grocery Sharing

Show subtle realtime status.

Example:

> ❤️ Princess is shopping

or:

> Updated just now

This makes the household experience feel collaborative.

---

# 25. Profile Screen

Use a clean profile layout inspired by the reference.

Top:

Circular avatar

> Marc Esteban

> Food Explorer · 32 meals

Then cards:

### My Preferences

Favorite cuisines
Disliked foods
Dietary preferences

### Household

❤️ Our Kitchen

### Budget

₱300 default meal budget

### Statistics

32 meals tried
24 cooked
8 ordered

### Settings

Notifications
Appearance
Privacy
Account

---

# 26. Statistics

Keep analytics visually simple.

Use small floating cards.

Example:

```text
🍽️
32
Meals Tried
```

```text
💰
₱187
Average Meal
```

```text
👨‍🍳
24
Meals Cooked
```

```text
❤️
87%
Couple Match
```

Avoid creating a complicated analytics dashboard.

---

# 27. AI Assistant

The AI screen should feel like a premium conversational assistant.

Header:

> What should we eat?

Conversation example:

> **You**
>
> I only have chicken, eggs, and rice.

> **What's Cooking?**
>
> You can make several meals with those ingredients.
>
> My pick:
>
> 🍗 Chicken Fried Rice
>
> 20 min · ~₱120
>
> **[Let's Cook]**

Use large rounded chat bubbles.

Keep the interface minimal.

---

# 28. AI Fridge Scanner

Create a camera/upload interface.

Header:

> Scan your fridge

Subtitle:

> We'll figure out what you can cook.

After scanning:

> We found 7 ingredients.

Display detected ingredients as editable chips.

Example:

```text
Chicken ✓
Eggs ✓
Tomatoes ✓
Milk ✓
Cheese ✓
```

Allow users to remove incorrect detections.

Button:

> **Find Meals**

---

# 29. Empty States

Empty states should be visually beautiful and friendly.

Example:

### No Favorites

> 🍽️ Nothing saved yet.
>
> Spin the wheel and find something you love.

Button:

> **What's Cooking?**

---

# 30. Loading States

Avoid generic full-screen loading indicators.

Use:

* Skeleton cards
* Shimmer effects
* Placeholder food images
* Subtle animations

The UI should maintain its layout while content loads.

---

# 31. Error States

Errors should be friendly.

Instead of:

> `Exception: PostgrestException`

Display:

> Hmm, something went wrong.
>
> We couldn't load your meals right now.

Button:

> **Try Again**

Never expose technical errors to normal users.

---

# 32. Animations

Use tasteful animations throughout the application.

Recommended:

* Spring-based card transitions
* Fade transitions
* Scale transitions
* Hero animations
* Bottom-sheet transitions
* Haptic feedback
* Roulette animation
* Favorite heart animation
* Grocery checkbox animation

Animations should feel:

**Smooth → Fast → Natural**

Avoid excessive animation.

---

# 33. Food Photography

> **Not implemented, and not scheduled.** The app ships no food imagery at all — see
> COMPONENTS §4. This section stands as the brief for the day it does, not as a description
> of anything in the build. Nothing here is a placeholder that got missed.

Food imagery should be one of the strongest visual elements.

Use:

* High-quality food photography
* Natural lighting
* Clean backgrounds
* Close-up compositions
* Appetizing presentation
* Consistent image ratios

Avoid:

* Low-quality stock images
* Cartoon food graphics as the primary imagery
* Inconsistent photography styles

---

# 34. Cards

Cards are a major component of the design language.

Use:

* White surfaces
* Large rounded corners
* Soft shadows
* Generous internal padding
* Minimal borders

Cards should visually float above the warm background.

---

# 35. Floating UI

Use floating elements inspired by the reference.

Examples:

* Floating notification cards
* Floating meal metadata
* Floating budget badges
* Floating recommendation labels
* Floating status indicators

These should overlap cards subtly and create depth.

Do not overuse this effect.

---

# 36. Buttons

Primary buttons should be large, rounded, and highly tactile.

Example:

> **What's Cooking?**

Use dark text or white text depending on contrast.

Primary CTA should have:

* 52–58px height
* Rounded corners
* Semibold typography
* Subtle press animation

Secondary actions should be quieter.

---

# 37. Bottom Sheets

Use rounded top corners.

Bottom sheets should be used for:

* Filters
* Budget selection
* Cuisine selection
* Meal preferences
* Add ingredients
* Add grocery items
* Household actions

Avoid navigating to a separate screen for every small configuration.

---

# 38. Responsive Layout

Although the primary target is mobile, the Flutter implementation should remain responsive.

Support:

* Small phones
* Standard phones
* Large phones
* Tablets where appropriate

Avoid hard-coded screen dimensions.

Use:

* Flexible layouts
* SafeArea
* MediaQuery
* LayoutBuilder
* Responsive spacing

---

# 39. Accessibility

Maintain:

* Readable font sizes
* Strong text contrast
* Accessible touch targets
* Semantic labels
* Screen-reader support
* Reduced-motion consideration

Do not sacrifice accessibility for aesthetics.

---

# 40. Flutter Implementation Guidelines

The UI should be implemented using reusable Flutter widgets.

Avoid putting large amounts of UI directly inside individual screens.

Example architecture:

```text id="g3v1ub"
features/
└── roulette/
    ├── data/
    ├── domain/
    ├── presentation/
    │   ├── screens/
    │   ├── widgets/
    │   └── providers/
    └── roulette.dart
```

Reusable design components should be centralized where appropriate.

---

# 41. Supabase Integration

The design must work naturally with the existing Supabase architecture.

UI states must account for:

* Loading
* Success
* Empty
* Error
* Offline
* Authentication expired
* Realtime updates

Do not build static mock interfaces that cannot realistically connect to the backend.

---

# 42. Important Design Rule

The reference image is a **visual inspiration**, not a template to copy.

Do NOT reproduce:

* Doctor profiles
* Healthcare terminology
* Medical categories
* Appointment cards
* Doctor maps
* Healthcare-specific icons
* Exact text
* Exact layouts
* Exact branding

Instead, preserve the visual principles:

> **Soft background + floating white cards + generous whitespace + premium typography + rounded components + subtle shadows + strong imagery + elegant navigation.**

Translate those principles into the food domain.

---

# 43. Overall Visual Hierarchy

Every screen should have:

### 1. One clear primary action

Example:

> **What's Cooking?**

### 2. One clear headline

Example:

> **What are we eating tonight?**

### 3. Supporting information

Example:

> ₱300 · 2 people · 30 minutes

### 4. Secondary actions

Example:

> Try Again
> View Recipe
> Add to Grocery

Do not overwhelm users with too many competing buttons.

---

# 44. Desired Final Feeling

When users open the app, the immediate impression should be:

> **“Wow, this looks premium.”**

After using the roulette:

> **“That was fun.”**

After using couple mode:

> **“This actually solves our problem.”**

After using pantry and grocery:

> **“This is actually useful.”**

The product should feel like a polished lifestyle application that people would proudly keep on their home screen.

---

# 45. Final Design Direction

Use the uploaded reference image as the **primary visual inspiration** for the entire application.

Translate its:

* Minimalism
* Whitespace
* Soft neutral background
* Rounded cards
* Floating elements
* Subtle shadows
* Premium typography
* Pill controls
* Large imagery
* Elegant navigation
* iOS-inspired proportions
* Clean visual hierarchy

into the **What's Cooking?** product.

The final application should look like:

# **A premium food lifestyle app designed by a professional product design team.**

Not a generic Flutter application.

Not a basic recipe app.

Not a restaurant delivery clone.

Not a dashboard.

It should be:

# 🍽️ **What's Cooking?**

### **No more “ikaw bahala.”**

**Spin. Decide. Eat.**
