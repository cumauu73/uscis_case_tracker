import Foundation

struct CaseStatusResponse: Decodable {
    let receiptNumber: String
    let formType: String
    let title: String
    let description: String
    let updatedAt: Date
}

enum CaseStatusServiceError: LocalizedError {
    case backendNotConfigured
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            "Live checking is not configured yet. Add your secure backend URL first."
        case .invalidResponse:
            "The status service returned an unexpected response."
        }
    }
}

struct CaseStatusService {
    func fetch(receiptNumber: String) async throws -> CaseStatusResponse {
        guard let baseURL = AppConfiguration.backendBaseURL else {
            throw CaseStatusServiceError.backendNotConfigured
        }

        let url = baseURL
            .appending(path: "v1")
            .appending(path: "cases")
            .appending(path: receiptNumber)
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CaseStatusServiceError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CaseStatusResponse.self, from: data)
    }
}

