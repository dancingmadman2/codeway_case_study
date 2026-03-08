# The Image Processoooor

Auto-detects faces vs documents and applies the appropriate processing pipeline.

## Decisions

- **Storage**: Hive
- **Image processing**: OpenCV + `image` package
- **Bonus**: Real-time camera overlay, OCR extraction

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

## Setup

```bash
git clone https://github.com/dancingmadman2/codeway_case_study.git
cd codeway_case_study

flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Requires CMake for `opencv_dart`. Physical device recommended for camera + ML Kit.
