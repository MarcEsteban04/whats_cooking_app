# 🍽️ What's Cooking?

> **No more “ikaw bahala.”**

**What's Cooking?** is a smart meal-decision app designed for couples, families, roommates, and individuals who constantly struggle with deciding what to eat.

Instead of endlessly asking:

> **“What should we eat?”**

Users can save their favorite meals, set their budget and preferences, enter ingredients they already have, and let **What's Cooking?** intelligently decide what they should eat.

The app combines **meal randomization, couple decision-making, meal planning, budgeting, grocery management, pantry tracking, and AI-powered recommendations** into one simple experience.

---

# 🎯 The Problem

One of the most common everyday problems for couples is deciding what to eat.

The conversation usually goes:

> “What's for dinner?”

> “You decide.”

> “Anything is fine.”

> “Pizza?”

> “I don't feel like pizza.”

> “Then what do you want?”

> “I don't know.”

And the cycle repeats almost every day.

**What's Cooking?** solves this by turning the decision into a fast, fun, and interactive experience.

Instead of spending 30 minutes deciding:

# Open → Spin → Decide → Eat.

---

# 💡 Core Concept

The core idea behind **What's Cooking?** is simple:

## 🎰 Let the app decide.

Users can create their own meal library or choose from the application's meal database.

Before spinning, users can optionally provide:

* Budget
* Meal type
* Cuisine
* Cooking method
* Available ingredients
* Cooking time
* Food preferences
* Dietary restrictions
* Current mood
* Eat at home vs. order out

The app then recommends a meal that matches those conditions.

### Example

**Budget:** ₱300
**People:** 2
**Cuisine:** Filipino
**Available ingredients:** Chicken, eggs, potatoes
**Cooking time:** Under 45 minutes

### Result

> 🍗 **Chicken Adobo**
>
> Estimated cost: ₱180
> Cooking time: ~35 minutes
> Servings: 2
>
> **[Accept] [Try Again]**

Once accepted:

> ✅ **Dinner decided. No more “ikaw bahala.”**

---

# 🚀 Product Goals

What's Cooking? should:

1. Make meal decisions faster.
2. Make deciding what to eat fun.
3. Help couples compromise on food.
4. Reduce unnecessary food spending.
5. Reduce food waste.
6. Help users use ingredients they already have.
7. Make meal planning easier.
8. Provide increasingly personalized recommendations.
9. Encourage users to cook more often.
10. Turn an everyday annoyance into an enjoyable experience.

---

# 👥 Target Users

### Primary

* Couples
* Young adults
* Roommates
* Students
* Working professionals
* Small families

### Secondary

* Individuals living alone
* People learning to cook
* Budget-conscious households
* People who frequently order food

---

# ✨ Core Features

## 1. 🎰 Smart Meal Roulette

The main feature of What's Cooking?

Users tap the **What's Cooking?** button and receive a meal recommendation.

The randomizer should not simply choose any random meal.

Instead, it considers:

* User preferences
* Previous meals
* Budget
* Meal category
* Cuisine
* Available ingredients
* Cooking time
* Dietary restrictions
* Favorite meals
* Disliked meals
* Partner preferences

### Example

Instead of:

> Random → Adobo

The recommendation engine understands:

> “You had adobo yesterday, you only have 30 minutes, and your budget is ₱250.”

It may recommend:

> 🍝 **Chicken Carbonara**

The experience should feel random, but the result should still make sense.

---

# 2. ❤️ Couple Mode

One of the application's main differentiating features.

Users can connect with their partner and create a shared household.

Both users can participate in deciding what to eat.

Each partner can have their own:

* Favorite meals
* Disliked meals
* Favorite cuisines
* Dietary restrictions
* Ingredient preferences
* Budget preferences
* Cooking preferences

The recommendation engine considers both users.

---

## 🤝 Can't Agree Mode

When both partners can't agree, they can independently vote on meals.

