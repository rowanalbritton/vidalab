import Foundation
import Testing
@testable import VIDALAB

struct MeditationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 2
        return calendar
    }

    private func at(_ day: Int, hour: Int = 8) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    // MARK: Breathing

    @Test func phasesSkipZeroLengthStepsAndKeepOrder() {
        let box = BreathPattern.find("box")!
        #expect(box.phases.map(\.phase) == [.inhale, .holdIn, .exhale, .holdOut])
        #expect(box.cycleSeconds == 16)

        let sigh = BreathPattern.find("sigh")!
        #expect(sigh.phases.map(\.phase) == [.inhale, .topUp, .exhale])

        let resonant = BreathPattern.find("resonant")!
        #expect(resonant.phases.map(\.phase) == [.inhale, .exhale])
    }

    @Test func cyclesFillTheChosenLength() {
        #expect(BreathPattern.find("resonant")!.cycles(forMinutes: 5) == 27) // 300 / 11
        #expect(BreathPattern.find("box")!.cycles(forMinutes: 1) == 4)       // 60 / 16, rounded
        #expect(BreathPattern.find("478")!.cycles(forMinutes: 0) == 1)       // never zero
    }

    // MARK: Stats

    @Test func statsCountThisWeekAndTheStreak() {
        let now = at(26, hour: 20) // Saturday
        let sessions = [
            MeditationSession(date: at(20), kind: .timer, title: "Sit", seconds: 600, stressBefore: nil, stressAfter: nil),  // last Sunday, previous week
            MeditationSession(date: at(24), kind: .breathing, title: "Box", seconds: 180, stressBefore: 7, stressAfter: 4),
            MeditationSession(date: at(25), kind: .guided, title: "Body scan", seconds: 900, stressBefore: 6, stressAfter: 5),
            MeditationSession(date: at(26), kind: .breathing, title: "Sigh", seconds: 60, stressBefore: 5, stressAfter: 5),
        ]

        let stats = MeditationStats.from(sessions, now: now, calendar: calendar)

        #expect(stats.minutesThisWeek == 19)   // 180 + 900 + 60 seconds
        #expect(stats.sessionsThisWeek == 3)
        #expect(stats.streakDays == 3)         // 24, 25, 26
        #expect(stats.averageStressChange == (-3 + -1 + 0) / 3.0)
    }

    @Test func aStreakEndingYesterdayStillCounts() {
        let now = at(26, hour: 7)
        let sessions = [
            MeditationSession(date: at(24), kind: .timer, title: "Sit", seconds: 300),
            MeditationSession(date: at(25), kind: .timer, title: "Sit", seconds: 300),
        ]

        #expect(MeditationStats.from(sessions, now: now, calendar: calendar).streakDays == 2)
    }

    @Test func aGapBreaksTheStreak() {
        let now = at(26)
        let sessions = [MeditationSession(date: at(23), kind: .timer, title: "Sit", seconds: 300)]

        #expect(MeditationStats.from(sessions, now: now, calendar: calendar).streakDays == 0)
    }

    // MARK: Guided scripts

    private let bodyScan = """
    1. Lie down comfortably, close your eyes.
    2. Take 3 deep breaths, settling in.
    3. Bring attention to your toes. Notice any sensation.

    **Tip:** This is one of the most studied mindfulness practices for chronic pain. See [the study](https://example.com).
    """

    @Test func guidedScriptsSpreadStepsAcrossTheirLength() {
        let script = GuidedScript.make(title: "Body scan", content: bodyScan, minutes: 15)

        #expect(script.segments.count == 4) // three steps and the closing line
        #expect(script.segments.last?.text == GuidedScript.closing)
        #expect(script.segments.last?.pauseSeconds == 0)
        #expect(abs(script.totalSeconds - 900) < 30)
    }

    @Test func tipsAreShownNotSpokenAndMarkdownIsStripped() {
        let script = GuidedScript.make(title: "Body scan", content: bodyScan, minutes: 15)

        #expect(script.tip?.hasPrefix("This is one of the most studied") == true)
        #expect(!script.segments.contains { $0.text.lowercased().contains("tip") })
        #expect(GuidedScript.plainText("**Minute 1:** Close your [eyes](https://x.y)") == "Minute 1: Close your eyes")
    }

    @Test func shortScriptsStillLeaveRoomToPractice() {
        let script = GuidedScript.make(title: "Quick", content: "1. Breathe in.\n2. Breathe out.", minutes: 1)

        #expect(script.segments.dropLast().allSatisfy { $0.pauseSeconds >= 6 })
    }

    @Test func breathingScriptsOpenTheBreathingGuide() {
        #expect(GuidedScript.breathPattern(forTitle: "4-7-8 Breathing Technique")?.id == "478")
        #expect(GuidedScript.breathPattern(forTitle: "Box Breathing (4-4-4-4)")?.id == "box")
        #expect(GuidedScript.breathPattern(forTitle: "Physiological Sigh")?.id == "sigh")
        #expect(GuidedScript.breathPattern(forTitle: "Body Scan Meditation") == nil)
    }

    @Test func summaryDurationsRoundToTheNearestMinute() {
        #expect(MeditationSessionView.durationText(seconds: 24) == "Under a minute")
        #expect(MeditationSessionView.durationText(seconds: 65) == "1 minute")
        #expect(MeditationSessionView.durationText(seconds: 94) == "2 minutes")
        #expect(MeditationSessionView.durationText(seconds: 600) == "10 minutes")
    }

    @Test func sessionCopyAvoidsEmDashes() {
        for pattern in BreathPattern.all {
            #expect(!pattern.summary.contains("\u{2014}"))
            #expect(!pattern.title.contains("\u{2014}"))
        }
        #expect(!GuidedScript.closing.contains("\u{2014}"))
    }
}
