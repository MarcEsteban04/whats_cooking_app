# 🍽️ What's Cooking?

> **No more "ikaw bahala."**

**What's Cooking?** decides what two people are eating tonight.

It is a **private app for one household of two** — Marc and his girlfriend. Not a
product, not a launch, no users to acquire. That single fact is the most important
thing in this document, because it changes what is worth building and what is
worth deleting.

---

# 🎯 The Problem

The conversation goes:

> "What's for dinner?"

> "You decide."

> "Anything is fine."

> "Pizza?"

> "I don't feel like pizza."

> "Then what do you want?"

> "I don't know."

Every day.

**What's Cooking?** replaces it with:

# Open → Spin → Decide → Eat.

---

# 💡 Core Concept

## 🎰 Let the app decide.

Two roulettes, over two libraries the household writes itself:

* **Cook something** — spin over the meals we know how to cook.
* **Eat out** — spin over the restaurants we actually go to.

Before spinning, either can be narrowed by budget, time, cuisine, mood and the
rest. After spinning, the answer is recorded so it does not come round again
tomorrow.

### Example

**Budget:** ₱300 a head
**Cooking time:** Under 45 minutes
**Mood:** Comfort food

### Result

> 🍗 **Chicken Adobo**
>
> ₱180 a head · ~35 minutes · 2 servings
>
> **[This is it] [Try again]**

Once accepted:

> ✅ **Dinner decided. No more "ikaw bahala."**

---

# 🚦 Scope

## What this app is

Six features. Everything in this document serves one of them.

| # | Feature | What it means |
| - | ------- | ------------- |
| 1 | **Meal roulette** | Spin over our own meals. Weighted, not random. |
| 2 | **Meals** | The library we write. Add, edit, favourite, hide. |
| 3 | **Pantry** | What is in the kitchen right now. |
| 4 | **Grocery** | What we need to buy, shared while one of us is at the shop. |
| 5 | **AI** | Ask in words. Generate a recipe. Read a fridge from a photo. |
| 6 | **Restaurant roulette** | Spin over our own list of places. |

**Both libraries are manually curated, and that is the design rather than a
shortcut.** A recommendation drawn from sixty meals somebody else chose is a
guess; a recommendation drawn from thirty meals we wrote down because we like
them and know how to cook them cannot be wrong about the food — only about
tonight. The bundled catalogue exists to make the app usable on day one and to
have something to spin before the library fills up. It is a starting point, not
the product.

## What this app is not

Cut, deliberately, because two people do not need them:

| Cut | Why |
| --- | --- |
| **Couple mode as a feature** | There is no partner to invite twice, no compatibility score to compute, no "can't agree" voting round. Two people in a kitchen can talk. What remains is the *plumbing*: one shared household so both phones see the same pantry, grocery list and history. |
| **Weekly meal planner** | We do not plan a week. We decide at seven in the evening — which is the entire premise of the roulette, and a planner is the opposite of it. |
| **Gamification** | Streaks and achievements are retention mechanics. There is no retention problem when the users are the developers. |
| **Food statistics** | An interesting dashboard nobody opens twice. Meal history already answers "what have we been eating". |
| **Smart notifications** | Two people who live together do not need to be pushed a reminder that it is nearly dinner. |
| **Monetization** | No. |
| **App Store / Play listing** | It installs on two phones. No store listing, no privacy policy, no screenshots, no review process. |
| **Restaurant *discovery*** | No maps, no ratings API, no location search. We know where we like to eat; the app spins over that list. |
| **Cooking mode** | Step-by-step recipe walkthrough. Genuinely nice, genuinely not one of the six. Recorded here so it is a decision rather than an omission. |
| **Guest mode / social login** | Two accounts, created once. |

**Row Level Security is not cut.** Supabase sits on the public internet whether
the app has two users or two million, and "only we use it" is not a security
model. Every policy stays.

---

# ✨ The Six

# 1. 🎰 Meal Roulette

The signature interaction, and the reason the app exists.

A spin is **weighted, not random**. The engine scores every candidate and then
draws from those scores, so the result feels like chance and never feels stupid.

What moves a score:

