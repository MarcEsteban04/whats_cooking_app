# What's Cooking? — Product Requirements Document

| Field | Value |
| ----- | ----- |
| **Product** | What's Cooking? |
| **Version** | 1.0 (MVP) |
| **Status** | Approved — Sprint 02 |
| **Owner** | Marc Esteban |
| **Last updated** | Sprint 02 |
| **Related** | [app_feature.md](app_feature.md) · [project_dev.md](project_dev.md) · [design_ui.md](design_ui.md) · [MVP_SCOPE.md](MVP_SCOPE.md) |

This document defines **what** What's Cooking? must accomplish and **how success is
measured**. `app_feature.md` describes the product vision and feature surface;
`project_dev.md` sequences the build. This document is the contract between them: it
states the problem, the users, the required behaviour, the explicit non-goals, and the
numbers that decide whether the product worked.

---

## 1. Problem statement

Deciding what to eat is a small decision made with high frequency under low energy.

For a household of two, dinner is decided roughly **365 times a year**. The decision
happens at the worst possible moment — end of day, hungry, tired, decision-fatigued —
and it is a *negotiation*, not a choice. The conversation is well known:

> "What's for dinner?" → "You decide." → "Anything is fine." → "Pizza?" →
> "I don't feel like pizza." → "Then what do you want?" → "I don't know."

### Why it stays unsolved

| Existing tool | Why it fails this problem |
| ------------- | ------------------------- |
| Recipe apps | Optimised for **browsing**, which *adds* decisions. You arrive undecided and leave overwhelmed. |
| Delivery apps | Infinite scroll is the decision problem, monetised. Also expensive and cooking-hostile. |
| Meal planners | Demand upfront planning effort. They solve *organisation*, not *in-the-moment indecision*. |
| Nutrition trackers | Solve a different problem entirely, and add a daily logging burden. |
| Asking your partner | The negotiation itself is the cost. |

**None of them decide for you, and none of them account for two people.**

### Consequences

* 15–30 minutes lost per decision.
* Low-grade recurring friction between partners.
* Default to delivery — higher spend than intended.
* Ingredients already bought spoil unused.
* The same five meals on rotation out of decision fatigue.

### Our claim

> The problem is not a lack of options. It is **the burden of choosing**.
>
> The solution is not more information. It is **a decision, made for you, that you trust.**

---

## 2. Target users

### Primary persona — **The Couple**

> **Marc & Princess**, 24–32, living together, both working.

| | |
| --- | --- |
| **Context** | Decide dinner together most weeknights. Both tired by 6pm. |
| **Frustration** | "Ikaw bahala" every single night. Neither wants to be the one who decides. |
| **Current behaviour** | 20 minutes of back-and-forth, then delivery out of exhaustion. |
| **Wants** | Something neither of them has to own the blame for. |
| **Success looks like** | Dinner decided in under a minute, both happy, no negotiation. |

**This persona drives every product decision.** Where personas conflict, the Couple wins.

### Secondary personas

**The Solo Cook** — 22–35, lives alone. Cooks for one, tired of the same rotation, wastes
food buying for recipes then losing motivation. Wants variety without planning, and
portions that make sense for one.

**The Roommates** — 3–5 sharing a flat and a kitchen. Need a *shared* grocery list that
doesn't live in a group chat, and fair rotation of who eats what.

**The Budget Student** — 18–24, hard ceiling per meal, cooks to save money. Budget is the
primary filter, not a preference. Needs to know cost *before* committing.

### Non-users

We are explicitly **not** building for professional chefs, food bloggers, competitive
athletes on macro plans, or people on medically supervised diets. Dietary restrictions are
supported as **preferences and exclusions**, not as clinical guarantees.

---

## 3. Value proposition

> **What's Cooking? decides what you're eating tonight, in under a minute, in a way you'll actually accept.**

Three things make this defensible:

1. **It decides, it doesn't browse.** The primary action is a single button. The output is
   *one* meal, not a list. Everything else in the app exists to make that one meal better.
2. **It understands two people.** The recommendation accounts for both partners'
   preferences, dislikes and shared history — so the answer arrives pre-negotiated.
3. **It feels random but is never stupid.** Constrained randomness supplies the fun and
   the blame-free outcome; the scoring engine supplies the credibility.

Users forgive a mediocre suggestion. They do not forgive a suggestion that ignores what
they just ate, what they can't eat, or what they can't afford.

---

## 4. Product principles

