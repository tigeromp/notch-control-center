import Foundation

struct SportLeague: Identifiable, Equatable {
    let id: String
    let name: String
    let fetchPaths: [String]
}

struct SportsScore: Identifiable, Equatable {
    let id: String
    let awayTeam: String
    let homeTeam: String
    let awayScore: String
    let homeScore: String
    let status: String
    let leagueID: String
    let leagueName: String

    var headline: String {
        if awayScore.isEmpty && homeScore.isEmpty {
            return "\(awayTeam) @ \(homeTeam) · \(status)"
        }
        return "\(awayTeam) \(awayScore) – \(homeTeam) \(homeScore) · \(status)"
    }
}

final class SportsController: ObservableObject {
    static let availableLeagues: [SportLeague] = [
        SportLeague(id: "nfl", name: "NFL", fetchPaths: ["football/nfl"]),
        SportLeague(id: "nba", name: "NBA", fetchPaths: ["basketball/nba"]),
        SportLeague(id: "mlb", name: "MLB", fetchPaths: ["baseball/mlb"]),
        SportLeague(id: "nhl", name: "NHL", fetchPaths: ["hockey/nhl"]),
        SportLeague(id: "ncaaf", name: "NCAA Football", fetchPaths: ["football/college-football"]),
        SportLeague(id: "ncaab", name: "NCAA Basketball", fetchPaths: ["basketball/mens-college-basketball"]),
        SportLeague(id: "soccer", name: "Soccer", fetchPaths: ["soccer/all"]),
        SportLeague(id: "cricket", name: "Cricket", fetchPaths: ["cricket/8048", "cricket/8580", "cricket/8670"])
    ]

    @Published var scores: [SportsScore] = []
    @Published var isLoading = false
    @Published var statusMessage = ""
    @Published var scoreFlashes: [String: UpdateFlashState] = [:]

    var onLayoutChange: (() -> Void)?

