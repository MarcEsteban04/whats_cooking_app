# What's Cooking? — MVP Scope

| Field | Value |
| ----- | ----- |
| **Release** | 1.0 |
| **Status** | Approved — Sprint 02 |
| **Covers** | Sprints 01–34 (core), 41–47 (couple), 48–53 (pantry & grocery), 64–70 (ship) |
| **Related** | [PRD.md](PRD.md) · [project_dev.md](project_dev.md) |

This is the cut line. If a request is not in section 2, it is out — regardless of how small
it looks. Changes to this document require an explicit scope decision, recorded in
section 7.

---

## 1. The one hypothesis

> **Can What's Cooking? reliably help people decide what to eat faster than they otherwise
> would — and will they come back to it?**

Every item below earns its place by supporting that test. The MVP is not "version 1.0 minus
polish"; it is the smallest product that can honestly answer the question.

**The single test that matters:** a user opens the app and, in under 60 seconds, accepts a
meal they are happy to eat.

---

## 2. In scope

### 2.1 Authentication and onboarding — *Sprints 16–20*

| Included | Notes |
| -------- | ----- |
| Email/password sign-up and login | Supabase Auth |
| Session persistence | Returning users land on Home, not on login |
| Password recovery | Email reset flow |
| Onboarding preferences | Cuisines, dislikes, dietary preferences, default budget, max cooking time — all skippable |
| Profile | Display name, avatar, editable preferences |
| Logout and account deletion | Deletion is a trust and compliance requirement |

### 2.2 Meal system — *Sprints 21–27*

| Included | Notes |
| -------- | ----- |
| Seeded meal catalogue | Breadth over depth; Filipino-leaning, plus Japanese, Korean, Chinese, Italian, Mexican, American |
| Browse feed with pagination | |
| Text search | Name and ingredient |
| Filters | Cuisine, category, cooking time, budget, difficulty |
| Meal detail screen | Image, description, ingredients, cost, time, difficulty, servings, instructions |
| Favourites | Add, remove, dedicated list |
| Dislikes | Add, remove, excluded from recommendations |
| Custom meals | Full create with ingredients, instructions, cost, time, category, image |

### 2.3 The roulette — *Sprints 28–34* — **the product**

| Included | Notes |
| -------- | ----- |
| Spin interaction | Animated cycling, deceleration, reveal, haptics |
| Pre-spin filters | Budget, cuisine, category, cooking time, difficulty, meal type |
| Randomised selection | Excludes dislikes and dietary violations as hard filters |
| Repetition prevention | Recently eaten meals heavily down-weighted |
| Weighted scoring engine | Preference, budget, ingredient, partner, favourite, variety, time, recency |
| Accept | Writes to meal history and closes the decision |
| Try Again | Unlimited re-spins |
| No-match state | Explains the blocking constraint and offers the most relaxable filter |

**This is the feature the MVP exists to test. If a sprint slips, it slips somewhere else.**

### 2.4 Meal history — *Sprint 31*

Recording of accepted meals with date, meal type, cost and household; a recently-eaten view;
and history feeding the repetition-prevention logic.

### 2.5 Couple mode — *Sprints 41–47*

| Included | Notes |
| -------- | ----- |
| Create household | Name, owner |
| Invite partner | Code or link |
| Accept / decline invitation | |
| Remove member, leave household | |
| Shared meal history | Household-scoped |
| Shared favourites | Visible to both |
| Per-member private preferences | Individual likes and dislikes preserved |
| Couple-aware recommendations | Both partners' exclusions and favourites scored |
| Can't Agree voting | Both vote, app surfaces the match — **P1, first to be cut** |

### 2.6 Pantry and grocery — *Sprints 48–53*

| Included | Notes |
| -------- | ----- |
| Add, edit, remove pantry ingredients | With quantity and unit |
| Ingredient search and categories | |
| Ingredient matching | Meals ranked by percentage of ingredients owned |
| *Find Meals* from pantry | |
| Grocery list | Create, add, edit, delete, check off, clear completed |
| Auto-generate missing ingredients | Selected meal minus pantry contents, one tap |

### 2.7 Cross-cutting requirements

Non-negotiable, and part of every feature's Definition of Done:

* **Four UI states everywhere** — loading (skeletons, not spinners), empty, error, data.
* **Friendly errors** — no raw exception text ever reaches a user.
* **Row Level Security** on every table, tested against unauthorised access.
* **Light and dark theme.**
* **Responsive** from small phones to tablets.
* **Accessibility** — 48dp touch targets, semantic labels, readable contrast.
* **Analytics for the north-star metric** — time to decision must be measurable from day one.
* **Crash reporting.**

---

## 3. Out of scope for MVP

Deferred deliberately. Each has a target version.