Ranked. When two conflict, the higher one wins.

1. **Decide, don't browse.** Every screen either produces a decision or supports one. If a
   feature adds a choice without removing a bigger one, it does not ship.
2. **Speed beats completeness.** Under 60 seconds to a decision. A fast good answer beats a
   slow perfect one.
3. **Never feel stupid.** Randomness is the feel; scoring is the floor. Recommending
   yesterday's dinner, a disliked meal, or something over budget is a product bug.
4. **Two people by default.** Couple support is core architecture, not a feature flag.
5. **Fun is a feature.** The spin is the product's memory. It must feel good every time.
6. **Respect the wallet.** Cost is always visible before commitment.
7. **Never expose the machine.** No raw exceptions, no jargon, no empty grey screens.

---

## 5. User stories

Format: `US-<epic>-<n>` · **As a** \<persona\>, **I want** \<capability\>, **so that**
\<outcome\>. Priority: **P0** = MVP blocker · **P1** = MVP if time · **P2** = post-MVP.

### Epic A — Onboarding & Account

| ID | Story | Priority |
| -- | ----- | -------- |
| US-A-01 | As a new user, I want to try the roulette before creating an account, so that I can see the value before committing. | P1 |
| US-A-02 | As a new user, I want to sign up with an email and password, so that I can start in under 30 seconds. | P0 |
| US-A-03 | As a new user, I want to state my favourite cuisines and foods I avoid, so that my first recommendation is already relevant. | P0 |
| US-A-04 | As a new user, I want to set a default budget and max cooking time, so that I don't re-enter them nightly. | P0 |
| US-A-05 | As a returning user, I want to stay logged in, so that opening the app goes straight to deciding. | P0 |
| US-A-06 | As a new user, I want to skip onboarding questions, so that impatience doesn't cost me the app. | P1 |

**US-A-03 acceptance criteria**

* **Given** I have just registered, **when** onboarding starts, **then** I am asked for
  favourite cuisines, disliked foods, dietary preferences, default budget and max cooking
  time — each skippable.
* **Given** I select "avoids fish", **when** I first spin, **then** no meal containing fish
  as a primary ingredient can be returned.
* **Given** I skip every question, **when** I first spin, **then** I still receive a valid
  recommendation drawn from the unfiltered catalogue.

### Epic B — The Roulette *(the product)*

| ID | Story | Priority |
| -- | ----- | -------- |
| US-B-01 | As a hungry user, I want to tap one button and be told what to eat, so that I stop deciding. | P0 |
| US-B-02 | As a user, I want the spin to be animated and satisfying, so that deciding feels fun instead of like a chore. | P0 |
| US-B-03 | As a user, I want to set budget, cooking time and cuisine before spinning, so that the result is achievable tonight. | P0 |
| US-B-04 | As a user, I want to re-spin if I don't like the result, so that I never feel trapped by the app. | P0 |
| US-B-05 | As a user, I want to accept a meal, so that the decision is recorded and closed. | P0 |
| US-B-06 | As a user, I want the app to avoid suggesting what I ate in the last few days, so that it feels like it's paying attention. | P0 |
| US-B-07 | As a user, I want disliked meals never suggested, so that I trust the results. | P0 |
| US-B-08 | As a user, I want to pick a mood (comfort / healthy / cheap / surprise), so that the result matches how I feel. | P1 |
| US-B-09 | As a user, I want to see estimated cost and time on the result, so that I can commit with confidence. | P0 |

**US-B-01 acceptance criteria**

* **Given** the app is open, **when** I tap SPIN, **then** a single meal is revealed within
  3 seconds of animation.
* **Given** a result is shown, **when** I read it, **then** name, estimated cost, cooking
  time and servings are all visible without scrolling.
* **Given** I have set filters, **when** a result is revealed, **then** it satisfies every
  hard filter (budget, time, dietary exclusion) or the app explains why no meal matched.
* **Given** no meal satisfies my filters, **when** I spin, **then** I see a friendly
  explanation and the single most-relaxable filter is offered for adjustment — never an
  empty screen.

**US-B-06 acceptance criteria**

* **Given** I ate Chicken Adobo yesterday, **when** I spin, **then** its selection
  probability is materially reduced, not merely re-ranked.
* **Given** the eligible pool is smaller than the repetition window, **when** I spin,
  **then** a repeat is allowed rather than returning nothing.

### Epic C — Meals

