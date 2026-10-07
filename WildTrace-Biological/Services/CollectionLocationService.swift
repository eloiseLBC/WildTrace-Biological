import Foundation
import CoreLocation

@MainActor
final class CollectionLocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CollectionLocation, Error>?
    private var timeout: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func capture() async throws -> CollectionLocation {
        guard pending == nil else { throw CaptureError.busy }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { return }
                self?.finish(.failure(CaptureError.timeout))
            }
            requestIfAuthorized()
        }
    }

    private func requestIfAuthorized() {
        guard pending != nil else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            finish(.failure(CaptureError.denied))
        @unknown default:
            finish(.failure(CaptureError.denied))
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let now = Date()
        guard let location = locations.filter({
            CLLocationCoordinate2DIsValid($0.coordinate) &&
            $0.horizontalAccuracy.isFinite &&
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 100 &&
            abs($0.timestamp.timeIntervalSince(now)) <= 60
        }).min(by: { $0.horizontalAccuracy < $1.horizontalAccuracy }) else { return }

        finish(.success(CollectionLocation(
            timestamp: DateUtils.isoFormatter.string(from: location.timestamp),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            source: "iphone"
        )))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown { return }
        finish(.failure(error))
    }

    private func finish(_ result: Result<CollectionLocation, Error>) {
        guard let continuation = pending else { return }
        pending = nil
        timeout?.cancel()
        timeout = nil
        manager.stopUpdatingLocation()
        continuation.resume(with: result)
    }

    func resolve(_ sample: CollectionLocation) async throws -> CityCountry {
        // CLGeocoder is retained for the project's macOS/iOS compatibility.
        let geocoder = CLGeocoder()
        let watchdog = Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            geocoder.cancelGeocode()
        }
        defer { watchdog.cancel() }
        let placemarks = try await geocoder.reverseGeocodeLocation(
            CLLocation(latitude: sample.latitude, longitude: sample.longitude),
            preferredLocale: Locale(identifier: "fr_FR")
        )
        guard let place = placemarks.first else { return CityCountry() }
        if let water = place.ocean ?? place.inlandWater {
            return CityCountry(aquaticLocation: water)
        }
        let city = place.locality ?? place.subAdministrativeArea
        let address = [place.name, place.locality, place.administrativeArea, place.country]
            .compactMap { $0 }.reduce(into: [String]()) { result, part in
                if !result.contains(part) { result.append(part) }
            }.joined(separator: ", ")
        return CityCountry(city: city, country: place.country,
                           formattedAddress: address.isEmpty ? nil : address)
    }

    private enum CaptureError: LocalizedError {
        case denied, timeout, busy
        var errorDescription: String? {
            switch self {
            case .denied: return "Autorisation de localisation refusée."
            case .timeout: return "Aucune position récente et précise obtenue en 30 secondes."
            case .busy: return "Une capture de position est déjà en cours."
            }
        }
    }
}
