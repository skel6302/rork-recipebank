# Weekly meal planner with shopping-list integration

## What this adds

An AnyList-style weekly meal planner so you can plan what you'll cook each day and
turn that plan into a shopping list in one tap.

## Features

- **Weekly planner** — a "Plan" tab showing all seven days of the week, each with
  Breakfast, Lunch, and Dinner slots.
- **Assign recipes** — tap any slot to pick a recipe from your collection; add more
  than one recipe to a slot if needed.
- **Browse weeks** — move forward or back a week; today's day is highlighted.
- **Tap to open** — tap a planned recipe to jump to its full detail page.
- **Send week to shopping list** — one button adds every ingredient from the week's
  planned recipes to your shopping list, merging duplicates.
- **Clear week** — remove the whole week's plan at once.

## Design

- Matches the warm cookbook aesthetic: paper background, spice accents, serif headings.
- Each day is a rounded card; today gets a spice-colored border and a "TODAY" badge.
- Empty meal slots show a dashed "Add a recipe" placeholder; filled slots show a recipe
  thumbnail, title, ingredient count, and cook time.
- A floating warm-gradient button sends the week to the shopping list, turning green
  with a checkmark on success.

## Screens

- **Plan tab** — the weekly planner (new).
- **Recipe picker sheet** — searchable list of your recipes when filling a slot.
- **Shopping tab** — unchanged, now also fed by the weekly plan.
