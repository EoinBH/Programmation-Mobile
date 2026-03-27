import Foundation

struct FoodSearchResponse: Decodable {
    let originalQuery: String
    let translatedQuery: String
    let results: [FoodSearchResult]

    enum CodingKeys: String, CodingKey {
        case originalQuery = "original_query"
        case translatedQuery = "translated_query"
        case results
    }
}

struct FoodSearchResult: Codable, Hashable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandName: String?

    enum CodingKeys: String, CodingKey {
        case fdcId
        case description
        case dataType
        case brandName
    }
}

struct MealFoodDraft: Codable, Hashable {
    let fdcId: Int
    let description: String
    var grams: Double
}

struct AnalyzeMealRequest: Encodable {
    let foods: [MealFoodDraft]
    let mealTakenAt: String

    enum CodingKeys: String, CodingKey {
        case foods
        case mealTakenAt = "meal_taken_at"
    }
}

struct MealHistoryItem: Codable, Hashable {
    let id: String
    let createdAt: String
    let updatedAt: String
    let mealTakenAt: String
    let items: [AnalyzedFoodItem]
    let totals: MealTotals
    let glycemicImpact: GlycemicImpact
    let note: String?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case mealTakenAt = "meal_taken_at"
        case items
        case totals
        case glycemicImpact = "glycemic_impact"
        case note
    }
}

struct AnalyzedFoodItem: Codable, Hashable {
    let fdcId: Int?
    let description: String?
    let grams: Double?
    let found: Bool
    let carbohydratesTotalG: Double?
    let fatTotalG: Double?
    let fiberG: Double?
    let sugarG: Double?
    let proteinG: Double?
    let calories: Double?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case fdcId
        case description
        case grams
        case found
        case carbohydratesTotalG = "carbohydrates_total_g"
        case fatTotalG = "fat_total_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case proteinG = "protein_g"
        case calories
        case error
    }
}

struct MealTotals: Codable, Hashable {
    let carbohydratesTotalG: Double
    let fatTotalG: Double
    let fiberG: Double
    let sugarG: Double
    let proteinG: Double
    let calories: Double
    let netCarbsG: Double

    enum CodingKeys: String, CodingKey {
        case carbohydratesTotalG = "carbohydrates_total_g"
        case fatTotalG = "fat_total_g"
        case fiberG = "fiber_g"
        case sugarG = "sugar_g"
        case proteinG = "protein_g"
        case calories
        case netCarbsG = "net_carbs_g"
    }
}

struct GlycemicImpact: Codable, Hashable {
    let score: Double
    let level: String
    let message: String
}

struct DeleteMealResponse: Decodable {
    let success: Bool
    let message: String
    let deletedID: String

    enum CodingKeys: String, CodingKey {
        case success
        case message
        case deletedID = "deleted_id"
    }
}

struct APIErrorResponse: Decodable, Error {
    let error: String
    let details: String?
}