| ID | Story | Priority |
| -- | ----- | -------- |
| US-C-01 | As a user, I want to browse and search meals, so that I can explore when I'm in the mood to. | P0 |
| US-C-02 | As a user, I want to filter by cuisine, category, time and budget, so that I can narrow to what's feasible. | P0 |
| US-C-03 | As a user, I want a meal detail screen with ingredients, cost, time and steps, so that I can actually cook it. | P0 |
| US-C-04 | As a user, I want to favourite meals, so that good results come back more often. | P0 |
| US-C-05 | As a user, I want to dislike meals, so that bad results stop appearing. | P0 |
| US-C-06 | As a user, I want to add my own meals, so that the app knows the food I actually eat. | P0 |
| US-C-07 | As a user, I want step-by-step cooking mode, so that I'm not scrolling a recipe with greasy hands. | P1 |
| US-C-08 | As a user, I want to see my meal history, so that I can repeat something that worked. | P0 |

### Epic D — Couple Mode

| ID | Story | Priority |
| -- | ----- | -------- |
| US-D-01 | As a partnered user, I want to create a household and invite my partner, so that we decide together. | P0 |
| US-D-02 | As a partner, I want to join via a code or link, so that setup takes seconds. | P0 |
| US-D-03 | As a couple, we want recommendations that account for both of us, so that neither has to compromise silently. | P0 |
| US-D-04 | As a partner, I want my own private preferences, so that shared decisions still respect my tastes. | P0 |
| US-D-05 | As a couple, we want shared meal history and favourites, so that the app learns about us as a unit. | P0 |
| US-D-06 | As a couple who can't agree, we want to each vote on meals and see the match, so that nobody has to concede. | P1 |
| US-D-07 | As a partner, I want to see my partner's changes appear live, so that we can decide while apart. | P1 |
| US-D-08 | As a couple, we want a food-compatibility score, so that the app feels personal and fun. | P2 |

**US-D-03 acceptance criteria**

* **Given** Partner A avoids fish and Partner B avoids spicy food, **when** the household
  spins, **then** no meal violating *either* exclusion is returned.
* **Given** a meal is favourited by both partners, **when** the household spins, **then**
  that meal scores higher than one favourited by only one partner.
* **Given** the household's exclusions eliminate every meal, **when** we spin, **then** the
  app names the conflicting constraint rather than failing silently.

### Epic E — Pantry & Grocery

| ID | Story | Priority |
| -- | ----- | -------- |
| US-E-01 | As a user, I want to record what's in my fridge, so that suggestions use what I already own. | P0 |
| US-E-02 | As a user, I want meals ranked by how much of the recipe I already have, so that I can cook without shopping. | P0 |
| US-E-03 | As a user, I want the app to tell me exactly which ingredients I'm missing, so that shopping is a solved list. | P0 |
| US-E-04 | As a user, I want missing ingredients added to a grocery list in one tap, so that I don't transcribe anything. | P0 |
| US-E-05 | As a household member, I want to check items off a shared list and have my partner see it instantly, so that we don't buy duplicates. | P1 |
| US-E-06 | As a user, I want to be warned about ingredients expiring soon, so that I waste less food. | P2 |

**US-E-02 acceptance criteria**

* **Given** my pantry contains chicken, soy sauce and garlic, **when** I tap *Find Meals*,
  **then** meals are ordered by descending percentage of required ingredients owned.
* **Given** a meal needs 7 ingredients and I have all 7, **then** it displays
  *100% available*.
* **Given** staples (salt, pepper, oil, water) are absent from my pantry, **then** they do
  not reduce the match percentage.

### Epic F — Planner

| ID | Story | Priority |
| -- | ----- | -------- |
| US-F-01 | As a planner, I want to assign meals to days of the week, so that weeknights are already decided. | P2 |
| US-F-02 | As a planner, I want a week generated from my budget and preferences, so that planning costs no effort. | P2 |
| US-F-03 | As a planner, I want the plan to reuse ingredients across days, so that I buy less and waste less. | P2 |
| US-F-04 | As a planner, I want one grocery list for the whole week with quantities combined, so that I shop once. | P2 |

### Epic G — Profile & Trust