Each person sees a selection of meals and can choose:

❤️ Like

👎 Pass

### Example

**Partner A**

❤️ Chicken Katsu
❌ Sinigang
❤️ Carbonara

**Partner B**

❤️ Chicken Katsu
❤️ Sinigang
❌ Carbonara

The app identifies:

> ❤️ **Chicken Katsu**
>
> You both liked this.

No arguments.

No “ikaw bahala.”

Just dinner.

---

# 3. 🍽️ Meal Database

What's Cooking? contains a searchable meal database.

Each meal can include:

* Name
* Description
* Image
* Cuisine
* Category
* Ingredients
* Instructions
* Estimated cost
* Cooking time
* Difficulty
* Servings
* Calories (optional)
* Tags

### Example

```text
Chicken Adobo

Cuisine:
Filipino

Category:
Dinner

Estimated Cost:
₱180

Cooking Time:
35 minutes

Difficulty:
Easy

Servings:
2
```

---

# 4. ❤️ Favorites

Users can save meals they enjoy.

Favorites influence future recommendations.

Example:

```text
⭐ Favorite Meals

Chicken Adobo
Chicken Katsu
Carbonara
Sinigang
Fried Chicken
```

The recommendation engine can prioritize these meals when appropriate.

---

# 5. 👎 Disliked Meals

Users can exclude meals they don't enjoy.

For example:

```text
❌ Disliked

Fish
Very spicy food
Dinuguan
```

These meals should not appear during normal recommendations.

---

# 6. 🧠 Meal History

What's Cooking? keeps track of what users have eaten.

This allows the recommendation system to avoid unnecessary repetition.

### Example

```text
Monday
Chicken Adobo

Tuesday
Pizza

Wednesday
Sinigang

Thursday
Chicken Katsu
```

If the user tries to spin:

> ⚠️ You had Chicken Adobo recently.

The system can reduce the probability of recommending it again.

---

# 7. 🏠 What's In The Fridge?

Users can enter ingredients they currently have at home.

Example:

```text
Chicken
Eggs
Potatoes
Onion
Garlic
Soy Sauce
Rice
```

What's Cooking? finds meals that can be prepared using those ingredients.

### Example

## You can make:

### 🍗 Chicken & Potato Adobo

**100% ingredients available**

### 🍳 Chicken Omelette

**90% ingredients available**

### 🍜 Chicken Stir Fry

**80% ingredients available**

Meals requiring the fewest additional ingredients should be prioritized.

---

# 8. 💰 Budget Mode

Users can set a meal budget.

Example:

> **Tonight's budget**
>
> ₱200

The recommendation engine prioritizes meals within that budget.

### Presets

* ₱100
* ₱200
* ₱300
* ₱500
* Custom

Budget can be configured per:

* Meal
* Day
* Week

---

# 9. 🛒 Grocery List

When a user selects a meal, What's Cooking? determines which ingredients are missing.

### Example

Chicken Adobo requires:

* Chicken
* Soy sauce
* Vinegar
* Garlic
* Onion
* Bay leaves
* Black pepper

The app checks the user's pantry.

If they already have:

* Garlic
* Onion
* Soy sauce

Only the missing ingredients are added.

```text
🛒 Grocery List

☐ Chicken
☐ Vinegar
☐ Bay leaves
☐ Black pepper
```

---

# 10. 👨‍🍳 Cooking Mode

After selecting a meal, users can enter a dedicated cooking mode.

Instead of displaying the entire recipe at once, instructions are presented step-by-step.

### Step 1

Prepare the chicken.

**Next →**

### Step 2

Marinate the chicken with soy sauce and garlic.

**Next →**

### Step 3

Heat the pan.

**Next →**

The goal is to make cooking easier without requiring users to constantly scroll through a recipe.

---

# 11. 📅 Weekly Meal Planner

Users can generate a meal plan for the week.

### Example