| Excluded | Target | Reason |
| -------- | ------ | ------ |
| AI meal assistant | 2.0 | Expensive, and the scoring engine must prove itself first |
| AI recipe generation | 2.0 | Depends on AI infrastructure |
| AI fridge scanner | 2.0 | High cost, unproven accuracy, not required by the hypothesis |
| Weekly meal planner | 1.3 | Planning is a different job than deciding tonight |
| Automatic meal planning and ingredient reuse | 1.3 | Depends on the planner |
| Realtime sync (Supabase Realtime) | 1.1 | Pull-to-refresh is sufficient to test the hypothesis |
| Push notifications | 1.2 | Retention lever, not a validation lever |
| Gamification, streaks, achievements | 1.2+ | Engagement mechanics before product-market fit are noise |
| Advanced statistics dashboards | 1.2 | Simple counts only at MVP |
| Budget tracking across day/week | 1.2 | Per-meal budget only at MVP |
| Pantry expiration tracking and alerts | 1.2 | Adds data-entry burden to an unproven feature |
| Cooking mode (step-by-step) | 1.1 | Meal detail instructions suffice at MVP — **P1, may land if time allows** |
| Mood-based recommendations | 1.1 | **P1**; scoring engine supports it, UI may slip |
| Third-party sign-in (Google, Apple) | Never (see PRD non-goals) | **Cut at Sprint 18.** Worth naming the consequence: App Store Guideline 4.8 compels Sign in with Apple only when *another* third-party provider is offered. Email-only removes that obligation outright. |
| Restaurant mode, delivery mode | Later | Different product |
| Group mode beyond a household | Later | Voting logic does not generalise for free |
| Subscriptions, payments, premium tier | Later | Nothing to monetise until retention is proven |
| Web or desktop clients | Never (see PRD non-goals) | Mobile-only by design |
| Offline-first sync engine | Never | Cached reads and degraded states only |

---

## 4. Priority ladder

If the schedule compresses, cut from the bottom.

| Tier | Contents | Cut policy |
| ---- | -------- | ---------- |
| **T0 — Cannot ship without** | Auth, onboarding preferences, meal catalogue, meal detail, **roulette + filters + scoring**, accept, meal history, dislikes, favourites | Never cut. These *are* the hypothesis. |
| **T1 — Ship with, strongly preferred** | Household create + invite, couple-aware scoring, shared history, pantry, ingredient matching, grocery list, auto-missing-ingredients, custom meals | Cut only to protect T0 quality |
| **T2 — First to go** | Can't Agree voting, cooking mode, mood filters, guest mode, statistics, avatar upload | Cut freely; each has a clean v1.1 home |

**Rule:** a polished T0 beats a complete T0+T1+T2 that feels unfinished. The roulette must
feel excellent, not merely functional — it is the product's only memorable moment.

---

## 5. MVP acceptance checklist

The MVP is complete when a user can do all of the following without a critical bug:

- [ ] Create an account and log in
- [ ] Complete onboarding and set preferences
- [ ] Browse and search meals
- [ ] View full meal details
- [ ] Favourite a meal
- [ ] Dislike a meal and never see it recommended again
- [ ] Add a custom meal
- [ ] Set a budget and cooking-time filter
- [ ] Spin the roulette and receive a result respecting every hard filter
- [ ] Re-spin and get a different result
- [ ] Accept a meal and see it recorded in history
- [ ] Not be recommended a meal eaten in the last few days
- [ ] Create a household
- [ ] Invite a partner and have them join
- [ ] Receive a recommendation respecting both partners' exclusions
- [ ] Add ingredients to the pantry
- [ ] Find meals ranked by pantry match percentage
- [ ] Generate a grocery list of missing ingredients
- [ ] Check items off the grocery list
- [ ] Use the app on Android and iOS, light and dark, without crashing

Plus the measurable bar:

- [ ] Median time to decision under 60 seconds in beta
- [ ] Acceptance rate above 40%
- [ ] Crash-free sessions above 99.5%
- [ ] Zero open P0 defects

---

## 6. Explicitly deferred decisions

These do **not** block the MVP and must not be debated during it: monetisation and pricing,
premium feature boundaries, i18n and localisation, referral or growth mechanics, an admin or
content-management tool, and community or user-generated content moderation.

---

## 7. Scope change log

Any addition to or removal from section 2 is recorded here with a reason.

| Date | Change | Reason | Decided by |
| ---- | ------ | ------ | ---------- |
| Sprint 02 | Initial scope defined | Baseline | Marc Esteban |
| Sprint 18 | **Removed** Google Sign-In from scope; Apple Sign-In moved from deferred to out of scope | Each provider costs an external console, platform-specific secrets and its own failure mode, and buys a few seconds once per user. Sprint 18 is now Onboarding Preferences. | Marc Esteban |
