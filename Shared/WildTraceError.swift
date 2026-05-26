import Foundation

enum WildTraceError: LocalizedError {
    case healthDataUnavailable
    case authorizationDenied
    case invalidDateRange
    case missingHealthKitType(String)
    case invalidPARURL
    case invalidObjectPath
    case invalidServerResponse
    case uploadFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            return "Les données Santé ne sont pas disponibles sur cet appareil."
        case .authorizationDenied:
            return "L’autorisation HealthKit a été refusée ou interrompue."
        case .invalidDateRange:
            return "La plage de dates est invalide."
        case .missingHealthKitType(let type):
            return "Type HealthKit indisponible : \(type)."
        case .invalidPARURL:
            return "URL PAR Oracle Cloud invalide."
        case .invalidObjectPath:
            return "Chemin objet Oracle Cloud invalide."
        case .invalidServerResponse:
            return "Réponse serveur invalide."
        case .uploadFailed(let statusCode):
            return "Upload OCI échoué. Code HTTP : \(statusCode)."
        }
    }
}
