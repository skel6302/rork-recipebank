# Weekly meal planner with shopping-list integration

## What this adds

An AnyList-style weekly meal planner so you can plan what you'll cook each day and
turn that plan into a shopping list in one tap.

## Features

- **Weekly planner** — a "Plan" tab showing all seven days of the week, each with
  Breakfast, Lunch, and Dinner slots.
- **Assign recipes or foods** — tap any slot to add either a recipe from your
  collection or a standalone food (e.g. a bagel) searched from a food database with
  nutrition; add more than one item to a slot if needed.
- **Food database search** — the picker's Foods tab searches USDA FoodData Central
  (branded foods) by name and can also estimate any food's nutrition with AI.
- **Browse weeks** — move forward or back a week; today's day is highlighted.
- **Tap to open** — tap a planned recipe to jump to its full detail page.
- **Send week to shopping list** — one button adds every ingredient from the week's
  planned recipes to your shopping list, merging duplicates.
- **Clear week** — remove the whole week's plan at once.

## Design

- Matches the warm cookbook aesthetic: paper background, spice accents, serif headings.
- Each day is a rounded card; today gets a spice-colored border and a "TODAY" badge.
- Empty meal slots show a dashed "Add a recipe or food" placeholder; filled recipe
  slots show a thumbnail, title, ingredient count, and cook time, while food slots show
  a fork icon, name, calories, and serving.
- A floating warm-gradient button sends the week to the shopping list, turning green
  with a checkmark on success.

## Screens

- **Plan tab** — the weekly planner (new).
- **Recipe picker sheet** — a two-tab sheet (Recipes / Foods) for filling a slot with
  a saved recipe or a searched food item.
- **Shopping tab** — unchanged, now also fed by the weekly plan.

---

# GLP-1 medication tracking & education

## What this adds

A new "Meds" tab for tracking GLP-1 medications (pill and shot) plus a bundled
education guide on what to eat, what to avoid, and managing side effects.

## Features

- **Medication tracking** — add Ozempic, Wegovy, Mounjaro, Zepbound, Trulicity,
  Saxenda, Rybelsus (quick presets) or any custom pill/shot, with dose (mg),
  weekly or daily schedule, and dose day.
- **Next-dose countdown** — each medication card shows when the next dose is due
  ("Tomorrow", "In 3 days") and turns to "Due now" when it's time.
- **One-tap dose logging** — record a dose with time, amount, and notes.
- **Injection-site rotation** — for shots, a site picker (abdomen / thigh / arm,
  left & right) that auto-suggests the next rotation site to avoid reuse.
- **Dose reminders** — optional local notifications at the chosen day/time.
- **Recent dose history** — a running list of logged doses across medications.
- **GLP-1 Guide** — bundled education cards: Eat more of, Go easy on, Managing
  side effects, and Smart habits, with tap-to-expand tips.

## Design

- Matches the warm cookbook aesthetic: paper background, spice/sage accents,
  serif headings, rounded cards and a floating warm-gradient add button.
- Includes a clear "not medical advice" disclaimer.

## Screens

- **Meds tab** — medication cards, recent doses, and a link to the guide (new).
- **Add/Edit medication sheet** — presets, dose, schedule, reminder time (new).
- **Log dose sheet** — time, amount, injection-site picker, notes (new).
- **GLP-1 Guide sheet** — curated education content (new).

---

# GLP-1 tab & RecipeBank Pro subscription

## What this adds

The Meds tab becomes a dedicated "GLP-1" tab (inspired by MeAgain) with weight
progress, and the app gets real subscription billing through RevenueCat.

## Features

- **GLP-1 tab** — renamed from Meds, adds a Weight Progress card with start /
  current / change stats, a trend chart, and quick weight logging.
- **Paywall** — monthly/yearly picker with live store prices, feature checklist,
  save-50% badge, and a Restore Purchases button; also reachable from Account
  ("Upgrade" / "Manage").

---

# Health tab & tiered subscriptions (Basic / Plus / Pro)

## What this adds

Calorie tracking and the GLP-1 companion merge into a single "Health" tab, and
billing becomes a three-tier model with a 7-day free trial, configured in
RevenueCat across the Test Store, iOS App Store, and Google Play Store.

## Plans

- **Basic (Free)** — up to 50 saved recipes, recipe import, and the grocery /
  shopping list.
- **Plus ($4.99/mo or $29.99/yr)** — unlimited recipe storage, the weekly meal
  planner, and calorie & macro tracking.
- **Pro ($6.99/mo or $39.99/yr)** — everything in Plus, with the GLP-1
  companion (dose tracking, reminders, site rotation, weight progress, guide)
  as the bonus feature.
- **7-day free trial** — new subscribers try any paid plan free for a week.

## Features

- **Health tab** — one tab with a Calories / GLP-1 switcher. The GLP-1 section
  shows a lock badge and an in-tab Pro upsell when the plan doesn't include it.
- **50-recipe free limit** — the Recipes tab shows "x of 50 free recipes" and
  adding/scanning/importing past the cap prompts an upgrade to Plus (including
  imports from the share extension).
- **Locked tabs** — Plan and Health show a polished unlock screen on the free
  plan.
- **Paywall** — monthly/yearly toggle with a save-50% badge, selectable Plus and
  Pro cards with live store prices, trial-first wording ("Start My 7-Day Free
  Trial"), a free-plan card, and Restore Purchases. Plus subscribers see an
  "Upgrade to Pro" flow.
- **Billing status** — RevenueCat is configured with `recipebank_plus_monthly`
  / `recipebank_plus_yearly` ($4.99 / $29.99) and `recipebank_pro_monthly` /
  `recipebank_pro_yearly` ($6.99 / $39.99) in all three stores, mapped to the
  "RecipeBank Plus" and "RecipeBank Pro" entitlements (Pro products unlock
  both). The 7-day trial still needs to be set as an introductory offer in App
  Store Connect / Play Console when the products are created there.

## Screens

- **Health tab** — Calories and GLP-1 sections behind a segmented switcher
  (new, replaces the separate Calories and GLP-1 tabs).
- **GLP-1 upsell** — in-tab Pro pitch when GLP-1 is locked (new).
- **Paywall sheet** — two-tier paywall with trial messaging (updated).
- **Recipes tab** — free-plan counter and limit prompts (updated).
- **Account sheet** — plan card with tier-aware Upgrade/Manage (updated).
