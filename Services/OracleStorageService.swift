import Foundation

final class OracleStorageService {
    func upload(data: Data, objectPath: String, parBaseURL: String) async throws {
        let url = try makeObjectURL(parBaseURL: parBaseURL, objectPath: objectPath)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WildTraceError.invalidServerResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw WildTraceError.uploadFailed(statusCode: httpResponse.statusCode)
        }
    }

    private func makeObjectURL(parBaseURL: String, objectPath: String) throws -> URL {
        var base = parBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !base.isEmpty else {
            throw WildTraceError.invalidPARURL
        }

        if !base.hasSuffix("/") {
            base.append("/")
        }

        guard let encodedPath = objectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: base + encodedPath) else {
            throw WildTraceError.invalidObjectPath
        }

        return url
    }
}