| Signal | Points |
| ------ | -----: |
| Mood match | ±35 |
| Favourite cuisine | +30 |
| Under budget | +20 (scaled by how far under) |
| Saved meal | +15 |
| Cuisine variety | ±10 |
| Fits the time we have | +10 (scaled) |
| Eaten recently | −15 (tapered) |

Plus one knob that matters more than any of them: a **temperature** that decides
how much the scores count at all. Lower it and the app becomes a menu that always
serves the optimum. Raise it and the scores stop mattering. It is what keeps
"weighted" from quietly becoming "ranked".

Three things are **not** scored, they are excluded outright, because a penalty
however large still produces the wrong answer eventually:

* A meal we hid.
* A meal containing a food we said we avoid.
* A meal eaten inside the repetition window.

### The no-match state

When nothing survives, the app says which constraint emptied the pool and offers
to drop the one that opens the most options — with the real number. It never
offers to relax a dietary need or an avoided ingredient.

---

# 2. 🍽️ Meals

The library. Ours, plus a starting catalogue.

Each meal carries:

* Name, description
* Cuisine, category, difficulty
* Ingredients with quantities
* Instructions
* Estimated cost, cooking time, servings
* Calories (optional)
* Tags — the vocabulary the moods read

Browse, search, filter and sort it. Save what we like. Hide what we do not.
**Write our own**, which is the point: the roulette is only as good as the
library, and the library is ours to grow.

### Meal history

Every accepted meal is recorded — what, when, which meal type, what it cost. That
record is what stops the roulette repeating itself, and it is the honest answer to
"what have we actually been eating".

---

# 3. 🏠 Pantry

What is in the kitchen, right now, shared between both phones.

```text
Chicken        1 kg
Eggs           6
Potatoes       500 g
Rice           2 kg
Garlic         1 bulb
Soy sauce      1 bottle
```

Items carry a quantity, a unit, and optionally an **expiry date** — which is the
half of a pantry that earns its keep, because the app can then say *use the
kangkong tonight* rather than waiting to be asked.

### Cook from what we have

The pantry feeds the roulette. Meals we can make now score higher; meals needing
one more thing are still offered, with the gap named.

> 🍗 **Chicken & Potato Adobo** — everything but the bay leaves

---

# 4. 🛒 Grocery

What we need to buy.

Built by hand, and built automatically: accept a meal, and anything it needs that
the pantry does not have lands on the list.

```text
🛒 Grocery

☐ Chicken       500 g
☐ Vinegar       1 bottle
☐ Bay leaves
☐ Black pepper
```

**Synchronised live between the two phones**, which is the one place realtime is
genuinely worth its complexity: one of us is standing in the shop and the other
is at home remembering something.

Duplicates combine. Two meals wanting chicken produce one line for 1.5 kg, not
two lines to puzzle over in an aisle.

---

# 5. 🤖 AI

Three things, in order of how much they are worth.

### Ask in words

> "What can we cook tonight?"

> "We only have chicken and eggs."

> "Something cheap, I don't want to cook for more than 20 minutes."

The assistant reads what the app already knows — the pantry, the budget, what we
have eaten lately, what we avoid — and answers with a meal from our library, or
tells us honestly that nothing fits.

### Generate a recipe

> "Make something from chicken, eggs and rice."

Name, ingredients, quantities, instructions, time. Saveable to the library, which
is how the library grows without typing.

### Read the fridge

A photo in, a list of ingredients out, into the pantry — **with a confirmation
step**, because image recognition is wrong often enough that silently trusting it
would poison the pantry and therefore the roulette.

### The rule

AI runs behind a Supabase Edge Function. **A provider key never goes in the
Flutter app**, where anybody with the APK can read it. Three providers in a chain,
so one being slow or down is not a dead feature.

---

# 6. 🍴 Restaurant Roulette

The other half of the question, and it deserves the same treatment as the first.

Some nights nobody is cooking. "Where should we eat?" is the same argument with
the same non-answer, so it gets the same solution: a list we wrote, and a spin.

Each place carries:

* Name
* Cuisine
* Roughly what a meal costs, a head
* How far — as *walk / short ride / worth the trip*, not kilometres
* Whether it delivers
* Notes, and what we order there
* Tags, so the moods work here too

