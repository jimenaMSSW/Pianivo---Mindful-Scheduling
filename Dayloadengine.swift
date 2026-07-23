import SwiftUI
import AVFoundation

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 1 — Daily Emotional Load Model
// ─────────────────────────────────────────────────────────────────────────────

/// Describes the emotional and physical weight of a given day's schedule.
/// Used throughout the app to adapt visuals, animations, density, and suggestions.
enum DayLoad: Equatable {
    case calm        // 0–3 appointments, ≤1 high-stress
    case busy        // 4–6 appointments OR 2 high-stress
    case overloaded  // ≥7 appointments OR ≥3 high-stress
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Load Calculator
// ─────────────────────────────────────────────────────────────────────────────

/// Calculates the emotional load for a set of appointments.
/// All computation is value-based and safe to call from any context.
func calculateDayLoad(from appointments: [Appointment]) -> DayLoad {
    let active = appointments.filter { $0.status != .cancelled }
    let total = active.count
    let highStress = active.filter { $0.isHighStress }.count

    // Overloaded wins over busy — check most severe first
    if total >= 7 || highStress >= 3 { return .overloaded }
    if total >= 4 || highStress >= 2 { return .busy }
    return .calm
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 2 — Visual Emotion System
// ─────────────────────────────────────────────────────────────────────────────

extension DayLoad {

    /// Primary accent colour for this load state.
    /// Intentionally muted — these are supportive cues, not alarms.
    var color: Color {
        switch self {
        case .calm:
            // Soft sage-teal: grounded, present
            return Color(red: 0.22, green: 0.72, blue: 0.62)
        case .busy:
            // Warm amber: active, not anxious
            return Color(red: 0.93, green: 0.70, blue: 0.22)
        case .overloaded:
            // Dusty rose-red: tension without alarm
            return Color(red: 0.85, green: 0.32, blue: 0.30)
        }
    }

    /// Very subtle background tint for schedule containers.
    var backgroundTint: Color {
        color.opacity(backgroundOpacity)
    }

    /// Opacity kept intentionally low — a whisper, not a shout.
    var backgroundOpacity: Double {
        switch self {
        case .calm:       return 0.04
        case .busy:       return 0.07
        case .overloaded: return 0.10
        }
    }

    /// Badge label shown in the daily rhythm header.
    var label: String {
        switch self {
        case .calm:       return "Calm Day"
        case .busy:       return "Busy Day"
        case .overloaded: return "Full Day"
        }
    }

    /// Supportive sub-label beneath the load badge.
    var sublabel: String {
        switch self {
        case .calm:       return "Space to breathe"
        case .busy:       return "Stay present"
        case .overloaded: return "Take it one step at a time"
        }
    }

    /// SF Symbol name for the load indicator.
    var iconName: String {
        switch self {
        case .calm:       return "waveform.path.ecg"
        case .busy:       return "chart.bar.fill"
        case .overloaded: return "bolt.circle.fill"
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 3 — Rhythm-Based Animations
// ─────────────────────────────────────────────────────────────────────────────

extension DayLoad {

    /// Returns the appropriate animation for this load state.
    /// Used for task insertion, completion, and schedule updates.
    var insertionAnimation: Animation {
        switch self {
        case .calm:
            // Slow, smooth — like a breath
            return .easeInOut(duration: 0.7)
        case .busy:
            // Standard — steady and reliable
            return .easeInOut(duration: 0.4)
        case .overloaded:
            // Crisp with just a hint of spring tension
            return .spring(response: 0.25, dampingFraction: 0.72)
        }
    }

    /// Pulse animation speed for the RhythmOrb.
    var pulseAnimation: Animation {
        switch self {
        case .calm:
            return .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
        case .busy:
            return .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        case .overloaded:
            return .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 4 — Optional Sound Feedback
// ─────────────────────────────────────────────────────────────────────────────

/// Manages mindful sound cues using AVAudioEngine tone synthesis.
/// Falls completely silent if anything is unavailable — never crashes.
@MainActor
final class SoundFeedbackManager: ObservableObject {

    static let shared = SoundFeedbackManager()

    /// Toggle stored in UserDefaults so it persists across sessions.
    @AppStorage("pianivo_sound_enabled") var isEnabled: Bool = true

    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var isSetup = false

    private init() { setupEngine() }

    private func setupEngine() {
        do {
            // Activate audio session first — required on real devices and iPad
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try session.setActive(true)

            let eng = AVAudioEngine()
            let player = AVAudioPlayerNode()
            eng.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
            eng.connect(player, to: eng.mainMixerNode, format: format)
            eng.mainMixerNode.outputVolume = 0.18  // Intentionally quiet
            try eng.start()
            engine = eng
            playerNode = player
            isSetup = true
        } catch {
            // Fail silently — sound is enhancement, not function
            isSetup = false
        }
    }

    /// Plays a gentle piano-like tone when an appointment is added.
    /// C5 (523.25 Hz) — bright, welcoming.
    func playAddTaskSound() {
        guard isEnabled else { return }
        playTone(frequency: 523.25, duration: 0.45, envelope: .pluck)
    }

    /// Plays a soft chord when an appointment is completed.
    /// C5 + E5 + G5 — a resolved, satisfying triad.
    func playCompleteTaskSound() {
        guard isEnabled else { return }
        playTone(frequency: 523.25, duration: 0.6, envelope: .chord)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            self?.playTone(frequency: 659.25, duration: 0.55, envelope: .chord)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.playTone(frequency: 783.99, duration: 0.5, envelope: .chord)
        }
    }

    // MARK: Private tone synthesis

    private enum Envelope { case pluck, chord }

    private func playTone(frequency: Float, duration: Float, envelope: Envelope) {
        guard isSetup, let player = playerNode, let engine, engine.isRunning else { return }
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: player.outputFormat(forBus: 0),
                                             frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return }

        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate
            // Base sine wave
            var sample = sin(2 * Float.pi * frequency * t)
            // Add subtle harmonic for piano-like timbre
            sample += 0.3 * sin(4 * Float.pi * frequency * t)
            sample *= 0.5

            // Envelope shaping
            let progress = t / duration
            let attack: Float = 0.01
            let releaseStart: Float = envelope == .pluck ? 0.1 : 0.4
            if progress < attack {
                sample *= progress / attack
            } else if progress > releaseStart {
                sample *= 1 - (progress - releaseStart) / (1 - releaseStart)
            }

            channelData[i] = sample * 0.7
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 5 — Balance Suggestion Engine
// ─────────────────────────────────────────────────────────────────────────────

/// The tone of every suggestion: supportive, not critical.
enum SuggestionType {
    case recovery    // Rest and space
    case pacing      // Distribute load
    case awareness   // Gentle observation
    case encouragement
}

struct BalanceSuggestion: Identifiable {
    let id = UUID()
    let message: String
    let type: SuggestionType

    var iconName: String {
        switch type {
        case .recovery:      return "leaf.fill"
        case .pacing:        return "arrow.triangle.2.circlepath"
        case .awareness:     return "eye.fill"
        case .encouragement: return "sparkles"
        }
    }

    var color: Color {
        switch type {
        case .recovery:      return Color(red: 0.22, green: 0.72, blue: 0.62)
        case .pacing:        return Color(red: 0.93, green: 0.70, blue: 0.22)
        case .awareness:     return Color(red: 0.45, green: 0.55, blue: 0.85)
        case .encouragement: return Color(red: 0.22, green: 0.72, blue: 0.62)
        }
    }
}

struct BalanceSuggestionEngine {

    /// Analyses a set of appointments for a given day and returns
    /// mindful, supportive suggestions. Never returns more than 3.
    static func suggestions(
        for appointments: [Appointment],
        on date: Date = Date()
    ) -> [BalanceSuggestion] {

        let cal = Calendar.current
        let active = appointments
            .filter { cal.isDate($0.startTime, inSameDayAs: date) && $0.status != .cancelled }
            .sorted { $0.startTime < $1.startTime }

        var results: [BalanceSuggestion] = []

        // ── Rule 1: ≥3 consecutive high-stress appointments ──────────────────
        var consecutiveHighStress = 0
        var maxConsecutive = 0
        for appt in active {
            if appt.isHighStress {
                consecutiveHighStress += 1
                maxConsecutive = max(maxConsecutive, consecutiveHighStress)
            } else {
                consecutiveHighStress = 0
            }
        }
        if maxConsecutive >= 3 {
            results.append(BalanceSuggestion(
                message: "You have several intensive appointments in a row. Even a moment to reset between them can make a real difference.",
                type: .recovery
            ))
        }

        // ── Rule 2: ≥3 hours scheduled without any gap ───────────────────────
        if active.count >= 2 {
            var continuousHours: Double = 0
            var blockStart = active[0].startTime
            var blockEnd = active[0].endTime

            for i in 1..<active.count {
                let gap = active[i].startTime.timeIntervalSince(blockEnd)
                if gap < 10 * 60 {  // Less than 10-minute gap = continuous
                    blockEnd = active[i].endTime
                    continuousHours = max(continuousHours, blockEnd.timeIntervalSince(blockStart) / 3600)
                } else {
                    blockStart = active[i].startTime
                    blockEnd = active[i].endTime
                }
            }
            if continuousHours >= 3 {
                results.append(BalanceSuggestion(
                    message: "There's a stretch of \(Int(continuousHours))+ hours without a clear break. A few minutes to breathe can help you stay grounded.",
                    type: .pacing
                ))
            }
        }

        // ── Rule 3: ≥6 appointments total ────────────────────────────────────
        if active.count >= 6 && !results.contains(where: { $0.type == .pacing }) {
            results.append(BalanceSuggestion(
                message: "It's a full day with \(active.count) appointments. Consider where you might find small moments of restoration between clients.",
                type: .pacing
            ))
        }

        // ── Rule 4: Back-to-back appointments (gap < 5 min) ──────────────────
        var backToBackCount = 0
        for i in 0..<max(0, active.count - 1) {
            let gap = active[i + 1].startTime.timeIntervalSince(active[i].endTime)
            if gap < 5 * 60 { backToBackCount += 1 }
        }
        if backToBackCount >= 2 && !results.contains(where: { $0.type == .recovery }) {
            results.append(BalanceSuggestion(
                message: "Several appointments follow on immediately from each other. Ending even one a few minutes early creates space to arrive fully for the next.",
                type: .awareness
            ))
        }

        // ── Encouragement for light days ──────────────────────────────────────
        if active.isEmpty {
            results.append(BalanceSuggestion(
                message: "A clear day. A good time for planning, reflection, or something that restores you.",
                type: .encouragement
            ))
        } else if active.count <= 2 && results.isEmpty {
            results.append(BalanceSuggestion(
                message: "A gentle day ahead — room to be fully present with each person you see.",
                type: .encouragement
            ))
        }

        // Never return more than 3 — priority is already ordered by insert order
        return Array(results.prefix(3))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 6 — Layout Density
// ─────────────────────────────────────────────────────────────────────────────

/// Layout spacing values that adapt to the day's load.
/// Calm = airy. Overloaded = slightly compressed but never illegible.
struct DayLoadSpacing {
    let cardPadding: CGFloat
    let sectionSpacing: CGFloat
    let itemSpacing: CGFloat

    static func forLoad(_ load: DayLoad) -> DayLoadSpacing {
        switch load {
        case .calm:
            return DayLoadSpacing(cardPadding: 18, sectionSpacing: 22, itemSpacing: 14)
        case .busy:
            return DayLoadSpacing(cardPadding: 16, sectionSpacing: 18, itemSpacing: 12)
        case .overloaded:
            return DayLoadSpacing(cardPadding: 14, sectionSpacing: 14, itemSpacing: 10)
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PART 7 — Shared UI Components
// ─────────────────────────────────────────────────────────────────────────────

// MARK: RhythmOrb
/// Animated pulsing orb whose behaviour reflects the day's emotional load.
/// Integrates into daily schedule headers as the primary load indicator.
struct RhythmOrb: View {
    let load: DayLoad
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer slow pulse ring
            Circle()
                .fill(load.color.opacity(0.10))
                .frame(width: 58, height: 58)
                .scaleEffect(isPulsing ? 1.20 : 1.0)
                .animation(load.pulseAnimation, value: isPulsing)

            // Middle ring
            Circle()
                .fill(load.color.opacity(0.18))
                .frame(width: 42, height: 42)

            // Core icon
            Image(systemName: load.iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(load.color)
        }
        .onAppear { isPulsing = true }
        .onChange(of: load) { _, _ in
            isPulsing = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isPulsing = true }
        }
        .accessibilityLabel("Day rhythm: \(load.label)")
    }
}

// MARK: DayLoadBadge
/// Compact badge version of the load state — for side panels and compact headers.
struct DayLoadBadge: View {
    let load: DayLoad

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: load.iconName)
                .font(.system(size: 10, weight: .bold))
            Text(load.label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.8)
        }
        .foregroundColor(load.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(load.color.opacity(0.12))
        .clipShape(Capsule())
        .accessibilityLabel("Schedule load: \(load.label)")
    }
}

// MARK: BalanceSuggestionCard
/// A single supportive suggestion rendered as a soft, non-alarming card.
struct BalanceSuggestionCard: View {
    let suggestion: BalanceSuggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: suggestion.iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(suggestion.color)
                .frame(width: 22, height: 22)
                .padding(.top, 1)

            Text(suggestion.message)
                .font(.subheadline)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(suggestion.color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

// MARK: BalanceSuggestionsPanel
/// Displays 1–3 balance suggestions with a header.
/// Designed to slot into any ScrollView section.
struct BalanceSuggestionsPanel: View {
    let suggestions: [BalanceSuggestion]

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("BALANCE SUGGESTIONS")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .tracking(1.0)
                }
                .padding(.horizontal, 2)

                ForEach(suggestions) { s in
                    BalanceSuggestionCard(suggestion: s)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
            )
        }
    }
}

// MARK: SoundToggleRow
/// A simple settings row for toggling sound feedback.
/// Drop into any Settings or preferences list.
struct SoundToggleRow: View {
    @ObservedObject var soundManager = SoundFeedbackManager.shared

    var body: some View {
        HStack {
            Label("Mindful Sound Cues", systemImage: soundManager.isEnabled ? "waveform" : "waveform.slash")
                .foregroundColor(.primary)
            Spacer()
            Toggle("", isOn: $soundManager.isEnabled)
                .labelsHidden()
                .tint(Color(red: 0.22, green: 0.72, blue: 0.62))
        }
        .accessibilityLabel("Sound cues \(soundManager.isEnabled ? "enabled" : "disabled")")
    }
}

// MARK: RhythmHeaderView
/// Full daily rhythm header — the centrepiece of the Rhythm of Your Day feature.
/// Plug directly into any day view above the schedule content.
struct RhythmHeaderView: View {
    let load: DayLoad
    let date: Date
    let earnings: Double
    let suggestions: [BalanceSuggestion]
    @State private var showSuggestions = false
    let spacing: DayLoadSpacing

    init(load: DayLoad, date: Date, earnings: Double, suggestions: [BalanceSuggestion]) {
        self.load = load
        self.date = date
        self.earnings = earnings
        self.suggestions = suggestions
        self.spacing = DayLoadSpacing.forLoad(load)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Rhythm banner ─────────────────────────────────────────────────
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(load.backgroundTint)
                    .animation(load.insertionAnimation, value: load)

                HStack(spacing: spacing.cardPadding - 2) {
                    RhythmOrb(load: load)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("RHYTHM OF YOUR DAY")
                                .font(.caption2.bold())
                                .tracking(1.0)
                                .foregroundColor(load.color)
                        }
                        Text(load.label)
                            .font(.title3.bold())
                            .foregroundColor(.primary)
                            .animation(load.insertionAnimation, value: load.label)
                        Text(load.sublabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(earnings.formatted(.currency(code: "USD")))
                            .font(.subheadline.bold())
                            .foregroundColor(load.color)
                        Text("today")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Suggestions disclosure
                        if !suggestions.isEmpty {
                            Button {
                                withAnimation(load.insertionAnimation) {
                                    showSuggestions.toggle()
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: showSuggestions ? "chevron.up.circle.fill" : "lightbulb.fill")
                                        .font(.caption2)
                                    Text(showSuggestions ? "Less" : "Tips")
                                        .font(.caption2.bold())
                                }
                                .foregroundColor(load.color)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(load.color.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .padding(spacing.cardPadding)
            }

            // ── Balance suggestions (collapsible) ─────────────────────────────
            if showSuggestions && !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions) { s in
                        BalanceSuggestionCard(suggestion: s)
                    }
                }
                .padding(.top, spacing.itemSpacing)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: -8)),
                    removal:   .opacity.combined(with: .offset(y: -8))
                ))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 4)
        )
        .animation(load.insertionAnimation, value: load)
        .animation(load.insertionAnimation, value: showSuggestions)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - PREVIEW
// ─────────────────────────────────────────────────────────────────────────────

#Preview("Rhythm Header — All States") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach([DayLoad.calm, .busy, .overloaded], id: \.label) { load in
                RhythmHeaderView(
                    load: load,
                    date: Date(),
                    earnings: load == .calm ? 285 : load == .busy ? 640 : 1020,
                    suggestions: BalanceSuggestionEngine.suggestions(
                        for: [],
                        on: Date()
                    )
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Balance Suggestion Card") {
    VStack(spacing: 12) {
        BalanceSuggestionCard(suggestion: BalanceSuggestion(
            message: "A gentle day ahead — room to be fully present with each person you see.",
            type: .encouragement
        ))
        BalanceSuggestionCard(suggestion: BalanceSuggestion(
            message: "Several appointments follow on immediately. Ending even one a few minutes early creates space to arrive fully for the next.",
            type: .awareness
        ))
        BalanceSuggestionCard(suggestion: BalanceSuggestion(
            message: "There's a stretch of 3+ hours without a clear break. A few minutes to breathe can help you stay grounded.",
            type: .pacing
        ))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