| Day       | Meal          |
| --------- | ------------- |
| Monday    | Chicken Adobo |
| Tuesday   | Carbonara     |
| Wednesday | Sinigang      |
| Thursday  | Chicken Katsu |
| Friday    | Pizza         |
| Saturday  | Korean Beef   |
| Sunday    | Fried Chicken |

The planner considers:

* Budget
* Preferences
* Meal history
* Ingredient reuse
* Variety
* Cooking time

---

# 12. 🧺 Ingredient Reuse

The meal planner should intelligently reuse ingredients.

Example:

**Monday**

Chicken Adobo

**Tuesday**

Chicken Fried Rice

**Wednesday**

Chicken Sandwich

Instead of buying completely different ingredients every day, users can strategically reuse what they already purchased.

Benefits:

* Less food waste
* Lower grocery costs
* Easier shopping

---

# 13. 🤖 What's Cooking? AI Assistant

An advanced AI assistant can become one of the application's biggest features.

Users can simply ask:

> **“What can we cook tonight?”**

The AI considers:

* Available ingredients
* Budget
* Previous meals
* Preferences
* Cooking time
* Partner preferences

### Example

> **AI**
>
> You have chicken, eggs, potatoes, and rice available.
>
> Your budget is ₱250 and you haven't had Filipino food in four days.
>
> I'd recommend:
>
> 🍗 **Chicken & Potato Adobo**
>
> Estimated cost: ₱180
> Cooking time: 35 minutes
> Servings: 2

---

# 14. 📸 AI Fridge Scanner

Future AI feature.

Users take a photo of their refrigerator, pantry, or ingredients.

AI attempts to identify available ingredients.

### Example

📷 Photo

↓

AI detects:

```text
Chicken
Eggs
Tomatoes
Onions
Milk
Cheese
```

↓

> **Here are 5 meals you can make.**

Because image recognition isn't perfect, users should be able to review and correct detected ingredients before generating recommendations.

---

# 15. 🎭 Mood-Based Recommendations

Users can choose what they're craving.

### Mood options

🍔 Comfort Food
🍜 Craving
🥗 Healthy
🌶️ Spicy
🍕 Junk Food
🍱 Light Meal
💪 High Protein
💰 Cheap
🎲 Surprise Me

The recommendation engine adjusts accordingly.

---

# 16. 🏆 Gamification

Make cooking and trying new meals more enjoyable.

### Statistics

```text
🔥 7 Day Cooking Streak

🍽️ 32 Meals Tried

🇵🇭 18 Filipino Meals

🍜 6 Asian Meals

💰 ₱1,250 Estimated Savings
```

### Achievements

🏆 **Adobo Addict**
Eat adobo 10 times.

🍳 **Home Cook**
Cook 20 meals.

💰 **Budget Master**
Stay within your budget for 30 days.

🌎 **Food Explorer**
Try 10 different cuisines.

❤️ **Perfect Match**
Find 20 meals both partners like.

---

# 17. 📊 Food Statistics

Users can view their eating patterns.

### Example

```text
Your Month

Filipino       42%
Asian          27%
Western        18%
Other          13%

Average Meal Cost
₱187

Meals Cooked
24

Meals Ordered
9
```

This helps users understand their eating habits and spending.

---

# 18. 🔔 Smart Notifications

Optional notifications can remind users:

> 🍽️ It's almost dinner time.

> You haven't planned dinner yet.

> 🥬 You have ingredients that may expire soon.

> ❤️ Your partner added a new favorite meal.

> 🛒 You still have items on your grocery list.

Notifications should be fully configurable.

---

# 19. 🔗 Couple / Household Sharing

Users can create a household.

### Example

```text
Marc's Household

Members:
❤️ Marc
❤️ Partner
```

Shared information includes:

* Meal history
* Favorites
* Grocery list
* Pantry
* Meal plans
* Budget
* Recommendations

Personal preferences can remain private when appropriate.

