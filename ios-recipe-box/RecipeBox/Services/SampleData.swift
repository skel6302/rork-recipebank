//
//  SampleData.swift
//  RecipeBox
//

import Foundation
import SwiftData

/// Seeds the database with starter recipes on first launch.
enum SampleData {
    static func seedIfNeeded(_ context: ModelContext) {
        let descriptor = FetchDescriptor<Recipe>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        for recipe in starterRecipes() {
            context.insert(recipe)
        }
        try? context.save()
    }

    static func starterRecipes() -> [Recipe] {
        [
            Recipe(
                title: "Creamy Tomato Basil Pasta",
                summary: "Silky tomato sauce with fresh basil and a touch of cream.",
                category: .dinner,
                servings: 4,
                prepMinutes: 10,
                cookMinutes: 25,
                rating: 5,
                isFavorite: true,
                ingredients: [
                    Ingredient(name: "penne pasta", quantity: "12 oz", aisle: .pantry, sortIndex: 0),
                    Ingredient(name: "crushed tomatoes", quantity: "1 can", aisle: .pantry, sortIndex: 1),
                    Ingredient(name: "heavy cream", quantity: "1/2 cup", aisle: .dairy, sortIndex: 2),
                    Ingredient(name: "fresh basil", quantity: "1 bunch", aisle: .produce, sortIndex: 3),
                    Ingredient(name: "garlic", quantity: "3 cloves", aisle: .produce, sortIndex: 4),
                    Ingredient(name: "parmesan", quantity: "1/2 cup", aisle: .dairy, sortIndex: 5)
                ],
                steps: [
                    "Boil pasta in salted water until al dente, then drain.",
                    "Sauté minced garlic in olive oil until fragrant.",
                    "Add crushed tomatoes and simmer for 10 minutes.",
                    "Stir in cream and torn basil, season to taste.",
                    "Toss pasta in the sauce and finish with parmesan."
                ]
            ),
            Recipe(
                title: "Fluffy Buttermilk Pancakes",
                summary: "Tall, golden pancakes that melt in your mouth.",
                category: .breakfast,
                servings: 3,
                prepMinutes: 10,
                cookMinutes: 15,
                rating: 4,
                isFavorite: true,
                ingredients: [
                    Ingredient(name: "all-purpose flour", quantity: "2 cups", aisle: .pantry, sortIndex: 0),
                    Ingredient(name: "buttermilk", quantity: "1 3/4 cups", aisle: .dairy, sortIndex: 1),
                    Ingredient(name: "eggs", quantity: "2", aisle: .dairy, sortIndex: 2),
                    Ingredient(name: "butter", quantity: "3 tbsp", aisle: .dairy, sortIndex: 3),
                    Ingredient(name: "baking powder", quantity: "2 tsp", aisle: .pantry, sortIndex: 4),
                    Ingredient(name: "maple syrup", quantity: "to serve", aisle: .pantry, sortIndex: 5)
                ],
                steps: [
                    "Whisk dry ingredients together in a bowl.",
                    "In another bowl combine buttermilk, eggs, and melted butter.",
                    "Fold wet into dry until just combined; lumps are fine.",
                    "Cook on a buttered griddle until bubbles form, then flip.",
                    "Serve warm with maple syrup."
                ]
            ),
            Recipe(
                title: "Honey Garlic Glazed Salmon",
                summary: "Pan-seared salmon with a sticky sweet-savory glaze.",
                category: .dinner,
                servings: 2,
                prepMinutes: 8,
                cookMinutes: 12,
                rating: 5,
                ingredients: [
                    Ingredient(name: "salmon fillets", quantity: "2", aisle: .meat, sortIndex: 0),
                    Ingredient(name: "honey", quantity: "3 tbsp", aisle: .pantry, sortIndex: 1),
                    Ingredient(name: "soy sauce", quantity: "2 tbsp", aisle: .pantry, sortIndex: 2),
                    Ingredient(name: "garlic", quantity: "2 cloves", aisle: .produce, sortIndex: 3),
                    Ingredient(name: "lemon", quantity: "1", aisle: .produce, sortIndex: 4)
                ],
                steps: [
                    "Pat salmon dry and season with salt and pepper.",
                    "Sear skin-side down in a hot pan for 4 minutes.",
                    "Flip, add honey, soy, garlic, and a squeeze of lemon.",
                    "Spoon the glaze over the fish until thick and sticky.",
                    "Rest for a minute and serve."
                ]
            ),
            Recipe(
                title: "Dark Chocolate Lava Cakes",
                summary: "Individual cakes with a molten chocolate center.",
                category: .dessert,
                servings: 4,
                prepMinutes: 15,
                cookMinutes: 12,
                rating: 5,
                isFavorite: true,
                ingredients: [
                    Ingredient(name: "dark chocolate", quantity: "6 oz", aisle: .pantry, sortIndex: 0),
                    Ingredient(name: "butter", quantity: "1/2 cup", aisle: .dairy, sortIndex: 1),
                    Ingredient(name: "eggs", quantity: "2 whole + 2 yolks", aisle: .dairy, sortIndex: 2),
                    Ingredient(name: "sugar", quantity: "1/4 cup", aisle: .pantry, sortIndex: 3),
                    Ingredient(name: "flour", quantity: "2 tbsp", aisle: .pantry, sortIndex: 4)
                ],
                steps: [
                    "Melt chocolate and butter together until smooth.",
                    "Whisk eggs, yolks, and sugar until pale.",
                    "Fold in chocolate then flour.",
                    "Pour into buttered ramekins.",
                    "Bake at 425°F for 12 minutes until edges set; serve warm."
                ]
            ),
            Recipe(
                title: "Crunchy Thai Peanut Salad",
                summary: "Crisp veggies tossed in a zingy peanut-lime dressing.",
                category: .lunch,
                servings: 2,
                prepMinutes: 20,
                cookMinutes: 0,
                rating: 4,
                ingredients: [
                    Ingredient(name: "shredded cabbage", quantity: "3 cups", aisle: .produce, sortIndex: 0),
                    Ingredient(name: "carrots", quantity: "2", aisle: .produce, sortIndex: 1),
                    Ingredient(name: "bell pepper", quantity: "1", aisle: .produce, sortIndex: 2),
                    Ingredient(name: "peanut butter", quantity: "1/4 cup", aisle: .pantry, sortIndex: 3),
                    Ingredient(name: "lime", quantity: "1", aisle: .produce, sortIndex: 4),
                    Ingredient(name: "peanuts", quantity: "1/3 cup", aisle: .pantry, sortIndex: 5)
                ],
                steps: [
                    "Whisk peanut butter, lime juice, soy, and a little water.",
                    "Slice all vegetables thinly.",
                    "Toss vegetables with the dressing.",
                    "Top with crushed peanuts and serve cold."
                ]
            ),
            Recipe(
                title: "Iced Vanilla Oat Latte",
                summary: "Smooth cold latte sweetened with vanilla and oat milk.",
                category: .drink,
                servings: 1,
                prepMinutes: 5,
                cookMinutes: 0,
                rating: 4,
                ingredients: [
                    Ingredient(name: "espresso", quantity: "2 shots", aisle: .beverages, sortIndex: 0),
                    Ingredient(name: "oat milk", quantity: "1 cup", aisle: .dairy, sortIndex: 1),
                    Ingredient(name: "vanilla syrup", quantity: "1 tbsp", aisle: .pantry, sortIndex: 2),
                    Ingredient(name: "ice", quantity: "1 cup", aisle: .other, sortIndex: 3)
                ],
                steps: [
                    "Brew espresso and let cool slightly.",
                    "Fill a glass with ice.",
                    "Add vanilla syrup and oat milk.",
                    "Pour espresso over and stir."
                ]
            )
        ]
    }
}
