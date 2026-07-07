import Foundation

final class WeatherController: ObservableObject {
    @Published var temperature: Double?
    @Published var conditionSymbol = "cloud.sun.fill"
    @Published var conditionText = ""
    @Published var cityLabel = ""
    @Published var countryCode: String?
    @Published var isLoading = false
    @Published var statusMessage = "Add a city in ⚙ settings"

    @Published var locationQuery: String {
        didSet {
            UserDefaults.standard.set(locationQuery, forKey: Keys.location)
            refresh()
        }
    }

    private var timer: Timer?
    private let session: URLSession

    private enum Keys {
        static let location = "weather.location"
    }

    init() {
        locationQuery = UserDefaults.standard.string(forKey: Keys.location) ?? ""
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let query = locationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.temperature = nil
                self.conditionText = ""
                self.cityLabel = ""
                self.countryCode = nil
                self.statusMessage = "Add a city in ⚙ settings"
                self.isLoading = false
            }
            return
        }

        DispatchQueue.main.async {
            self.isLoading = true
            self.statusMessage = ""
        }

        geocode(city: query) { [weak self] coordinate in
            guard let self else { return }
            guard let coordinate else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.statusMessage = "Could not find “\(query)”"
                }
                return
            }

            self.fetchForecast(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                label: coordinate.label,
                countryCode: coordinate.countryCode
            )
        }
    }

    private struct Coordinate {
        let latitude: Double
        let longitude: Double
        let label: String
        let countryCode: String?
    }

    private func geocode(city: String, completion: @escaping (Coordinate?) -> Void) {
        guard let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            completion(nil)
            return
        }

        session.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let latitude = first["latitude"] as? Double,
                  let longitude = first["longitude"] as? Double else {
                completion(nil)
                return
            }

            let name = first["name"] as? String ?? city
            let admin = first["admin1"] as? String
            let country = first["country_code"] as? String
            let label = [name, admin].compactMap { $0 }.joined(separator: ", ")
            completion(Coordinate(
                latitude: latitude,
                longitude: longitude,
                label: label,
                countryCode: country
            ))
        }.resume()
    }

    private func fetchForecast(latitude: Double, longitude: Double, label: String, countryCode: String?) {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,weather_code&temperature_unit=fahrenheit"
        guard let url = URL(string: urlString) else { return }

        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isLoading = false
            }

            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temperature = current["temperature_2m"] as? Double,
                  let code = current["weather_code"] as? Int else {
                DispatchQueue.main.async {
                    self.statusMessage = "Weather unavailable"
                }
                return
            }

            let mapped = Self.mapWeatherCode(code)
            DispatchQueue.main.async {
                self.temperature = temperature
                self.conditionSymbol = mapped.symbol
                self.conditionText = mapped.text
                self.cityLabel = label
                self.countryCode = countryCode
                self.statusMessage = ""
            }
        }.resume()
    }

    private static func mapWeatherCode(_ code: Int) -> (symbol: String, text: String) {
        switch code {
        case 0:
            return ("sun.max.fill", "Clear")
        case 1, 2, 3:
            return ("cloud.sun.fill", "Partly Cloudy")
        case 45, 48:
            return ("cloud.fog.fill", "Foggy")
        case 51, 53, 55, 56, 57:
            return ("cloud.drizzle.fill", "Drizzle")
        case 61, 63, 65, 66, 67, 80, 81, 82:
            return ("cloud.rain.fill", "Rain")
        case 71, 73, 75, 77, 85, 86:
            return ("cloud.snow.fill", "Snow")
        case 95, 96, 99:
            return ("cloud.bolt.rain.fill", "Thunderstorm")
        default:
            return ("cloud.fill", "Cloudy")
        }
    }
}
