enum ProcessingStep {
  capturing,
  detecting,
  faceDetection,
  faceCropping,
  faceFilter,
  faceComposite,
  docEdgeDetection,
  docPerspectiveTransform,
  docCrop,
  docContrastEnhance,
  docOcrEnhanced,
  docPdfExport,
  saving;

  String get description {
    switch (this) {
      case ProcessingStep.capturing:
        return 'Capturing image';
      case ProcessingStep.detecting:
        return 'Detecting content type';
      case ProcessingStep.faceDetection:
        return 'Detecting faces';
      case ProcessingStep.faceCropping:
        return 'Cropping detected faces';
      case ProcessingStep.faceFilter:
        return 'Applying face filter';
      case ProcessingStep.faceComposite:
        return 'Compositing faces onto image';
      case ProcessingStep.docEdgeDetection:
        return 'Detecting document edges';
      case ProcessingStep.docPerspectiveTransform:
        return 'Applying perspective transform';
      case ProcessingStep.docCrop:
        return 'Cropping document';
      case ProcessingStep.docContrastEnhance:
        return 'Enhancing contrast';
      case ProcessingStep.docOcrEnhanced:
        return 'Recognizing text';
      case ProcessingStep.docPdfExport:
        return 'Exporting to PDF';
      case ProcessingStep.saving:
        return 'Saving results';
    }
  }
}
