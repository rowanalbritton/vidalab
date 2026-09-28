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

struct MeditationAccessTests {
    @Test func twoBreathingPatternsAreFree() {
        let free = BreathPattern.all.filter { !$0.isPremium }.map(\.id)
        #expect(Set(free) == ["resonant", "sigh"])
    }

    @Test func theFirstGuidedSessionsAreFree() {
        let ids = ["a", "b", "c", "d", "e"]
        #expect(MeditationAccess.isGuidedFree("a", in: ids))
        #expect(MeditationAccess.isGuidedFree("c", in: ids))
        #expect(!MeditationAccess.isGuidedFree("d", in: ids))
        #expect(!MeditationAccess.isGuidedFree("missing", in: ids))
    }

    private func date(hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: hour))!
    }

    @Test func suggestionsFollowTheTimeOfDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        #expect(MeditationMoment.at(date(hour: 7), calendar: calendar) == .morning)
        #expect(MeditationMoment.at(date(hour: 13), calendar: calendar) == .midday)
        #expect(MeditationMoment.at(date(hour: 19), calendar: calendar) == .evening)
        #expect(MeditationMoment.at(date(hour: 23), calendar: calendar) == .night)
        #expect(MeditationMoment.at(date(hour: 2), calendar: calendar) == .night)
    }

    @Test func freeMembersAreNeverSuggestedALockedPattern() {
        #expect(MeditationMoment.night.breathPattern(isPlus: true)?.id == "478")
        #expect(MeditationMoment.night.breathPattern(isPlus: false)?.id == "resonant")
        #expect(MeditationMoment.midday.breathPattern(isPlus: false)?.id == "sigh")
    }

    @Test func rhythmDescribesEachPhase() {
        #expect(BreathPattern.find("478")?.rhythm == "In 4 · hold 7 · out 8")
        #expect(BreathPattern.find("resonant")?.rhythm == "In 5.5 · out 5.5")
        #expect(BreathPattern.find("sigh")?.rhythm == "In 2 · in 1 · out 6")
    }
}

struct VoicedLibraryTests {
    @Test func theBundledSessionsAndGuidesLoad() {
        let sessions = VoicedLibrary.loadSessions()
        #expect(sessions.map(\.id) == VoicedLibrary.sessionOrder)
        #expect(VoicedLibrary.loadGuides().count == 10)
    }

    @Test func arriveAndResetAreFreeAndTheRestAreVidaPlus() {
        let free = VoicedLibrary.loadSessions().filter { !$0.isPremium }.map(\.id)
        #expect(free == ["arrive", "reset"])
        #expect(VoicedLibrary.loadGuides().allSatisfy { !$0.isPremium })
    }

    @Test func scriptsStayWithinTheHealthLanguageRules() {
        let banned = ["cure", "treat", "prevent", "heal", "\u{2014}", "Headspace"]
        for session in VoicedLibrary.loadSessions() {
            let text = ([session.title, session.summary] + session.segments.map(\.text)).joined(separator: " ").lowercased()
            for word in banned {
                #expect(!text.contains(word.lowercased()), "\(session.id) contains \(word)")
            }
        }
    }

    @Test func theWordsFollowTheVoice() {
        let cues = [VoicedCue(start: 2, end: 6), VoicedCue(start: 10, end: 14), VoicedCue(start: 20, end: 25)]
        #expect(VoicedLibrary.cueIndex(at: 0, in: cues) == nil)
        #expect(VoicedLibrary.cueIndex(at: 3, in: cues) == 0)
        #expect(VoicedLibrary.cueIndex(at: 12, in: cues) == 1)
        #expect(VoicedLibrary.cueIndex(at: 18, in: cues) == 1)
        #expect(VoicedLibrary.cueIndex(at: 30, in: cues) == 2)
    }

    @Test func suggestionsNeverLockFreeMembersOut() {
        let sessions = VoicedLibrary.loadSessions()
        #expect(VoicedLibrary.suggestedID(for: .night, isPlus: true, sessions: sessions) == "wind-down")
        #expect(VoicedLibrary.suggestedID(for: .night, isPlus: false, sessions: sessions) == "arrive")
        #expect(VoicedLibrary.suggestedID(for: .midday, isPlus: false, sessions: sessions) == "reset")
    }
}