---

# 📱 Main Screens

## 1. Home

The main screen should immediately answer the question:

> **What's cooking?**

Example:

```text
Good evening, Marc 👋

What are we eating tonight?

        🎰
   WHAT'S COOKING?

Budget: ₱300
People: 2

Quick Picks

🍗 Comfort
🍜 Asian
🥗 Healthy
💰 Budget
🎲 Surprise
```

---

# 2. Meal Result

The result screen should feel exciting.

```text
🎉 Tonight's Pick

🍗 Chicken Katsu

₱220 estimated
30 minutes
2 servings

❤️ You both liked this before.

[ ACCEPT ]
[ TRY AGAIN ]
```

---

# 3. Meals

Browse:

* All meals
* Favorites
* Recently eaten
* Saved recipes
* My meals

---

# 4. Fridge / Pantry

```text
🏠 What's In The Fridge?

Chicken
Eggs
Potatoes
Rice
Garlic
Onion

[ + Add Ingredient ]

✨ Find Meals
```

---

# 5. Grocery

```text
🛒 Grocery List

Chicken
☐ 500g

Vinegar
☐ 1 bottle

Garlic
☐ 1 bulb

[ + Add Item ]
```

---

# 6. Planner

Weekly calendar with meals assigned to each day.

---

# 7. Couple

```text
❤️ Our Food Profile

Marc
Favorite: Chicken
Avoids: Fish

Partner
Favorite: Pasta
Avoids: Spicy food

Compatibility

❤️ 87%
```

---

# 8. Profile / Settings

Includes:

* Account
* Preferences
* Dietary restrictions
* Budget
* Notifications
* Household
* Subscription
* Privacy
* Data management

---

# 🧱 Technical Architecture

## Frontend

### Flutter

Flutter is the primary mobile application framework.

### Recommended Technologies

* Flutter
* Dart
* Material 3
* Riverpod
* GoRouter
* Freezed
* Dio where external APIs are required

### Suggested Project Structure

```text
lib/
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── router/
│   ├── theme/
│   └── utils/
│
├── features/
│   ├── auth/
│   ├── home/
│   ├── meals/
│   ├── roulette/
│   ├── couple/
│   ├── pantry/
│   ├── grocery/
│   ├── planner/
│   ├── history/
│   ├── ai/
│   └── profile/
│
└── main.dart
```

---

# ☁️ Backend

## Supabase

Supabase handles:

* Authentication
* PostgreSQL database
* Row Level Security
* Storage
* Realtime
* Edge Functions

---

# 🗄️ Database Structure

## profiles

```text
id
display_name
avatar_url
created_at
updated_at
```

---

## households

```text
id
name
created_by
created_at
```

---

## household_members

```text
id
household_id
user_id
role
joined_at
```

---

## meals

```text
id
name
description
image_url
cuisine
category
difficulty
cooking_time
estimated_cost
servings
instructions
created_at
```

---

## ingredients

```text
id
name
category
unit
created_at
```

---

## meal_ingredients

```text
id
meal_id
ingredient_id
quantity
unit
```

---

## user_preferences

```text
id
user_id
favorite_cuisines
disliked_ingredients
dietary_preferences
default_budget
max_cooking_time
created_at
updated_at
```

---

## favorite_meals

```text
id
user_id
meal_id
created_at
```

---

## disliked_meals

```text
id
user_id
meal_id
created_at
```

---

## meal_history

```text
id
household_id
meal_id
eaten_at
meal_type
cost
```

---

## pantry_items

```text
id
household_id
ingredient_id
quantity
unit
expiration_date
created_at
updated_at
```

---

## grocery_lists

```text
id
household_id
name
created_at
```

---

## grocery_items

```text
id
grocery_list_id
ingredient_id
quantity
unit
is_completed
created_at
```

---

## meal_plans

```text
id
household_id
meal_id
planned_date
meal_type
created_at
```

---

