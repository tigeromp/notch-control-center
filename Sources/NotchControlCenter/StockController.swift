import AppKit
import Foundation

struct StockQuote: Identifiable, Equatable {
    let id: String
    let symbol: String
    let name: String
    let price: Double
    let changePercent: Double

    var isUp: Bool { changePercent >= 0 }

    var formattedPrice: String {
        String(format: "$%.2f", price)
    }

    var formattedChange: String {
        let sign = changePercent >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.2f", changePercent))%"
    }
}

final class StockController: ObservableObject {
    @Published var quotes: [StockQuote] = []
    @Published var lastError: String?
    @Published var isLoading = false
    @Published var quoteFlashes: [String: UpdateFlashState] = [:]
    @Published var watchlistText: String {
        didSet {
            UserDefaults.standard.set(watchlistText, forKey: "stocks.watchlist")
            refresh()
        }
    }

    private var timer: Timer?
    private let session: URLSession
    private var refreshGeneration = 0
    private var lastAppliedRefreshGeneration = 0
    private var previousQuotes: [String: StockQuote] = [:]
    private var priceTimeline: [String: [(price: Double, date: Date)]] = [:]
    private var previousSparkTimestamps: [String: Int] = [:]
    private var latestSparkTimestamps: [String: Int] = [:]
    private(set) var isContentVisible = false
    private var pendingFlashSymbols: Set<String> = []

    static let refreshInterval: TimeInterval = 2

    init() {
        watchlistText = UserDefaults.standard.string(forKey: "stocks.watchlist")
            ?? "AAPL,TSLA,NVDA,MSFT,GOOGL"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
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
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
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

    func setContentVisible(_ visible: Bool) {
        let wasVisible = isContentVisible
        isContentVisible = visible
        if visible, !wasVisible {
            replayPendingFlashes()
            refresh()
        }
    }

    func refresh() {
        let symbols = symbols
        guard !symbols.isEmpty else {
            DispatchQueue.main.async {
                self.quotes = []
                self.lastError = "No tickers entered"
            }
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration

        if quotes.isEmpty {
            DispatchQueue.main.async {
                self.isLoading = true
                self.lastError = nil
            }
        }

        fetchQuotes(symbols: symbols) { [weak self] fetched in
            DispatchQueue.main.async {
                guard let self, generation >= self.lastAppliedRefreshGeneration else { return }
                self.lastAppliedRefreshGeneration = generation
                self.isLoading = false

                if fetched.isEmpty {
                    self.lastError = "Could not fetch quotes — check symbols"
                } else {
                    let order = symbols
                    let sorted = fetched.sorted {
                        (order.firstIndex(of: $0.symbol) ?? 999) < (order.firstIndex(of: $1.symbol) ?? 999)
                    }
                    self.applyQuotes(sorted)
                    self.lastError = nil
                }
            }
        }
    }

    private func applyQuotes(_ newQuotes: [StockQuote]) {
        let now = Date()
        let cutoff = now.addingTimeInterval(-60)
        var flashes = quoteFlashes

        for quote in newQuotes {
            var timeline = priceTimeline[quote.symbol] ?? []
            timeline.append((quote.price, now))
            priceTimeline[quote.symbol] = timeline.filter { $0.date > cutoff }

            let previous = previousQuotes[quote.symbol]
            let timestampAdvanced = {
                guard let latest = latestSparkTimestamps[quote.symbol],
                      let previousTS = previousSparkTimestamps[quote.symbol] else { return false }
                return latest != previousTS
            }()
            if let previous, abs(previous.price - quote.price) > 0.0001 || timestampAdvanced {
                let minuteKind = UpdateFlashTracker.minuteDirection(
                    timeline: priceTimeline[quote.symbol] ?? [],
                    currentPrice: quote.price
                )
                let tickKind = UpdateFlashTracker.tickDirection(previous: previous.price, current: quote.price)
                let kind = minuteKind ?? tickKind ?? (quote.price >= previous.price ? UpdateFlashKind.up : .down)
                recordFlash(symbol: quote.symbol, kind: kind, flashes: &flashes)
            }
            previousQuotes[quote.symbol] = quote
            if let latest = latestSparkTimestamps[quote.symbol] {
                previousSparkTimestamps[quote.symbol] = latest
            }
        }

        quoteFlashes = flashes
        quotes = newQuotes
    }

    private func recordFlash(symbol: String, kind: UpdateFlashKind, flashes: inout [String: UpdateFlashState]) {
        let nextGen = (flashes[symbol]?.generation ?? 0) + 1
        flashes[symbol] = UpdateFlashState(kind: kind, generation: nextGen)
        if !isContentVisible {
            pendingFlashSymbols.insert(symbol)
        }
    }

    private func replayPendingFlashes() {
        guard !pendingFlashSymbols.isEmpty else { return }
        var flashes = quoteFlashes
        for symbol in pendingFlashSymbols {
            guard let current = flashes[symbol] else { continue }
            flashes[symbol] = UpdateFlashState(kind: current.kind, generation: current.generation + 1)
        }
        pendingFlashSymbols.removeAll()
        quoteFlashes = flashes
    }

    private func fetchQuotes(symbols: [String], completion: @escaping ([StockQuote]) -> Void) {
        if isContentVisible {
            fetchLiveQuotes(symbols: symbols, completion: completion)
        } else {
            fetchSparkQuotes(symbols: symbols, completion: completion)
        }
    }

    private func fetchSparkQuotes(symbols: [String], completion: @escaping ([StockQuote]) -> Void) {
        let joined = symbols.joined(separator: ",")
        guard let encoded = joined.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://query2.finance.yahoo.com/v8/finance/spark?symbols=\(encoded)&range=1d&interval=1m") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        session.dataTask(with: request) { data, _, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion([])
                return
            }

            var timestamps: [String: Int] = [:]
            let quotes = symbols.compactMap { symbol -> StockQuote? in
                guard let item = json[symbol] as? [String: Any],
                      let closes = item["close"] as? [Double],
                      let price = closes.last else { return nil }
                if let candleTimes = item["timestamp"] as? [Int], let latest = candleTimes.last {
                    timestamps[symbol] = latest
                }
                let previousClose = item["chartPreviousClose"] as? Double
                    ?? item["previousClose"] as? Double
                    ?? price
                let changePercent = previousClose > 0 ? ((price - previousClose) / previousClose) * 100 : 0
                let sym = item["symbol"] as? String ?? symbol
                return StockQuote(
                    id: sym,
                    symbol: sym,
                    name: sym,
                    price: price,
                    changePercent: changePercent
                )
            }

            DispatchQueue.main.async {
                for (symbol, timestamp) in timestamps {
                    self.latestSparkTimestamps[symbol] = timestamp
                }
                completion(quotes)
            }
        }.resume()
    }

