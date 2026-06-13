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
