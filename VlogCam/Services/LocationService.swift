import CoreLocation

@MainActor
final class LocationService: ObservableObject {
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private var updatesTask: Task<Void, Never>?

    init() {
        authorizationStatus = manager.authorizationStatus
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        guard updatesTask == nil else { return }
        updatesTask = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.default) {
                    if let location = update.location {
                        self.lastLocation = location
                    }
                    if Task.isCancelled { break }
                }
            } catch {
                // Location updates ended
            }
        }
    }

    func stopUpdates() {
        updatesTask?.cancel()
        updatesTask = nil
    }
}
