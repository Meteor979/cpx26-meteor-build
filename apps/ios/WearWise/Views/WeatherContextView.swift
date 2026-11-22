import SwiftUI
import UIKit

enum WeatherUICopy {
    static let weather = "Weather"
    static let useCurrent = "Use current weather"
    static let update = "Update weather"
    static let updated = "Weather updated"
    static let demo = "Using demo weather"
    static let useDemo = "Use demo weather"
    static let loading = "Loading weather"
    static let mock = "Mock weather"
    static let cached = "Cached weather"
    static let unavailable = "Weather unavailable"
    static let locationOff = "Location access is off"
    static let tryAgain = "Try again"
}

struct WeatherContextView: View {
    @EnvironmentObject private var weatherStore: WeatherContextStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var context: WeatherContext {
        weatherStore.context
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.title2.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(WeatherUICopy.weather)
                        .font(.headline)
                    Text(statusTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if context.status == .loading {
                    ProgressView()
                        .accessibilityLabel(WeatherUICopy.loading)
                }
            }

            Text(context.weather.summaryLine)
                .font(.title3.weight(.bold))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) {
                    weatherDetail(context.weather.detailLine)
                    weatherDetail(context.weather.rainLine)
                }

                VStack(alignment: .leading, spacing: 5) {
                    weatherDetail(context.weather.detailLine)
                    weatherDetail(context.weather.rainLine)
                }
            }

            if let label = context.locationLabel, !label.isEmpty {
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = weatherStore.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                if context.status == .permissionDenied {
                    guard
                        let settingsURL = URL(
                            string: UIApplication.openSettingsURLString
                        )
                    else {
                        return
                    }
                    openURL(settingsURL)
                } else if context.status == .ok || context.status == .stale {
                    weatherStore.updateWeather()
                } else {
                    weatherStore.useCurrentWeather()
                }
            } label: {
                Label(primaryActionTitle, systemImage: primaryActionIcon)
            }
            .buttonStyle(WearWisePrimaryButtonStyle())
            .disabled(context.status == .loading)
            .accessibilityHint(primaryActionHint)

            if weatherStore.isEnabled {
                Button {
                    weatherStore.useDemoWeather()
                } label: {
                    Label(WeatherUICopy.useDemo, systemImage: "cloud.sun.fill")
                }
                .buttonStyle(WearWiseSecondaryButtonStyle())
            }
        }
        .wearWiseCard()
        .accessibilityElement(children: .contain)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                weatherStore.recheckAuthorization()
            }
        }
    }

    private var statusTitle: String {
        switch context.status {
        case .demo: WeatherUICopy.demo
        case .loading: WeatherUICopy.loading
        case .ok:
            context.source == .mock ? WeatherUICopy.mock : WeatherUICopy.updated
        case .stale: WeatherUICopy.cached
        case .unavailable: WeatherUICopy.unavailable
        case .permissionDenied: WeatherUICopy.locationOff
        }
    }

    private var statusIcon: String {
        switch context.status {
        case .demo: "cloud.sun"
        case .loading: "location.circle"
        case .ok, .stale: "checkmark.circle"
        case .unavailable: "exclamationmark.circle"
        case .permissionDenied: "location.slash"
        }
    }

    private var primaryActionTitle: String {
        switch context.status {
        case .demo: WeatherUICopy.useCurrent
        case .loading: WeatherUICopy.loading
        case .ok, .stale: WeatherUICopy.update
        case .unavailable, .permissionDenied: WeatherUICopy.tryAgain
        }
    }

    private var primaryActionIcon: String {
        context.status == .permissionDenied
            ? "gearshape.fill"
            : "location.fill"
    }

    private var primaryActionHint: String {
        context.status == .permissionDenied
            ? "Opens Settings so location access can be enabled."
            : "Requests approximate location once for local weather."
    }

    private func weatherDetail(_ text: String) -> some View {
        Text(text)
            .font(.body.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)
    }
}
