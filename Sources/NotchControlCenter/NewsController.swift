import Combine
import Foundation

struct NewsHeadline: Identifiable, Equatable {
    let id: String
    let title: String
    let source: String
}

final class NewsController: ObservableObject {
    @Published var headlines: [NewsHeadline] = []
    @Published var isLoading = false
    @Published var statusMessage = ""

    weak var weatherController: WeatherController?
    private var cancellables = Set<AnyCancellable>()

    private var timer: Timer?
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    var regionCode: String {
        weatherController?.countryCode ?? "US"
    }

    var regionLabel: String {
        NewsRegionCatalog.displayName(for: regionCode)
    }

    var regionSubtitle: String {
        if weatherController?.locationQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            return "US headlines · set Weather city to localize"
        }
        return "Headlines for \(regionLabel)"
    }

    func bind(to weather: WeatherController) {
        weatherController = weather

        weather.$countryCode
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    var feedURLs: [URL] {
        NewsRegionCatalog.feeds(for: regionCode)
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
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
        let feeds = feedURLs
        guard !feeds.isEmpty else {
            headlines = []
            statusMessage = "No news feeds for \(regionLabel)"
            return
        }

        isLoading = true
        statusMessage = ""

        let group = DispatchGroup()
        var fetched: [NewsHeadline] = []
        let lock = NSLock()

        for url in feeds {
            group.enter()
            fetchFeed(url) { items in
                defer { group.leave() }
                lock.lock()
                fetched.append(contentsOf: items)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            if fetched.isEmpty {
                self.headlines = []
                self.statusMessage = "Could not load \(self.regionLabel) headlines"
            } else {
                self.headlines = Array(fetched.prefix(12))
            }
        }
    }

    private func fetchFeed(_ url: URL, completion: @escaping ([NewsHeadline]) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            guard let data, let xml = String(data: data, encoding: .utf8) else {
                completion([])
                return
            }

            let source = Self.sourceLabel(for: url)
            let titles = Self.parseTitles(from: xml)
            let items = titles.prefix(6).enumerated().map { index, title in
                NewsHeadline(id: "\(source)-\(index)-\(title.hashValue)", title: title, source: source)
            }
            completion(items)
        }.resume()
    }

    private static func sourceLabel(for url: URL) -> String {
        if url.host?.contains("google.com") == true {
            return "Google News"
        }
        if url.host?.contains("npr.org") == true {
            return "NPR"
        }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? "News"
    }

    private static func parseTitles(from xml: String) -> [String] {
        var titles: [String] = []
        let pattern = "<title><!\\[CDATA\\[(.*?)\\]\\]></title>|<title>(.*?)</title>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return titles
        }

        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        regex.enumerateMatches(in: xml, options: [], range: range) { match, _, _ in
            guard let match else { return }
            if match.range(at: 1).location != NSNotFound,
               let r = Range(match.range(at: 1), in: xml) {
                titles.append(String(xml[r]))
            } else if match.range(at: 2).location != NSNotFound,
                      let r = Range(match.range(at: 2), in: xml) {
                titles.append(String(xml[r]))
            }
        }

        return titles.filter { title in
            let lower = title.lowercased()
            return !lower.contains("bbc news") && !lower.contains("google news")
                && !lower.contains("rss") && !lower.contains("npr") && title.count > 12
        }
    }
}