| ID | Story | Priority |
| -- | ----- | -------- |
| US-G-01 | As a user, I want to edit my preferences at any time, so that the app keeps up with me. | P0 |
| US-G-02 | As a user, I want my household data private to my household, so that I trust the app with it. | P0 |
| US-G-03 | As a user, I want to see stats on what I've eaten and spent, so that I feel the app is worth keeping. | P1 |
| US-G-04 | As a user, I want to delete my account and data, so that I stay in control. | P1 |
| US-G-05 | As a user, I want configurable notifications, so that the app is helpful and not annoying. | P2 |

---

## 6. MVP scope

The MVP tests exactly one hypothesis:

> **Can What's Cooking? reliably help people decide what to eat faster than they otherwise
> would — and will they come back to it?**

Everything that does not serve that test is cut. The full in/out breakdown lives in
[MVP_SCOPE.md](MVP_SCOPE.md). Summary:

**In:** auth and onboarding · meal catalogue with search and filters · meal details ·
custom meals · favourites and dislikes · **the roulette with filters, repetition prevention
and weighted scoring** · meal history · household creation and invitation · shared history
and favourites · pantry with ingredient matching · grocery list with auto-generated missing
ingredients.

**Out for MVP:** AI assistant · fridge scanner · weekly planner · realtime sync ·
gamification and achievements · advanced statistics · restaurant and delivery modes · group
mode beyond two people · subscriptions and payments · push notifications.

---

## 7. Post-MVP roadmap

Aligned to the versions in `project_dev.md`.

| Version | Theme | Contents |
| ------- | ----- | -------- |
| **1.0** | Core decision | Auth, meals, roulette, scoring, history, favourites |
| **1.1** | Couples | Households, invitations, shared data, Can't Agree voting, realtime |
| **1.2** | Food management | Pantry, expiry, ingredient matching, grocery, budget system |
| **1.3** | Planning | Weekly planner, auto-generation, ingredient reuse, week→grocery |
| **2.0** | Intelligence | AI assistant, recipe generation, fridge scanner, AI personalisation |
| **Later** | Expansion | Restaurant mode, delivery, meal photo recognition, group mode, gamification |

---

## 8. Non-goals

Stating these prevents scope drift. Each is a deliberate refusal, not an oversight.

| # | We will **not** build | Why |
| - | --------------------- | --- |
| 1 | A calorie or macro tracker | Turns a fun 60-second decision into daily logging. Calories may appear as *display data*; they will never be a tracked target. |
| 2 | A social network or public recipe feed | Feeds, follows and comments reintroduce browsing — the exact problem we exist to remove. |
| 3 | A food delivery marketplace | We do not take orders, take payments, or carry restaurant inventory. |
| 4 | Live or scraped grocery pricing | Costs are **user-adjustable estimates**. Real-time pricing is a per-market data business we are not entering. |
| 5 | A nutrition or medical authority | Dietary settings are preferences and exclusions. We make no clinical or allergen-safety guarantee, and will say so in-product. |
| 6 | A professional recipe authoring tool | Custom meals are for *your* food, not for publishing. No rich media editor, no versioning, no export. |
| 7 | Offline-first with conflict resolution | Household data is inherently shared; a sync engine is disproportionate. MVP handles offline with cached reads and clear degraded states. |
| 8 | Web or desktop clients | Mobile-only. The decision happens in a kitchen, standing up, on a phone. |
| 9 | Groups larger than a household | MVP supports 1–2 users well. Group mode is a v2+ question, and voting logic does not generalise for free. |
| 10 | Ads | The core loop is one screen and one tap. An ad inside that loop destroys the product. Monetisation is freemium only. |
| 11 | Localisation beyond English at MVP | UI ships in English; Filipino food terminology appears in meal data. Full i18n waits for demand. |
| 12 | Smart-appliance or wearable integrations | No credible user pull at this stage. |
| 13 | Third-party sign-in (Google, Apple, Facebook) | Cut at Sprint 18. Every provider is an external console, a set of platform-specific secrets and its own failure mode, bought for a few seconds saved once per user. Email and password is the whole of authentication. |

---

## 9. Success metrics

### North star

> ## Time to Decision
>
> Median seconds from app open to accepting a meal.
>
> **Target: under 60 seconds. Stretch: under 30 seconds.**

Measured per session that reaches an accept. Sessions without an accept are tracked
separately as **abandonment** and are the primary diagnostic signal.

### Primary metrics

| Metric | Definition | MVP target |
| ------ | ---------- | ---------- |
| Time to Decision | Median open → accept | **< 60s** |
| Acceptance rate | Accepts ÷ spins | **> 40%** |
| Spins per accept | Re-spins before commitment | **< 2.5** |
| D7 retention | Users active 7 days after install | **> 30%** |
| W4 retention | Users active in week 4 | **> 15%** |
| Decisions per user per week | Accepted meals weekly | **> 3** |

