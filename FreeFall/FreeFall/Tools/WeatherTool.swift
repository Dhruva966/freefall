import Foundation
import FoundationModels
import MapKit
import WeatherKit

// Requires WeatherKit entitlement (com.apple.developer.weatherkit).
// Add to your App ID in developer.apple.com before running on device.
@available(iOS 26, *)
final class WeatherTool: Tool {
    typealias Output = String

    let name = "getWeather"
    let description = "Get current or forecast weather for a location and time. Use when the user asks about weather."

    @Generable
    struct Arguments {
        @Guide(description: "The location to get weather for, e.g. 'San Francisco' or 'Tokyo, Japan'.")
        var query: String

        @Guide(description: "Date and time in ISO 8601 format, e.g. '2026-04-26T15:30:00'. Use current date/time if not specified.")
        var datetime: String
    }

    func call(arguments: Arguments) async throws -> String {
        guard let geoRequest = MKGeocodingRequest(addressString: arguments.query) else {
            return "Couldn't build a geocoding request for '\(arguments.query)'."
        }
        let mapItems = try await geoRequest.mapItems
        guard let location = mapItems.first?.location else {
            return "Couldn't find a location matching '\(arguments.query)'."
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let requestedDate = formatter.date(from: arguments.datetime) ?? Date.now

        let weather = try await WeatherService.shared.weather(for: location)
        let isCurrentWeather = abs(requestedDate.timeIntervalSince(.now)) < 3600

        if isCurrentWeather {
            let c = weather.currentWeather
            return """
                Weather in \(arguments.query) right now:
                \(c.condition.rawValue), \(c.temperature.formatted())
                Feels like \(c.apparentTemperature.formatted())
                Humidity: \(Int(c.humidity * 100))%
                Wind: \(c.wind.speed.formatted()) \(c.wind.compassDirection.description)
                """
        } else {
            guard let forecast = weather.hourlyForecast.forecast.min(by: {
                abs($0.date.timeIntervalSince(requestedDate)) < abs($1.date.timeIntervalSince(requestedDate))
            }) else {
                return "No forecast available for that time."
            }
            return """
                Weather in \(arguments.query) at \(forecast.date.formatted(date: .abbreviated, time: .shortened)):
                \(forecast.condition.description), \(forecast.temperature.formatted())
                Precipitation chance: \(Int(forecast.precipitationChance * 100))%
                Wind: \(forecast.wind.speed.formatted())
                """
        }
    }
}
