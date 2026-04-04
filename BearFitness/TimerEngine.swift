//
//  TimerEngine.swift
//  BearFitness
//
//  Created by Yerin Kang on 4/2/26.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation

@Observable
final class TimerEngine {
    // MARK: - Timer State
    enum TimerState {
        case idle, running, paused, completed
    }

    var state: TimerState = .idle
    var currentSectionIndex: Int = 0
    var secondsRemaining: Int = 0
    var totalElapsedSeconds: Int = 0

    // MARK: - Program Info
    private(set) var programName: String = ""
    private(set) var workoutType: String = ""
    private(set) var sections: [TimerSection] = []
    private(set) var startedAt: Date = Date()

    // Per-section tracking
    private var sectionStartTime: Date = Date()
    private(set) var completedSections: [SessionSection] = []

    private var timer: Timer?
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Voice Announcements
    private func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func announcePhase(_ phase: WorkoutPhase) {
        switch phase {
        case .warmUp:        speak("Warm up")
        case .highIntensity: speak("High intensity")
        case .lowIntensity:  speak("Low intensity")
        case .coolDown:      speak("Cool down")
        }
    }

    private func announceCountdown(_ seconds: Int) {
        switch seconds {
        case 3: speak("3")
        case 2: speak("2")
        case 1: speak("1")
        default: break
        }
    }

    // MARK: - Computed
    var currentSection: TimerSection? {
        guard currentSectionIndex < sections.count else { return nil }
        return sections[currentSectionIndex]
    }

    var currentPhase: WorkoutPhase {
        currentSection?.phase ?? .warmUp
    }

    var progress: Double {
        guard let section = currentSection, section.durationSeconds > 0 else { return 0 }
        let elapsed = section.durationSeconds - secondsRemaining
        return Double(elapsed) / Double(section.durationSeconds)
    }

    var currentRound: Int {
        currentSection?.roundNumber ?? 1
    }

    var totalRounds: Int {
        sections.map(\.roundNumber).max() ?? 1
    }

    var currentInterval: Int {
        currentSection?.intervalNumber ?? 1
    }

    var totalIntervals: Int {
        // Count intervals in current round
        let round = currentRound
        return sections.filter { $0.roundNumber == round && ($0.phase == .highIntensity || $0.phase == .lowIntensity) }.count
    }

    var totalRemainingSeconds: Int {
        guard currentSectionIndex < sections.count else { return 0 }
        let remaining = sections[currentSectionIndex...].dropFirst().reduce(0) { $0 + $1.durationSeconds }
        return remaining + secondsRemaining
    }

    var formattedTimeRemaining: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedTotalRemaining: String {
        let t = totalRemainingSeconds
        let m = t / 60
        let s = t % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Setup
    func setup(from program: HIITProgram) {
        programName = program.name
        workoutType = program.workoutType
        sections = buildSections(from: program)
        currentSectionIndex = 0
        secondsRemaining = sections.first?.durationSeconds ?? 0
        totalElapsedSeconds = 0
        completedSections = []
        state = .idle
    }

    private func buildSections(from program: HIITProgram) -> [TimerSection] {
        var result: [TimerSection] = []

        // Warm up
        if program.warmUpSeconds > 0 {
            result.append(TimerSection(
                phase: .warmUp,
                durationSeconds: program.warmUpSeconds,
                roundNumber: 0,
                intervalNumber: 0
            ))
        }

        // Interval cycles
        let cycleCount = program.repeatEnabled ? program.numberOfCycles : 1
        for cycle in 1...cycleCount {
            for set in 1...program.intervalSets {
                if program.highIntensitySeconds > 0 {
                    result.append(TimerSection(
                        phase: .highIntensity,
                        durationSeconds: program.highIntensitySeconds,
                        roundNumber: cycle,
                        intervalNumber: set
                    ))
                }
                if program.lowIntensitySeconds > 0 {
                    result.append(TimerSection(
                        phase: .lowIntensity,
                        durationSeconds: program.lowIntensitySeconds,
                        roundNumber: cycle,
                        intervalNumber: set
                    ))
                }
            }
        }

        // Cool down
        if program.coolDownSeconds > 0 {
            result.append(TimerSection(
                phase: .coolDown,
                durationSeconds: program.coolDownSeconds,
                roundNumber: 0,
                intervalNumber: 0
            ))
        }

        return result
    }

    // MARK: - Controls
    func start() {
        guard state == .idle || state == .paused else { return }
        // If no sections (all durations were 0), immediately complete
        guard !sections.isEmpty else {
            state = .completed
            return
        }
        if state == .idle {
            startedAt = Date()
            sectionStartTime = Date()
        }
        if state == .paused {
            sectionStartTime = Date()
        }
        state = .running
        startTimer()
        // Announce the first section when starting
        if let phase = currentSection?.phase {
            announcePhase(phase)
        }
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        timer?.invalidate()
        timer = nil
    }

    func togglePlayPause() {
        if state == .running {
            pause()
        } else {
            start()
        }
    }

    func skipToNext() {
        guard currentSectionIndex < sections.count else { return }
        recordCurrentSection()
        moveToNextSection()
    }

    func skipToPrevious() {
        guard currentSectionIndex > 0 else {
            // Reset current section
            secondsRemaining = currentSection?.durationSeconds ?? 0
            sectionStartTime = Date()
            return
        }
        currentSectionIndex -= 1
        secondsRemaining = sections[currentSectionIndex].durationSeconds
        sectionStartTime = Date()
        // Announce the phase we went back to
        if let phase = currentSection?.phase {
            announcePhase(phase)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
    }

    // MARK: - Timer Logic
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.tick()
            }
        }
    }

    private func tick() {
        guard state == .running else { return }

        totalElapsedSeconds += 1

        if secondsRemaining > 0 {
            secondsRemaining -= 1
        }

        // Countdown voice: 3, 2, 1
        if secondsRemaining > 0 && secondsRemaining <= 3 {
            announceCountdown(secondsRemaining)
        }

        if secondsRemaining == 0 {
            recordCurrentSection()
            moveToNextSection()
        }
    }

    private func recordCurrentSection() {
        guard let section = currentSection else { return }
        let now = Date()
        let actualDuration = section.durationSeconds - secondsRemaining

        completedSections.append(SessionSection(
            phase: section.phase,
            plannedDurationSeconds: section.durationSeconds,
            actualDurationSeconds: actualDuration,
            startTimestamp: sectionStartTime,
            endTimestamp: now,
            roundNumber: section.roundNumber,
            intervalNumber: section.intervalNumber
        ))
    }

    private func moveToNextSection() {
        currentSectionIndex += 1
        if currentSectionIndex >= sections.count {
            // Workout complete
            state = .completed
            timer?.invalidate()
            timer = nil
            speak("Workout complete!")
        } else {
            secondsRemaining = sections[currentSectionIndex].durationSeconds
            sectionStartTime = Date()
            // Announce the new phase
            if let phase = currentSection?.phase {
                announcePhase(phase)
            }
        }
    }

    // MARK: - Build Session for saving
    func buildSession() -> WorkoutSession {
        WorkoutSession(
            programName: programName,
            workoutType: workoutType,
            startedAt: startedAt,
            endedAt: Date(),
            totalDurationSeconds: totalElapsedSeconds,
            sections: completedSections
        )
    }
}

// MARK: - Timer Section (planned phases)
struct TimerSection: Identifiable {
    let id = UUID()
    let phase: WorkoutPhase
    let durationSeconds: Int
    let roundNumber: Int
    let intervalNumber: Int
}
