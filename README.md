# The Image Processoooor

A flutter app that auto-detects whether an image contains a **face** or a **document** and applies the appropriate processing pipeline.

## Features

- **Auto-detection** — ML Kit classifies input as face or document, routes to the correct pipeline
- **Face pipeline** — Detect faces, crop, apply grayscale filter, composite back onto original
- **Document pipeline** — Detect text regions, identify edges, perspective-correct, enhance contrast, export to PDF
- **Real-time camera overlay** — Live bounding boxes for faces, text-block-based document outline with smoothed corners
- **OCR extraction** — Recognized text saved with history, searchable and copyable
- **Processing history** — All results stored locally with thumbnails for quick browsing
- **Share & export** — Share processed images or PDFs directly from the app

## Architecture

Clean Architecture (Presentation → Domain → Data) with GetX for state management and dependency injection. Each screen has its own Controller and Binding.

## Dependencies

| Category | Package |
|---|---|
| State Management | `get` (GetX) |
| Face Detection | `google_mlkit_face_detection` |
| Text Recognition | `google_mlkit_text_recognition` |
| Camera | `camera` |
| Image Processing | `image`, `opencv_dart` |
| PDF Export | `pdf` |
| Local Storage | `hive_ce` / `hive_ce_flutter` |
| Code Generation | `build_runner` / `hive_ce_generator` |

## Setup

```bash
git clone https://github.com/dancingmadman2/codeway_case_study.git
cd codeway_case_study

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Requires CMake for `opencv_dart`. A physical device is recommended since the app uses the camera and ML Kit.
