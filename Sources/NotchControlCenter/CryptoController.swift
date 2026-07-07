import Foundation

struct CryptoQuote: Identifiable, Equatable {
    let id: String
    let symbol: String
    let price: Double
    let changePercent: Double

    var isUp: Bool { changePercent >= 0 }

    var displaySymbol: String {
        symbol.replacingOccurrences(of: "-USD", with: "")
    }

    var formattedPrice: String {
        if price >= 1000 {
            return String(format: "$%.0f", price)
        }
        if price >= 1 {
            return String(format: "$%.2f", price)
        }
        return String(format: "$%.4f", price)
    }

    var formattedChange: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercent))%"
    }
}

final class CryptoController: ObservableObject {
    @Published var quotes: [CryptoQuote] = []
    @Published var isLoading = false
    @Published var statusMessage = ""

    @Published var watchlistText: String {
        didSet {
            UserDefaults.standard.set(watchlistText, forKey: Keys.watchlist)
            refresh()
        }
    }

    private var timer: Timer?
    private let session: URLSession

    private enum Keys {
        static let watchlist = "crypto.watchlist"
    }

    init() {
        watchlistText = UserDefaults.standard.string(forKey: Keys.watchlist) ?? "BTC-USD,ETH-USD,SOL-USD"
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    var symbols: [String] {
        watchlistText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
            .filter { !$0.isEmpty }
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
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
        let symbols = symbols
        guard !symbols.isEmpty else {
            quotes = []
            statusMessage = "Add symbols in ⚙ settings"
            return
        }

        isLoading = true
        statusMessage = ""

        let group = DispatchGroup()
        var fetched: [CryptoQuote] = []
        let lock = NSLock()

        for symbol in symbols {
            group.enter()
            fetchQuote(symbol: symbol) { quote in
                defer { group.leave() }
                guard let quote else { return }
                lock.lock()
                fetched.append(quote)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            if fetched.isEmpty {
                self.quotes = []
                self.statusMessage = "Could not fetch crypto prices"
            } else {
                let order = symbols
                self.quotes = fetched.sorted {
                    (order.firstIndex(of: $0.symbol) ?? 999) < (order.firstIndex(of: $1.symbol) ?? 999)
                }
            }
        }
    }

    private func fetchQuote(symbol: String, completion: @escaping (CryptoQuote?) -> Void) {
        guard let url = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        session.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let first = results.first,
                  let meta = first["meta"] as? [String: Any],
                  let price = meta["regularMarketPrice"] as? Double else {
                completion(nil)
                return
            }

            let previous = meta["chartPreviousClose"] as? Double ?? price
            let change = previous > 0 ? ((price - previous) / previous) * 100 : 0
            let sym = meta["symbol"] as? String ?? symbol

            completion(CryptoQuote(id: sym, symbol: sym, price: price, changePercent: change))
        }.resume()
    }
}