    private func fetchLiveQuotes(symbols: [String], completion: @escaping ([StockQuote]) -> Void) {
        let group = DispatchGroup()
        var fetched: [StockQuote] = []
        let lock = NSLock()

        for symbol in symbols {
            group.enter()
            fetchLiveQuote(symbol: symbol) { quote in
                defer { group.leave() }
                guard let quote else { return }
                lock.lock()
                fetched.append(quote)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            completion(fetched)
        }
    }

    private func fetchLiveQuote(symbol: String, completion: @escaping (StockQuote?) -> Void) {
        guard let url = URL(string: "https://query2.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1m&range=1d") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        session.dataTask(with: request) { data, _, error in
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let first = results.first,
                  let meta = first["meta"] as? [String: Any],
                  let price = meta["regularMarketPrice"] as? Double else {
                completion(nil)
                return
            }

            let previousClose = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? price
            let changePercent = previousClose > 0 ? ((price - previousClose) / previousClose) * 100 : 0
            let sym = meta["symbol"] as? String ?? symbol

            completion(
                StockQuote(
                    id: sym,
                    symbol: sym,
                    name: meta["shortName"] as? String ?? sym,
                    price: price,
                    changePercent: changePercent
                )
            )
        }.resume()
    }

    var bannerText: String {
        if isLoading && quotes.isEmpty {
            return "Loading quotes…"
        }
        if let lastError, quotes.isEmpty {
            return lastError
        }
        guard !quotes.isEmpty else {
            return "Enter tickers in ⚙ settings — e.g. AAPL,TSLA"
        }
        return quotes.map { "\($0.symbol) \($0.formattedPrice) \($0.formattedChange)" }
            .joined(separator: "   •   ")
    }
}
