# 🐻 BearFitness

A comprehensive iOS fitness companion app that combines Apple Fitness workout tracking with custom HIIT (High-Intensity Interval Training) program creation and heart rate zone analysis.

## Overview

BearFitness seamlessly integrates with Apple Health and HealthKit to provide deep insights into your workouts while offering a powerful HIIT training platform with real-time guidance and performance analysis.

## Key Features

### Apple Fitness Integration

**Workout Library**
- Automatically syncs all workouts from Apple Fitness
- Smart filtering by workout type (Running, Cycling, Swimming, etc.)
- Organized by date: Today, Yesterday, This Week, This Month, or custom months
- Pull-to-refresh to sync latest workouts
- Quick stats: Duration, distance, calories burned

**Detailed Workout Analysis**
- Comprehensive statistics dashboard
- Interactive heart rate chart with area visualization
- Average, maximum, and minimum heart rate tracking
- Orange dashed line showing average HR throughout workout

**Heart Rate Zone Analysis**
The app analyzes your entire workout and breaks down time spent in each zone:
- **Zone 1** (Very Light): < 100 bpm - 🔵 Cyan
- **Zone 2** (Light): 100-119 bpm - 🟢 Green  
- **Zone 3** (Moderate): 120-139 bpm - 🟡 Yellow
- **Zone 4** (Hard): 140-159 bpm - 🟠 Orange
- **Zone 5** (Maximum): 160+ bpm - 🔴 Red

Each zone displays:
- Visual progress bar
- Percentage of time spent
- Color-coded indicator

**GPS Route with Heart Rate Heatmap**
- Interactive map showing your workout route
- Route segments colored by heart rate zones in real-time
- Start (green) and end (red) markers
- Legend showing zone colors

### 💪 HIIT Program Builder

**Create Custom Programs**

Build personalized HIIT workouts with complete control:

1. **Program Setup**
   - Name your program
   - Choose workout type (Running, Walking, Cycling, Swimming, Rowing, Elliptical, Jump Rope, Stair Climbing, Mixed Cardio)

2. **Warm-Up Phase**
   - Set duration in minutes and seconds
   - Visual orange indicator

3. **Interval Configuration**
   - **High Intensity** (pink): Set duration for max effort periods
   - **Low Intensity** (green): Set duration for recovery periods
   - **Interval Sets**: Number of high/low cycles per round (1-20)

4. **Repeat Cycles**
   - Toggle to enable multiple rounds
   - Set number of cycles (2-20)
   - Perfect for progressive HIIT sessions

5. **Cool-Down Phase**
   - Set duration for post-workout recovery
   - Visual blue indicator

6. **Real-Time Preview**
   - Total duration calculated automatically
   - Displays in HH:MM:SS format

**Program Management**
- Edit any saved program
- Delete programs with confirmation
- Quick-start button on each program card
- View all programs in a scrollable list

### ⏱️ Interactive HIIT Timer

**Immersive Timer Experience**

The timer provides a full-screen, distraction-free workout experience:

**Visual Feedback**
- Dynamic background color matching current phase:
  - 🟠 Orange: Warm-up
  - 🔴 Pink/Red: High intensity
  - 🟢 Green: Low intensity  
  - 🔵 Blue: Cool-down
- Circular progress ring showing phase completion
- Large, easy-to-read countdown timer (MM:SS)
- Current phase label (WARM UP, HIGH INTENSITY, etc.)
- Target heart rate range for current phase

**Live Stats Bar**
Three key metrics displayed in a bordered panel:
- **Rounds**: Current round / Total rounds
- **Remaining Time**: Total time left in workout
- **Interval**: Current interval / Total intervals

**Controls**
- ⏮️ **Previous**: Skip to previous section
- ⏯️ **Play/Pause**: Large center button (changes color with phase)
- ⏭️ **Next**: Skip to next section
- ❌ **Close**: Exit workout (top-right)

**Voice Guidance**
Audio cues keep you focused without looking at your device:
- Announces each phase: "Warm up", "High intensity", "Low intensity", "Cool down"
- Countdown for transitions: "3", "2", "1"
- Completion announcement: "Workout complete!"

**Session Recording**
Every workout is tracked:
- Start and end timestamps for each section
- Planned vs actual duration for every phase
- Round and interval numbering
- Option to save or discard after completion

### Session History & Analysis

**Completed Workouts**

View all your finished HIIT sessions:
- Session cards showing program name and workout type
- Date and time completed
- Total duration in HH:MM:SS format
- Number of sections completed

