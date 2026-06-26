# VBT-AI — Velocity Based Training

Camera-only, on-device AI-powered velocity-based training app. No external hardware required — uses your phone camera and machine learning to track barbell velocity and body joint angles in real-time.

![Flutter](https://img.shields.io/badge/Flutter-latest-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-latest-0175C2?logo=dart)
![Android](https://img.shields.io/badge/Android-9%2B-3DDC84?logo=android)
![ML Kit](https://img.shields.io/badge/ML%20Kit-Pose%20Detection-4285F4)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

### Barbell Tracking (Optical Flow)
- Block-matching optical flow (16x16 blocks, SSD similarity, 2-pixel search grid)
- User-defined ROI via 2-point tap calibration
- Kalman filter position smoothing with outlier rejection
- No ML model required for position tracking

### Pose Detection (MediaPipe)
- 33-joint skeleton overlay with real-time rendering
- Angle calculation for squat, bench press, deadlift, overhead press
- Angular velocity (dθ/dt) with EMA smoothing (α=0.3)
- Axis lines and color-coded angle arcs
- Front/back camera switching with live mirror

### Rep Detection & Metrics
- Automatic concentric/eccentric phase detection via velocity zero-crossing
- Mean velocity, peak velocity, ROM, time under tension
- Estimated 1RM (Epley formula + velocity-based)
- Session recording with summary and velocity chart

### Performance
- Configurable frame skip (Battery Saver / Balanced / Performance)
- Isolate-based frame processing pipeline
- ML Kit pose throttled to ~3 FPS to prevent CPU overload
- Optical flow runs at camera framerate (30 FPS)

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Framework | Flutter (latest stable) |
| State Management | Riverpod |
| Camera | `camera` plugin 0.11.x (raw YUV access) |
| Barbell Tracking | Custom block-matching optical flow |
| Position Smoothing | Kalman filter (2D) |
| Pose Detection | Google ML Kit Pose Detection (MediaPipe) |
| Angle Math | Custom 3-point joint angle calculator |
| TFLite | MoveNet Lightning (optional sanity check) |
| Min SDK | Android 24 (Android 7.0+) |
| iOS | 14+ |

---

## Architecture

```
lib/
├── domain/entities/          # Data models (BarbellPosition, RepMetrics)
├── features/
│   ├── camera/               # Barbell tracking screen + overlay
│   ├── home/                 # Home screen with navigation
│   ├── pose/                 # Standalone pose detection screen
│   └── session/              # Session summary + velocity chart
├── ml/                       # MoveNet TFLite service
├── providers/                # Riverpod providers (SessionProvider)
├── services/
│   ├── optical_flow_service.dart      # Block-matching optical flow
│   ├── tracking_fusion.dart           # Optical flow + MoveNet fusion
│   ├── pose_service.dart              # ML Kit Pose wrapper
│   ├── angle_calculator.dart          # 3-point joint angle math
│   ├── angular_velocity_engine.dart   # dθ/dt + EMA smoothing
│   ├── position_tracker.dart          # Kalman filter + outlier rejection
│   ├── velocity_calculator.dart       # Vertical displacement velocity
│   ├── rep_detector.dart              # Phase detection via zero-crossing
│   ├── metrics_calculator.dart        # ROM, mean/peak velocity, 1RM
│   ├── calibration_service.dart       # Pixels-per-meter calibration
│   ├── frame_processor.dart           # Isolate-based frame pipeline
│   └── frame_skip_strategy.dart       # Configurable frame skip
└── app/                      # App configuration, theme, routes
```

---

## Screens

### Home
- Start new session / calibrate / view last session
- Performance mode selector (Battery / Balanced / Performance)

### Camera (Barbell Tracking)
1. Tap left end of barbell → tap right end (defines ROI)
2. Start session → optical flow tracks barbell centroid
3. Real-time velocity overlay + rep counter
4. View summary with velocity chart

### Pose & Angles
- Standalone MediaPipe pose detection
- Exercise selector (Squat / Bench / Deadlift / Overhead)
- Skeleton overlay with angle arcs and axis lines
- Real-time angle + angular velocity display
- Front/back camera switching

---

## Getting Started

### Prerequisites
- Flutter SDK (latest stable)
- Android Studio / VS Code
- Android device (API 24+) or iOS device (14+)

### Installation

```bash
# Clone the repository
git clone https://github.com/ali127182/vbt-ai.git
cd vbt-ai

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Build APK

```bash
flutter build apk --release
```

---

## Configuration

### Frame Skip Modes
- **Battery Saver**: Process every 6th frame (~5 FPS detection)
- **Balanced**: Process every 3rd frame (~10 FPS detection)
- **Performance**: Process every frame (~30 FPS detection)

### ML Kit Pose
- Model: MediaPipe Pose (base/lite variant)
- Processing: Every 8th frame (~3-4 FPS) to prevent CPU overload
- Output: 33 landmarks with confidence scores

### Calibration
- 2-point tap defines tracking ROI
- Pixels-per-meter calculated from known barbell width
- Stored locally via SharedPreferences

---

## How It Works

1. **Camera frames** → NV21 byte conversion → Isolate processing
2. **Optical flow** → Block matching within ROI → centroid position
3. **Kalman filter** → Smooth position + predict velocity
4. **Velocity** → Vertical displacement / time delta
5. **Rep detection** → Eccentric (negative velocity) → concentric (positive velocity) transition
6. **Pose detection** → MediaPipe landmarks → joint angles → angular velocity (dθ/dt)

---

## Performance Notes

- Tested on Samsung devices (Exynos/MediaTek SoC)
- Optical flow: ~30 FPS on mid-range devices
- Pose detection: ~3-4 FPS (throttled to prevent crash)
- Memory: ~30-35 MB during operation
- ML Kit loads models on first run (~2-3 seconds)

---

## License

MIT License - see [LICENSE](LICENSE) for details.
