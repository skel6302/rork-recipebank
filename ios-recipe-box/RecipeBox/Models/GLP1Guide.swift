//
//  GLP1Guide.swift
//  RecipeBox
//

import SwiftUI

/// A single tip inside a guide section.
struct GuideTip: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

/// A themed section of the GLP-1 education guide.
struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let tint: Color
    let intro: String
    let tips: [GuideTip]
}

/// Curated, bundled GLP-1 education content. Kept in-app (no network) so it's
/// fast and reliable. General wellness guidance — not medical advice.
enum GLP1Guide {
    static let sections: [GuideSection] = [
        GuideSection(
            title: "Eat more of",
            symbol: "leaf.fill",
            tint: Theme.sage,
            intro: "Appetite drops on GLP-1s, so make the calories you do eat count — protein first, then fiber and fluids.",
            tips: [
                GuideTip(title: "Lean protein at every meal", detail: "Aim for 20–30g per meal — eggs, Greek yogurt, chicken, fish, tofu, beans. Protein protects muscle while you lose weight."),
                GuideTip(title: "Fiber-rich vegetables", detail: "Leafy greens, broccoli, berries and legumes ease constipation, a common side effect, and help you feel satisfied."),
                GuideTip(title: "Hydrate constantly", detail: "Sip water through the day. Many \u{201C}hunger\u{201D} and nausea signals are really mild dehydration. Track your glasses on the Calories tab."),
                GuideTip(title: "Healthy fats in moderation", detail: "Avocado, olive oil, nuts and seeds add steady energy and help nutrient absorption without large portions."),
            ]
        ),
        GuideSection(
            title: "Go easy on",
            symbol: "exclamationmark.triangle.fill",
            tint: Theme.amber,
            intro: "These foods most often trigger nausea, reflux or \u{201C}sulfur burps\u{201D} while your stomach empties more slowly.",
            tips: [
                GuideTip(title: "Fried & greasy foods", detail: "High-fat, fried meals sit heavy and are the #1 nausea trigger. Bake, grill or air-fry instead."),
                GuideTip(title: "Sugary foods & drinks", detail: "Sweets and sodas can spike then crash energy and worsen queasiness. Save them for rare treats."),
                GuideTip(title: "Carbonated drinks", detail: "Bubbles add gas and bloating on top of slower digestion. Flat water or herbal tea is gentler."),
                GuideTip(title: "Alcohol", detail: "GLP-1s can heighten alcohol's effects and irritate the stomach. Keep it minimal and never on an empty stomach."),
                GuideTip(title: "Very large portions", detail: "Your stomach empties slower now — big plates lead to discomfort. Smaller, frequent meals work better."),
            ]
        ),
        GuideSection(
            title: "Managing side effects",
            symbol: "cross.case.fill",
            tint: Theme.spice,
            intro: "Most side effects are mild and fade as your body adjusts — especially after the first week of each dose step-up.",
            tips: [
                GuideTip(title: "Nausea", detail: "Eat smaller, blander meals; stop before you're full. Ginger, peppermint tea and cool foods can help. It usually eases within days."),
                GuideTip(title: "Constipation", detail: "Increase fiber and water, and stay active. A daily walk and magnesium-rich foods often help keep things moving."),
                GuideTip(title: "Sulfur (\u{201C}rotten egg\u{201D}) burps", detail: "Often linked to high-fat or high-sulfur foods (eggs, garlic, red meat). Smaller, lower-fat meals reduce them."),
                GuideTip(title: "Fatigue", detail: "Eating less can mean less fuel. Prioritize protein, stay hydrated, and don't skip meals entirely."),
                GuideTip(title: "When to call your doctor", detail: "Severe or lasting belly pain, persistent vomiting, or signs of dehydration warrant a call to your prescriber promptly."),
            ]
        ),
        GuideSection(
            title: "Smart habits",
            symbol: "checkmark.seal.fill",
            tint: Color(red: 0.45, green: 0.40, blue: 0.70),
            intro: "Small routines make GLP-1s far more comfortable and effective.",
            tips: [
                GuideTip(title: "Protein first", detail: "Always start your plate with protein, then veggies, then carbs. You'll get the nutrients that matter before you fill up."),
                GuideTip(title: "Eat slowly & mindfully", detail: "Put the fork down between bites. With delayed stomach emptying, fullness creeps up — slow eating prevents overshooting."),
                GuideTip(title: "Stay consistent with timing", detail: "Take your dose on the same day/time each week (or daily for pills). Use the reminders in the Meds tab."),
                GuideTip(title: "Rybelsus pill rule", detail: "Take oral semaglutide on an empty stomach with a small sip of plain water, then wait 30 minutes before eating or other meds."),
                GuideTip(title: "Rotate injection sites", detail: "Alternate abdomen, thigh and upper arm to avoid soreness and lumps. The Meds tab suggests your next site automatically."),
            ]
        ),
    ]
}