    @Published var selectedLeagues: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(selectedLeagues).sorted(), forKey: Keys.leagues)
            onLayoutChange?()
            refresh()
        }
    }

    private var timer: Timer?
    private let session: URLSession
    private var refreshGeneration = 0
    private var lastAppliedRefreshGeneration = 0
    private var previousScores: [String: SportsScore] = [:]
    private(set) var isContentVisible = false
    private var pendingFlashIDs: Set<String> = []

    static let refreshInterval: TimeInterval = 2

    private enum Keys {
        static let leagues = "sports.leagues.selected"
        static let legacyLeaguesText = "sports.leagues"
    }

    init() {
        if let saved = UserDefaults.standard.array(forKey: Keys.leagues) as? [String] {
            selectedLeagues = Set(saved.filter { Self.league(for: $0) != nil })
        } else if let legacy = UserDefaults.standard.string(forKey: Keys.legacyLeaguesText) {
            selectedLeagues = Set(
                legacy
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { Self.league(for: $0) != nil }
            )
        } else {
            selectedLeagues = ["nfl", "nba"]
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        session = URLSession(configuration: config)
    }

    var leagues: [String] {
        Self.availableLeagues
            .map(\.id)
            .filter { selectedLeagues.contains($0) }
    }

    var selectedLeaguesLabel: String {
        let names = leagues.compactMap { Self.league(for: $0)?.name }
        guard !names.isEmpty else { return "No sports selected" }
        return names.joined(separator: ", ")
    }

    static func league(for id: String) -> SportLeague? {
        availableLeagues.first { $0.id == id }
    }

    func isLeagueSelected(_ id: String) -> Bool {
        selectedLeagues.contains(id)
    }

    func scores(for leagueID: String) -> [SportsScore] {
        scores.filter { $0.leagueID == leagueID }
    }

    func rowPlaceholder(for leagueID: String) -> String {
        if isLoading { return "Loading live games…" }
        if let league = Self.league(for: leagueID) {
            return "No live \(league.name) games right now"
        }
        return statusMessage
    }

    var leaguesWithLiveGames: [String] {
        leagues.filter { !scores(for: $0).isEmpty }
    }

    var hasLiveGames: Bool {
        !scores.isEmpty
    }

    var emptyLiveMessage: String {
        if isLoading { return "Loading live games…" }
        if leagues.isEmpty { return "Pick sports in ⚙ settings" }
        return "No live games right now"
    }

    func setLeague(_ id: String, selected: Bool) {
        var updated = selectedLeagues
        if selected {
            updated.insert(id)
        } else {
            updated.remove(id)
        }
        selectedLeagues = updated
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
        let leagues = leagues
        guard !leagues.isEmpty else {
            scores = []
            statusMessage = "Pick sports in ⚙ settings"
            return
        }

        refreshGeneration += 1
        let generation = refreshGeneration

        if scores.isEmpty {
            isLoading = true
        }
        statusMessage = ""

        let group = DispatchGroup()
        var fetched: [SportsScore] = []
        let lock = NSLock()

        for leagueID in leagues {
            group.enter()
            fetchLeague(leagueID) { items in
                defer { group.leave() }
                lock.lock()
                fetched.append(contentsOf: items)
                lock.unlock()
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self, generation >= self.lastAppliedRefreshGeneration else { return }
            self.lastAppliedRefreshGeneration = generation
            self.isLoading = false
            if fetched.isEmpty {
                self.scores = []
                self.statusMessage = "No live games right now"
            } else {
                let order = self.leagues
                let sorted = fetched.sorted {
                    (order.firstIndex(of: $0.leagueID) ?? 999, $0.id) < (order.firstIndex(of: $1.leagueID) ?? 999, $1.id)
                }
                self.applyScores(sorted)
            }
        }
    }

    private func applyScores(_ newScores: [SportsScore]) {
        var flashes = scoreFlashes

        for score in newScores {
            if let previous = previousScores[score.id] {
                let scoreChanged = previous.awayScore != score.awayScore || previous.homeScore != score.homeScore
                let statusChanged = previous.status != score.status
                if scoreChanged || statusChanged {
                    recordFlash(id: score.id, flashes: &flashes)
                }
            }
            previousScores[score.id] = score
        }

        scoreFlashes = flashes
        scores = newScores
    }

    private func recordFlash(id: String, flashes: inout [String: UpdateFlashState]) {
        let nextGen = (flashes[id]?.generation ?? 0) + 1
        flashes[id] = UpdateFlashState(kind: .accent, generation: nextGen)
        if !isContentVisible {
            pendingFlashIDs.insert(id)
        }
    }

    private func replayPendingFlashes() {
        guard !pendingFlashIDs.isEmpty else { return }
        var flashes = scoreFlashes
        for id in pendingFlashIDs {
            guard let current = flashes[id] else { continue }
            flashes[id] = UpdateFlashState(kind: current.kind, generation: current.generation + 1)
        }
        pendingFlashIDs.removeAll()
        scoreFlashes = flashes
    }

    private func fetchLeague(_ leagueID: String, completion: @escaping ([SportsScore]) -> Void) {
        guard let league = Self.league(for: leagueID) else {
            completion([])
            return
        }

        let group = DispatchGroup()
        var fetched: [SportsScore] = []
        let lock = NSLock()

        for path in league.fetchPaths {
            group.enter()
            fetchScoreboard(path: path, leagueID: leagueID, leagueName: league.name) { items in
                defer { group.leave() }
                lock.lock()
                fetched.append(contentsOf: items)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            var seen = Set<String>()
            let unique = fetched.filter { score in
                guard !seen.contains(score.id) else { return false }
                seen.insert(score.id)
                return true
            }
            completion(Array(unique.prefix(8)))
        }
    }

    private func fetchScoreboard(
        path: String,
        leagueID: String,
        leagueName: String,
        completion: @escaping ([SportsScore]) -> Void
    ) {
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(path)/scoreboard") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        session.dataTask(with: request) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let events = json["events"] as? [[String: Any]] else {
                completion([])
                return
            }

            let liveEvents = events.filter { Self.isEventLive($0) }
            let scores = liveEvents.compactMap { event -> SportsScore? in
                Self.parseScore(event: event, leagueID: leagueID, leagueName: leagueName)
            }

            completion(scores)
        }.resume()
    }

    private static func isEventLive(_ event: [String: Any]) -> Bool {
        guard let competitions = event["competitions"] as? [[String: Any]],
              let competition = competitions.first,
              let status = competition["status"] as? [String: Any],
              let type = status["type"] as? [String: Any],
              let state = type["state"] as? String else { return false }
        return state == "in"
    }

    private static func parseScore(event: [String: Any], leagueID: String, leagueName: String) -> SportsScore? {
        let id: String
        if let stringID = event["id"] as? String {
            id = stringID
        } else if let intID = event["id"] as? Int {
            id = String(intID)
        } else {
            return nil
        }

        guard let competitions = event["competitions"] as? [[String: Any]],
              let competition = competitions.first,
              let competitors = competition["competitors"] as? [[String: Any]],
              competitors.count >= 2 else { return nil }

        func teamInfo(_ comp: [String: Any]) -> (name: String, score: String) {
            let team = comp["team"] as? [String: Any]
            let abbrev = team?["abbreviation"] as? String
                ?? team?["shortDisplayName"] as? String
                ?? team?["displayName"] as? String
                ?? "?"
            let score: String
            if let scoreString = comp["score"] as? String {
                score = scoreString
            } else if let scoreNumber = comp["score"] as? Int {
                score = String(scoreNumber)
            } else {
                score = ""
            }
            return (abbrev, score)
        }

        let home = competitors.first { ($0["homeAway"] as? String) == "home" } ?? competitors[0]
        let away = competitors.first { ($0["homeAway"] as? String) == "away" } ?? competitors[1]
        let homeInfo = teamInfo(home)
        let awayInfo = teamInfo(away)

        let statusDetail = ((competition["status"] as? [String: Any])?["type"] as? [String: Any])?["shortDetail"] as? String
            ?? ((event["status"] as? [String: Any])?["type"] as? [String: Any])?["shortDetail"] as? String
            ?? "Scheduled"

        return SportsScore(
            id: "\(leagueID)-\(id)",
            awayTeam: awayInfo.name,
            homeTeam: homeInfo.name,
            awayScore: awayInfo.score,
            homeScore: homeInfo.score,
            status: statusDetail,
            leagueID: leagueID,
            leagueName: leagueName
        )
    }
}
