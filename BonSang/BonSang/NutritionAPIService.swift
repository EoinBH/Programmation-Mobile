import Foundation

final class NutritionAPIService {
    static let shared = NutritionAPIService()

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let session: URLSession

    /// Remplace par ton URL ngrok / domaine en prod.
    private let baseURL = URL(string: "http://localhost:3000")!

    private init(session: URLSession = .shared) {
        self.session = session

        decoder = JSONDecoder()
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
    }

    func searchFoods(query: String) async throws -> FoodSearchResponse {
        try await request(
            path: "/nutrition/search",
            method: "POST",
            body: ["query": query],
            responseType: FoodSearchResponse.self
        )
    }

    func analyzeMeal(foods: [MealFoodDraft], mealTakenAt: Date) async throws -> MealHistoryItem {
        let requestBody = AnalyzeMealRequest(
            foods: foods,
            mealTakenAt: ISO8601DateFormatter().string(from: mealTakenAt)
        )

        return try await request(
            path: "/nutrition/analyze-meal",
            method: "POST",
            body: requestBody,
            responseType: MealHistoryItem.self
        )
    }

    func fetchHistory() async throws -> [MealHistoryItem] {
        try await request(
            path: "/nutrition/history",
            method: "GET",
            responseType: [MealHistoryItem].self
        )
    }

    func updateMeal(mealID: String, foods: [MealFoodDraft], mealTakenAt: Date) async throws -> MealHistoryItem {
        let requestBody = AnalyzeMealRequest(
            foods: foods,
            mealTakenAt: ISO8601DateFormatter().string(from: mealTakenAt)
        )

        return try await request(
            path: "/nutrition/history/\(mealID)",
            method: "PUT",
            body: requestBody,
            responseType: MealHistoryItem.self
        )
    }

    func deleteMeal(mealID: String) async throws {
        _ = try await request(
            path: "/nutrition/history/\(mealID)",
            method: "DELETE",
            responseType: DeleteMealResponse.self
        )
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        responseType: T.Type
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response, as: responseType)
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        responseType: T.Type
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)
        return try decodeResponse(data: data, response: response, as: responseType)
    }

    private func decodeResponse<T: Decodable>(data: Data, response: URLResponse, as type: T.Type) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw apiError
            }
            throw NSError(domain: "NutritionAPIService", code: httpResponse.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Erreur serveur (\(httpResponse.statusCode))."
            ])
        }

        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw NSError(domain: "NutritionAPIService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Décodage impossible : \(error.localizedDescription)"
            ])
        }
    }
}
