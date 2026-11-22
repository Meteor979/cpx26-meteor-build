import Combine
import CoreLocation
import Foundation

@MainActor
final class WeatherContextStore: NSObject, ObservableObject {
    @Published private(set) var context: WeatherContext = .demo
    @Published private(set) var errorMessage: String?
    @Published private(set) var isEnabled: Bool

    private let service: WeatherServiceProtocol
    let cache: WeatherCacheStore
    private let defaults: UserDefaults
    private let locationManager: CLLocationManager
    private var isRequestInFlight = false
    private var requestGeneration = 0

    var status: WeatherContextStatus {
        context.status
    }

    init(
        service: WeatherServiceProtocol = WeatherService(),
        cache: WeatherCacheStore = WeatherCacheStore(),
        locationManager: CLLocationManager = CLLocationManager(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.cache = cache
        self.locationManager = locationManager
        self.defaults = defaults
        self.isEnabled = defaults.bool(forKey: "wearwise.weather.enabled")

        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLDistanceFilterNone

        if
            isEnabled,
            locationManager.authorizationStatus == .denied
                || locationManager.authorizationStatus == .restricted
        {
            showPermissionDenied()
        } else if isEnabled, let entry = cache.loadLatest() {
            context = context(from: entry, status: .stale)
        }
    }

    func useCurrentWeather() {
        requestGeneration += 1
        isEnabled = true
        defaults.set(true, forKey: "wearwise.weather.enabled")
        errorMessage = nil

        switch locationManager.authorizationStatus {
        case .notDetermined:
            context = WeatherContext(
                weather: context.weather,
                status: .loading,
                source: context.source,
                locationLabel: context.locationLabel,
                observedAt: context.observedAt,
                updatedAt: context.updatedAt
            )
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestOneLocation()
        case .denied, .restricted:
            showPermissionDenied()
        @unknown default:
            showPermissionDenied()
        }
    }

    func updateWeather() {
        useCurrentWeather()
    }

    func recheckAuthorization() {
        handleAuthorization(locationManager.authorizationStatus)
    }

    func useDemoWeather() {
        requestGeneration += 1
        isEnabled = false
        defaults.set(false, forKey: "wearwise.weather.enabled")
        locationManager.stopUpdatingLocation()
        isRequestInFlight = false
        errorMessage = nil
        context = .demo
    }

    func loadWeather(for coordinates: WeatherCoordinates) async {
        guard !isRequestInFlight else {
            return
        }
        isRequestInFlight = true
        defer { isRequestInFlight = false }
        let generation = requestGeneration

        let keyHash = coordinates.cacheKeyHash()
        if let cached = cache.loadForLocation(keyHash: keyHash) {
            errorMessage = nil
            context = context(from: cached, status: .stale)
            return
        }

        context = WeatherContext(
            weather: context.weather,
            status: .loading,
            source: context.source,
            locationLabel: context.locationLabel,
            observedAt: context.observedAt,
            updatedAt: context.updatedAt
        )

        let request = WeatherRequest(
            requestID: "ios-weather-\(UUID().uuidString.lowercased())",
            latitude: coordinates.latitude,
            longitude: coordinates.longitude,
            accuracyM: coordinates.accuracyM,
            timezone: coordinates.timezone,
            targetAt: nil
        )

        do {
            let response = try await service.fetchCurrentWeather(request)
            guard let nextContext = WeatherContext.from(response: response) else {
                fallbackAfterFailure(
                    message: "Weather unavailable",
                    generation: generation
                )
                return
            }
            guard isEnabled, generation == requestGeneration else {
                return
            }
            cache.save(response: response, keyHash: keyHash)
            context = nextContext
            errorMessage = nil
        } catch {
            fallbackAfterFailure(
                message: "Weather unavailable",
                generation: generation
            )
        }
    }

    internal func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard isEnabled else {
            return
        }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            requestOneLocation()
        case .denied, .restricted:
            showPermissionDenied()
        case .notDetermined:
            break
        @unknown default:
            showPermissionDenied()
        }
    }

    internal func handleLocation(
        latitude: Double,
        longitude: Double,
        accuracy: Double
    ) {
        guard isEnabled else {
            return
        }
        locationManager.stopUpdatingLocation()
        let roundedLatitude = (latitude * 100).rounded() / 100
        let roundedLongitude = (longitude * 100).rounded() / 100
        let safeAccuracy =
            accuracy > 0
            ? max(1_000, min(accuracy.rounded(), 5_000))
            : 1_200
        let coordinates = WeatherCoordinates(
            latitude: roundedLatitude,
            longitude: roundedLongitude,
            accuracyM: safeAccuracy,
            timezone: TimeZone.current.identifier
        )
        Task {
            await loadWeather(for: coordinates)
        }
    }

    internal func handleLocationFailure() {
        guard isEnabled else {
            return
        }
        fallbackAfterFailure(
            message: "Weather unavailable",
            generation: requestGeneration
        )
    }

    private func requestOneLocation() {
        errorMessage = nil
        context = WeatherContext(
            weather: context.weather,
            status: .loading,
            source: context.source,
            locationLabel: context.locationLabel,
            observedAt: context.observedAt,
            updatedAt: context.updatedAt
        )
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestLocation()
    }

    private func showPermissionDenied() {
        errorMessage = "Location access is off"
        context = WeatherContext(
            weather: .demo,
            status: .permissionDenied,
            source: .mock,
            locationLabel: nil,
            observedAt: nil,
            updatedAt: nil
        )
    }

    private func fallbackAfterFailure(
        message: String,
        generation: Int
    ) {
        guard isEnabled, generation == requestGeneration else {
            return
        }
        if let cached = cache.loadLatest() {
            context = context(from: cached, status: .stale)
            errorMessage = nil
        } else {
            context = WeatherContext(
                weather: .demo,
                status: .unavailable,
                source: .mock,
                locationLabel: nil,
                observedAt: nil,
                updatedAt: nil
            )
            errorMessage = message
        }
    }

    private func context(
        from entry: WeatherCacheEntry,
        status: WeatherContextStatus
    ) -> WeatherContext {
        WeatherContext(
            weather: entry.weather,
            status: status,
            source: .cache,
            locationLabel: entry.locationLabel,
            observedAt: entry.observedAt,
            updatedAt: entry.fetchedAt
        )
    }
}

extension WeatherContextStore: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(
        _ manager: CLLocationManager
    ) {
        let authorizationStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            self?.handleAuthorization(authorizationStatus)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.first else {
            Task { @MainActor [weak self] in
                self?.handleLocationFailure()
            }
            return
        }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let accuracy = location.horizontalAccuracy
        Task { @MainActor [weak self] in
            self?.handleLocation(
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.handleLocationFailure()
        }
    }
}
