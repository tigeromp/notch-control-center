import SwiftUI

struct SportLeaguePicker: View {
    @ObservedObject var sports: SportsController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick sports")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(SportsController.availableLeagues) { league in
                    SportLeagueChip(
                        league: league,
                        isSelected: sports.isLeagueSelected(league.id)
                    ) {
                        sports.setLeague(league.id, selected: !sports.isLeagueSelected(league.id))
                    }
                }
            }
        }
    }
}

struct SportLeagueChip: View {
    let league: SportLeague
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(league.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.mint.opacity(0.35) : Color.white.opacity(0.08))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.mint.opacity(0.7) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SportLeagueRow: View {
    let league: SportLeague
    let scores: [SportsScore]
    let placeholder: String
    var flashes: [String: UpdateFlashState] = [:]
    var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetSectionHeader(icon: "sportscourt", title: league.name, tint: .mint, isLoading: isLoading)
            SportsTickerStrip(
                scores: scores,
                placeholder: placeholder,
                flashes: flashes
            )
            .frame(height: 22)
        }
    }
}

struct WidgetSectionHeader: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let icon: String
    let title: String
    let tint: Color
    var isLoading = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(appearance.font(size: 9))
                .foregroundStyle(tint)
            Text(title)
                .font(appearance.font(size: 9, weight: .semibold))
                .foregroundStyle(appearance.mutedText)
            if isLoading {
                ProgressView().controlSize(.mini).scaleEffect(0.5)
            }
        }
    }
}

struct TimerStopwatchModule: View {
    @ObservedObject var timer: TimerStopwatchController
    @State private var customTimerText = ""
    @FocusState private var customTimerFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                WidgetSectionHeader(icon: "timer", title: "Timer & Stopwatch", tint: .orange)
                Spacer()
                Picker("", selection: $timer.mode) {
                    Text("Timer").tag(ClockMode.timer)
                    Text("Stopwatch").tag(ClockMode.stopwatch)
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
                .scaleEffect(0.85)
            }

            if timer.mode == .timer {
                timerBody
            } else {
                stopwatchBody
            }
        }
    }

    private var timerBody: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(timer.formattedTimerRemaining())
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundStyle(timer.timerFinished ? .orange : .white)
                Spacer()
                Button(action: timer.toggleTimer) {
                    Image(systemName: timer.timerRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(GlassIconButtonStyle())
                Button(action: timer.resetTimer) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(GlassIconButtonStyle())
            }

            if timer.timerTotal > 0 {
                ProgressView(value: timer.timerProgress)
                    .tint(.orange)
            }

            HStack(spacing: 6) {
                ForEach([5, 10, 15, 25], id: \.self) { minutes in
                    Button("\(minutes)m") { timer.startTimer(minutes: minutes) }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.plain)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 6) {
                TextField("mm:ss or min", text: $customTimerText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 96)
                    .focused($customTimerFocused)
                    .onSubmit { startCustomTimer() }

                Button("Start") { startCustomTimer() }
                    .font(.system(size: 10, weight: .semibold))
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.orange.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func startCustomTimer() {
        guard timer.startTimer(from: customTimerText) else { return }
        customTimerText = ""
        customTimerFocused = false
    }

    private var stopwatchBody: some View {
        HStack {
            Text(timer.formattedStopwatchElapsed())
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Button(action: timer.toggleStopwatch) {
                Image(systemName: timer.stopwatchRunning ? "pause.fill" : "play.fill")
            }
            .buttonStyle(GlassIconButtonStyle())
            Button(action: timer.resetStopwatch) {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(GlassIconButtonStyle())
        }
    }
}

struct MeetingModeModule: View {
    @ObservedObject var calendar: CalendarController

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WidgetSectionHeader(icon: "video.fill", title: "Meeting Mode", tint: .blue)

            if let meeting = calendar.nextMeeting {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meeting.countdownLabel())
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(meeting.isHappeningNow ? .green : .orange)
                        Text(meeting.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(meeting.timeLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    if meeting.joinURL != nil {
                        Button("Join") { calendar.joinNextMeeting() }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.blue.opacity(0.85))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Text(calendar.statusMessage.isEmpty ? "No meetings coming up" : calendar.statusMessage)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }
}

struct CryptoQuoteChip: View {
    @EnvironmentObject private var appearance: NotchAppearanceStore
    let quote: CryptoQuote

    var body: some View {
        HStack(spacing: 5) {
            Text(quote.displaySymbol)
                .font(appearance.font(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(appearance.primaryText)
            Text(quote.formattedPrice)
                .font(appearance.font(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(appearance.primaryText.opacity(0.85))
            Text(quote.formattedChange)
                .font(appearance.font(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(quote.isUp ? .green : .red)
        }
    }
}

struct CryptoTickerStrip: View {
    let quotes: [CryptoQuote]
    let placeholder: String

    var body: some View {
        MarqueeTicker(
            placeholder: placeholder,
            isEmpty: quotes.isEmpty,
            contentSignature: quotes.map { "\($0.id)|\($0.price)|\($0.changePercent)" }.joined(separator: ";")
        ) {
            HStack(spacing: 20) {
                ForEach(quotes) { quote in
                    CryptoQuoteChip(quote: quote)
                }
            }
        }
    }
}