```text
🍜 Ramen Nagi

Japanese · ₱450 a head · short ride
Delivers

"Get the Butao. Ask for extra chashu."
```

Spun, filtered and recorded exactly like meals: budget, cuisine, mood, distance,
and a repetition window so the roulette does not send us to the same place twice
in a week.

**Manually added, with no discovery layer.** No maps, no ratings, no location
search. A list of places we already like is better than every restaurant in the
city, and it does not need an API.

---

# 🎭 Mood

Both roulettes take a mood.

### The nine

🍔 Comfort Food
🍜 Craving
🥗 Healthy
🌶️ Spicy
🍕 Junk Food
🍱 Light Meal
💪 High Protein
💰 Cheap
🎲 Surprise Me

**A mood is a bias, never a filter.** It moves scores and hands the engine the
same pool it was given. As a filter, "healthy" over a small library would leave
three dishes to choose between for the rest of the month.

Each mood names what it leans *away* from as well as toward, and that half is
load-bearing: promoting three healthy meals out of sixty barely moves a weighted
draw, but pushing the deep-fried pork down at the same time does.

**"Surprise me" is a real mood, not the absence of one.** It favours nothing by
tag, rewards food we have never had, and raises the temperature so the draw
flattens toward genuine chance.

---

# 💰 Budget

A budget is set per head, not per pot, because that is the number both of us
actually think in.

### Presets

* ₱100
* ₱150
* ₱250
* Custom
* Any

Set once in preferences as the standing assumption, and overridable for one
evening from the filter sheet. Tightening it tonight must not silently change what
the app assumes next week.

Applied two ways at once: a **hard filter** on what may be offered, and a
**scaled bonus** on how far under it a meal comes in. A meal at half the budget is
a better answer to "we have ₱200" than one at ₱199.

---

# 📱 Screens

## Home

```text
WC  Tonight
    Marc Esteban's Kitchen ⌄

What are we eating tonight?
Let us decide for you.

BUDGET    COOKING FOR    READY IN
Any       2 people       Any

      [    SPIN    ]

      ⚙ Narrow it down
```

## Result

```text
TONIGHT'S PICK

🍗 Chicken Adobo

₱180 a head · 35 min · 2 servings

Filipino is one of your favourites

[ This is it ]
[ Try again ]  [ Details ]
      Not now
```

## The rest

| Screen | Holds |
| ------ | ----- |
| **Meals** | The library, browsable and searchable. Favourites, hidden, ours, recently eaten. |
| **Pantry** | What we have. Add, adjust, expiry. |
| **Grocery** | The list, live. |
| **Eat out** | The restaurant list, and its own spin. |
| **Profile** | Preferences, budget, dietary needs, avoided foods, effort, repetition window, appearance, account. |

---

# 🧱 Technical Architecture

| Layer | Technology |
| ----- | ---------- |
| Mobile | Flutter · Dart · Material 3 |
| State | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase — Postgres, Auth, Storage, Realtime, Edge Functions |
| AI | Three external providers, behind an Edge Function |
| Architecture | Feature-based / Clean Architecture |

```text
lib/
├── core/
│   ├── analytics/   constants/   domain/   errors/
│   ├── extensions/  network/     router/   theme/
│   ├── utils/       widgets/
│
├── features/
│   ├── auth/        onboarding/  home/      meals/
│   ├── roulette/    history/     pantry/    grocery/
│   ├── restaurants/ ai/          profile/
│
└── main.dart
```

## Backend rules

* **Row Level Security on every table.** Two users is not a security model.
* **The service-role key never reaches Flutter.** A startup assertion fails the
  first frame if one is compiled in.
* **No AI provider key in Flutter.** Same assertion, same reason.
* **Promises live in the query, not in client-side filtering.** A hidden meal, an
  avoided ingredient and a dietary need are excluded by the database, so no
  forgotten `.where` can break them.

---

# 🗄️ Database

Tables the six features need.

## Identity and sharing