# 🔐 Authentication

Supabase Auth should support:

* Email/password
* Google
* Apple
* Magic link (optional)

A guest mode can optionally allow users to try the roulette before creating an account.

---

# 🔒 Security

Supabase Row Level Security must be enabled.

Users should only be able to access:

* Their own profile
* Their own preferences
* Their private data
* Households they belong to
* Shared household information

Users must never be able to access another household's private information.

---

# 🔄 Realtime Features

Supabase Realtime can power shared couple experiences.

### Couple Mode

If one partner adds:

> ❤️ Chicken Katsu

The other partner can immediately see it.

### Grocery List

If one person checks:

> ☑ Chicken

The other person's list updates automatically.

### Meal Planning

Both partners see changes to the shared weekly plan.

---

# 🤖 AI Architecture

AI functionality should be handled through a secure backend layer.

Never expose private AI API keys inside the Flutter application.

Recommended flow:

```text
Flutter App
     ↓
Supabase Edge Function
     ↓
AI Provider
     ↓
Supabase
     ↓
Flutter App
```

---

# 🎰 Recommendation Engine

The meal randomizer should eventually become a weighted recommendation engine.

Possible scoring model:

```text
Preference Match       +30
Budget Match           +20
Ingredient Match       +20
Partner Compatibility  +25
Favorite Meal          +15
Cuisine Variety        +10
Cooking Time Match     +10
Recent Meal Penalty    -15
Disliked Meal          -100
```

The system then selects from the highest-scoring meals while maintaining some randomness.

This creates a key product characteristic:

> **It should feel random, but never feel stupid.**

---

# 💸 Monetization

What's Cooking? can use a freemium model.

## Free

* Basic roulette
* Personal meal library
* Favorites
* Basic meal history
* Basic filters
* Basic couple features

## Premium

Potential premium features:

* Unlimited AI recommendations
* AI fridge scanner
* Advanced meal planning
* Advanced budget tracking
* Unlimited households
* Advanced statistics
* Personalized AI recommendations
* AI recipe generation
* Smart grocery planning

The basic roulette should remain free because it is the primary hook of the application.

---

# 🔮 Future Features

## 🍴 Restaurant Mode

Instead of deciding what to cook:

> **“Where should we eat?”**

The app can recommend restaurants based on:

* Budget
* Cuisine
* Distance
* Rating
* Preferences

---

## 🛵 Delivery Mode

Where integrations are available, users could eventually go from:

> “What's Cooking?”

directly to:

> “Order this.”

---

## 📸 Meal Recognition

Users take a photo of their food.

AI identifies the meal and lets the user add it to their meal history.

---

## 🌎 Location-Based Recommendations

The application can recommend nearby restaurants that match:

* Budget
* Cuisine
* Distance
* Preferences

---

## 🧑‍🤝‍🧑 Group Mode

Expand beyond couples.

Example:

> **Family Dinner — 5 people**

Everyone votes.

What's Cooking? finds the meal with the highest group compatibility.

---

# 🧭 MVP Scope

The first release should focus on validating the core idea rather than building every feature.

## MVP Features

### Authentication

* Sign up
* Login
* Profile

### Meal System

* Browse meals
* Search meals
* Meal details
* Add custom meal
* Favorites
* Dislikes

### Roulette

* Random meal
* Filters
* Budget
* Cooking time
* Meal category
* Try again
* Accept meal

### History

* Record selected meals
* Recently eaten
* Repetition prevention

### Couple Mode

* Create household
* Invite partner
* Shared meals
* Shared history
* Basic voting

### Pantry

* Add ingredients
* Remove ingredients
* Find meals based on ingredients

### Grocery

* Add missing ingredients
* Check off items

This is enough to validate whether people actually enjoy using the application.

---

# 🗺️ Development Roadmap

## Version 1.0 — Core Experience

* Authentication
* Home screen
* Meal database
* Meal details
* Roulette
* Filters
* Favorites
* Meal history

