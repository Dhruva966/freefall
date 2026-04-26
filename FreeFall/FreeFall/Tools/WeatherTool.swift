import CoreLocation
import Foundation
import FoundationModels

@available(iOS 26, *)
final class WeatherTool: Tool {
    typealias Output = String

    let name = "getWeather"
    let description = "Get current weather for a city. Use when user asks about weather, temperature, rain, forecast."

    @Generable
    struct Arguments {
        @Guide(description: "City name to get weather for, e.g. 'San Francisco'. Use 'here' if user didn't specify.")
        var city: String

        @Guide(description: "'today' for current conditions or 'tomorrow' for tomorrow's forecast.")
        var when: String
    }

    func call(arguments: Arguments) async throws -> String {
        let city = arguments.city == "here" ? "New York" : arguments.city
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.geocodeAddressString(city)
        guard let location = placemarks.first?.location else {
            return "Couldn't find location for \(city)."
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let isTomorrow = arguments.when.lowercased().contains("tomorrow")

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,weathercode&temperature_unit=fahrenheit&timezone=auto&forecast_days=2"
        guard let url = URL(string: urlString) else { return "Weather unavailable." }

        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daily = json["daily"] as? [String: Any],
              let maxTemps = daily["temperature_2m_max"] as? [Double],
              let minTemps = daily["temperature_2m_min"] as? [Double],
              let codes = daily["weathercode"] as? [Int] else {
            return "Weather data unavailable."
        }

        let idx = isTomorrow ? 1 : 0
        guard idx < maxTemps.count else { return "Forecast unavailable." }

        let max = Int(maxTemps[idx])
        let min = Int(minTemps[idx])
        let condition = weatherDescription(for: codes[idx])
        let day = isTomorrow ? "Tomorrow" : "Today"

        return "\(day) in \(city): \(condition), \(min)–\(max)°F."
    }

    private func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1, 2, 3: return "Partly cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rainy"
        case 71, 73, 75: return "Snowy"
        case 80, 81, 82: return "Rain showers"
        case 95: return "Thunderstorms"
        default: return "Mixed conditions"
        }
    }
}