Acceptance rate is the health check on the recommendation engine. Below 30% means the
engine is not credible; above 70% may mean filters are so narrow that it no longer feels
like discovery.

### Secondary metrics

| Metric | MVP target |
| ------ | ---------- |
| Onboarding completion | > 70% |
| Households created (of eligible users) | > 25% |
| Partner invitations accepted | > 60% |
| Users with 5 or more pantry items | > 20% |
| Grocery lists created per active user per week | > 0.5 |
| Custom meals added per active user | > 1 |
| Crash-free sessions | **> 99.5%** |
| P95 spin latency (tap → result) | **< 2s** |

### Counter-metrics — guardrails

Rising numbers here mean we broke something, even if primary metrics look healthy.

| Signal | What it would mean |
| ------ | ------------------ |
| Session length **increasing** | The app has become browsing. Time to decision is the goal, not engagement. |
| Spins per accept **rising** | Recommendations are losing credibility. |
| Filter screen time **rising** | Configuration burden is displacing the decision. |
| Dislike actions **rising** sharply | Catalogue quality or scoring has regressed. |

### Qualitative bar

The closed beta (Sprint 68) must produce, unprompted, statements matching:

* *"We don't argue about dinner any more."*
* *"It's actually fun."*
* *"It suggested something I forgot I liked."*

Their absence is a signal even if every quantitative target is met.

---

## 10. Assumptions and risks

| # | Assumption | Risk if wrong | Validated by |
| - | ---------- | ------------- | ------------ |
| A1 | People will accept a decision made by an app | Core thesis fails | Acceptance rate, Sprints 67–68 |
| A2 | The blame-free framing is what makes couples adopt it | Couple mode underused | Household creation rate |
| A3 | Users will enter pantry contents at least occasionally | Ingredient matching is dead weight | Pantry-items metric |
| A4 | Estimated costs are close enough to be trusted | Budget filter loses credibility | Beta feedback on cost accuracy |
| A5 | A seeded catalogue is large enough to feel non-repetitive | Variety collapses | Spins per accept, dislike rate |
| A6 | Filipino-leaning content is a strength, not a limit | Narrow addressable market | Beta cuisine distribution |

### Key risks

* **Cold start.** A user with no history, no pantry and no partner still needs a good first
  spin. Onboarding preferences must carry the entire first session.
* **Catalogue depth.** Too few meals and the roulette repeats within a week. Sprint 21 must
  seed enough breadth per cuisine, and adding custom meals must be frictionless.
* **Cost accuracy.** Prices vary by region and over time. Estimates must be visibly
  *estimates* and user-editable, or the budget filter permanently loses trust.
* **Single-user drop-off.** Roughly half of early users will have no partner. Solo mode must
  be complete on its own, never a degraded couple experience.

---

## 11. Open questions

Each must be resolved before the sprint listed.

| # | Question | Resolve by |
| - | -------- | ---------- |
| Q1 | Repetition window default — 3, 5 or 7 days? Configurable? | Sprint 32 |
| Q2 | Does a re-spin count as a rejection signal for learning? | Sprint 37 |
| Q3 | Household exclusions — hard union of both partners' dislikes, or soft penalty? | Sprint 46 |
| Q4 | Initial catalogue size and cuisine split | Sprint 21 |
| Q5 | Cost estimates — single national average, or user-editable per meal? | Sprint 23 |
| Q6 | Guest mode — full roulette, or limited spins before signup? | Sprint 16 |
| Q7 | Household size cap for MVP — strictly 2, or up to 5? | Sprint 41 |
| Q8 | Are custom meals private to the household, or pooled into the global catalogue? | Sprint 26 |

---

## 12. Definition of success for the MVP

The MVP has succeeded if, at the end of the closed beta:

1. Median time to decision is **under 60 seconds**.
2. Acceptance rate exceeds **40%**.
3. D7 retention exceeds **30%**.
4. At least **25%** of eligible users created a household.
5. Beta users, unprompted, describe the app as solving a real recurring argument.
6. No P0 defects remain open.

If 1–3 hold and 4–5 do not, the decision engine works and **couple mode needs rework**.
If 4–5 hold and 1–3 do not, the positioning is right and **the engine needs rework**.