---

## Version 1.1 — Couples

* Household creation
* Partner invitations
* Shared favorites
* Voting
* Couple recommendations

---

## Version 1.2 — Food Management

* Pantry
* Grocery list
* Ingredient matching
* Budget system

---

## Version 1.3 — Planning

* Weekly meal planner
* Ingredient reuse
* Automatic grocery generation
* Meal variety optimization

---

## Version 2.0 — AI

* AI Meal Assistant
* AI fridge scanner
* Personalized recommendations
* AI-generated recipes

---

# 🎨 Design Direction

What's Cooking? should feel:

* Fun
* Modern
* Playful
* Fast
* Minimal
* Premium
* Food-focused

It should **not** feel like a complicated calorie tracker or nutrition application.

The main experience should remain:

> **Open → Spin → Decide → Eat**

---

# 🎰 The Signature Interaction

The roulette interaction should be one of the application's most memorable experiences.

A user taps:

# WHAT'S COOKING?

Then:

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

The animation slows down.

The final meal is revealed.

A small celebration animation plays.

Then:

> ❤️ **Tonight's dinner is decided.**

The user can:

**[ ACCEPT ]**

or:

**[ TRY AGAIN ]**

Haptic feedback should be used where supported to make the interaction feel satisfying.

---

# 🧠 Product Philosophy

What's Cooking? should never feel like a complicated food-management system.

Everything should support one simple goal:

> ## **Less thinking. More eating.**

The application should help users spend less time deciding and more time actually enjoying their food.

---

# 🏷️ Brand

## Name

# What's Cooking?

## Primary Tagline

> **No more “ikaw bahala.”**

## Alternative Taglines

> **Spin. Decide. Eat.**

> **Dinner decided in seconds.**

> **Let us pick tonight.**

> **Stop asking. Start eating.**

> **Your next meal, decided for you.**

---

# 📊 Success Metrics

The most important metrics should measure whether What's Cooking? actually solves the problem.

### Key Metrics

* Meals decided per user
* Roulette spins per day
* Recommendation acceptance rate
* Repeat usage
* Couple households created
* Meals cooked
* Grocery lists created
* Weekly meal plans created
* AI recommendation acceptance rate

### Most Important Metric

## ⏱️ Time to Decision

How long does it take from opening the app to deciding what to eat?

### Goal:

> **Under 60 seconds.**

---

# 🏁 Final Product Vision

What's Cooking? starts with a very simple question:

> **“What should we eat?”**

But it evolves into a personalized food decision assistant that understands:

* What you like
* What your partner likes
* What you already have
* What you've eaten recently
* How much you want to spend
* How much time you have
* What you're craving
* What you should probably eat next

And turns all of that into one simple answer:

# 🍽️ “This. We're eating this tonight.”

No endless discussions.

No “ikaw bahala.”

No scrolling through food delivery apps for 30 minutes.

Just:

# **What's Cooking? 🎰**

---

# 🛠️ Technology Stack

| Layer            | Technology                         |
| ---------------- | ---------------------------------- |
| Mobile           | Flutter                            |
| Language         | Dart                               |
| Backend          | Supabase                           |
| Database         | PostgreSQL                         |
| Authentication   | Supabase Auth                      |
| File Storage     | Supabase Storage                   |
| Realtime         | Supabase Realtime                  |
| Server Logic     | Supabase Edge Functions            |
| AI               | External AI API via Edge Functions |
| State Management | Riverpod                           |
| Navigation       | GoRouter                           |
| UI               | Material 3                         |
| Architecture     | Feature-based / Clean Architecture |

---

# 🎯 Project Goal

Build a fun, fast, and genuinely useful meal decision-making application for couples and households.

What's Cooking? should turn the everyday problem of:

> **“We don't know what to eat.”**

into:

> # **“What's Cooking? already decided.” 🍽️🎰**