**Detailed Session View**
Tap any session to see:
- Complete section breakdown
- Each phase with actual vs planned duration
- Completion percentage per section (90%+ shown in blue)
- Round and interval labels
- Start and end timestamps

**HIIT Performance Analysis**

The most powerful feature - validate your HIIT performance using Apple Watch heart rate data:

1. **Apply Session to Workout**
   - From any Apple Fitness workout detail, tap "Apply"
   - Select matching HIIT session (shows sessions within ±2 hours)
   - App analyzes heart rate data against HIIT targets

2. **Target Heart Rate Zones**
Each HIIT phase has specific target zones:
   - **Warm-Up**: 100-119 bpm (Zone 1-2)
   - **High Intensity**: 140-170 bpm (Zone 4-5)
   - **Low Intensity**: 100-139 bpm (Zone 2-3)
   - **Cool-Down**: 100-119 bpm (Zone 1-2)

3. **Analysis Results**
   - **Overall Score**: Circular progress indicator showing % of sections hitting target zones
   - Color-coded performance:
     - 🟢 Green: ≥80% (Excellent)
     - 🟠 Orange: 50-79% (Good)
     - 🔴 Red: <50% (Needs improvement)
   
4. **Section-by-Section Breakdown**
For each phase, see:
   - Target BPM range
   - Actual average BPM achieved
   - Actual heart rate zone
   - ✅ Pass or ❌ Fail indicator
   - Round and interval numbers

This helps you understand if you're truly hitting your intensity targets during HIIT training!

### Points System (UI Ready)

The app displays points badges on qualifying workouts:
- "+20" points shown on recent workouts
- Star icon indicator
- Foundation ready for gamification features

## Technical Architecture

**Frameworks & Technologies**
- **SwiftUI**: Modern declarative UI
- **SwiftData**: Persistent storage for programs and sessions
- **HealthKit**: Workout and heart rate data integration
- **MapKit**: GPS route visualization
- **Swift Charts**: Interactive heart rate charts
- **AVFoundation**: Text-to-speech voice guidance
- **Swift Concurrency**: async/await for all data operations

**Performance Optimizations**
- Chart data downsampled to 300 points for smooth scrolling
- Route segments downsampled to 500 points for map performance
- Binary search algorithm for HR-to-location matching (O(log n))
- Precomputed heart rate statistics
- Lazy loading for workout lists

**Data Models**
- `HIITProgram`: Custom workout programs (SwiftData)
- `WorkoutSession`: Completed HIIT sessions (SwiftData)
- `SessionSection`: Individual phase tracking
- `WorkoutPhase`: Enum with target HR zones
- `HeartRateZone`: Five-zone classification system

## Design System

**Visual Identity**
- Purple-blue gradient primary accent
- Phase-specific colors for visual clarity
- Card-based layouts with subtle shadows
- Gradient text effects for emphasis

**Typography**
- Custom font tokens for consistency
- Monospaced digits for time displays
- Clear hierarchy with font weights

**UI Patterns**
- Segmented controls for tab navigation
- Filter pills for workout types
- Floating Action Button for primary actions
- Full-screen immersive timer
- Sheet presentations for forms and results

## Setup Requirements

**Prerequisites**
- iOS 17.0+ / iPadOS 17.0+
- Xcode 15.0+
- Apple Watch (recommended for heart rate tracking)
- Apple Fitness app with completed workouts

**HealthKit Capabilities**
The app requests read access to:
- Workouts
- Heart Rate
- Active Energy Burned
- Basal Energy Burned
- Distance (Walking/Running, Cycling, Swimming)
- Step Count
- Swimming Stroke Count
- Flights Climbed
- Workout Routes

**Installation**
1. Clone the repository
2. Open `BearFitness.xcodeproj` in Xcode
3. Ensure HealthKit capability is enabled
4. Build and run on a physical device (HealthKit not available in simulator)

## Usage Guide

### Getting Started

1. **First Launch**
   - Grant HealthKit permissions when prompted
   - Navigate to Workout tab to see Apple Fitness workouts

2. **Create Your First HIIT Program**
   - Go to Program tab
   - Tap the + button
   - Configure your intervals and durations
   - Save

3. **Run a HIIT Session**
   - Find your program in "My Programs"
   - Tap the play button
   - Follow voice and visual guidance
   - Save when complete

4. **Analyze Performance**
   - Complete HIIT session while wearing Apple Watch
   - Go to Workout tab
   - Open your workout detail
   - Tap "Apply" and select matching session
   - Review your heart rate zone compliance