```text
profiles            id · display_name · avatar_url
households          id · name · created_by
household_members   household_id · user_id · role
user_preferences    user_id · favorite_cuisines · dietary_tags
                    disliked_ingredient_names · disliked_ingredients
                    default_budget · max_cooking_time · max_difficulty
                    preferred_servings · repetition_window_days
```

## Meals

```text
meals               id · name · description · cuisine · category
                    difficulty · cooking_time_minutes · estimated_cost
                    cost_per_serving · servings · calories · instructions
                    dietary_tags · tags · is_public · household_id
ingredients         id · name · category · default_unit · is_staple
meal_ingredients    meal_id · ingredient_id · quantity · unit · is_optional
favorite_meals      user_id · meal_id
disliked_meals      user_id · meal_id
meal_history        household_id · meal_id · eaten_at · meal_type
                    estimated_cost · actual_cost · was_cooked · source
```

## Pantry and grocery

```text
pantry_items        household_id · ingredient_id · quantity · unit
                    expiration_date
grocery_lists       household_id · name
grocery_items       grocery_list_id · ingredient_id · quantity · unit
                    is_completed
```

## Restaurants

```text
restaurants         id · household_id · name · cuisine · cost_per_head
                    proximity · delivers · notes · go_to_order · tags
restaurant_history  household_id · restaurant_id · eaten_at · actual_cost
```

## Support

```text
ai_usage            user_id · provider · tokens · created_at
analytics_events    user_id · name · properties · occurred_at
```

`meal_plans` is **dropped**. There is no planner.

---

# 🎨 Design Direction

Fun. Modern. Fast. Minimal. Premium. Food-focused.

Not a calorie tracker. Not a nutrition app. Not a complicated
food-management system.

* **Ink on warm white, with one terracotta accent.** No green anywhere.
* **Monochrome icons.** No coloured glyphs, no emoji in the interface.
* **Typography and spacing for hierarchy**, not borders.
* **One full-colour thing in the whole app**: the logo.
* Reduced motion honoured everywhere. **Haptics are never suppressed** — they
  carry the satisfaction when animation cannot.

---

# 🎰 The Signature Interaction

```text
🍕 Pizza
      ↓
🍗 Chicken
      ↓
🍜 Ramen
      ↓
🍛 Curry
      ↓
🍝 Carbonara
      ↓
🍗 Chicken Katsu
```

A reel of real candidates rolls through a window — three cards visible, the
middle one being considered. It pulls back before it starts, runs fast, then
visibly slows. The card it lands on **is** the meal: the winner is planted at the
landing slot before the reel starts, because a reel that stops somewhere and then
shows something else is the version that feels rigged.

Tapping anywhere runs the remaining travel out fast. Suspense is a gift, not a
toll.

Light haptic on starting. A click per card as it slows. Medium on the reveal.
**Heavy when dinner is decided** — the loudest thing the app does, once.

> ❤️ **Tonight's dinner is decided.**

---

# 🧠 Product Philosophy

> ## **Less thinking. More eating.**

Every feature has to survive one question: *does this get us to dinner faster?*
The six do. The things in the cut list did not.

---

# 🏷️ Brand

## Name

# What's Cooking?

## Tagline

> **No more "ikaw bahala."**

## Alternatives

> **Spin. Decide. Eat.**

> **Dinner decided in seconds.**

> **Let us pick tonight.**

---

# 📊 The One Metric

There are no users to measure, no funnel, no retention curve. One number still
matters, because it is the whole promise:

## ⏱️ Time to Decision

From opening the app to knowing what we are eating.

### Goal:

> **Under 60 seconds.**

It is recorded on every accepted meal, measured from app open rather than from the
spin — the browsing and the filter-fiddling before the first tap are part of the
cost, and a measurement starting at the spin would flatter it.

Everything else the app records is diagnostic: how many spins it took, what
emptied the pool, how long the pick took against the animation.

---

# 🏁 Final Product Vision

Two roulettes, two libraries we wrote ourselves, a kitchen the app knows the
contents of, a grocery list that updates in the other person's hand, and an
assistant that can be asked in words.

Turning:

> **"We don't know what to eat."**

into:

> # **"What's Cooking? already decided." 🍽️🎰**
