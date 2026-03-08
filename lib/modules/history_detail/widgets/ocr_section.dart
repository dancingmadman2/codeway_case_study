import 'package:flutter/material.dart';
import 'package:codeway_img_proc/shared/widgets/searchable_ocr_text.dart';

class OcrSection extends StatelessWidget {
  final String extractedText;
  final VoidCallback onCopy;

  const OcrSection({
    super.key,
    required this.extractedText,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SearchableOcrText(
          text: extractedText,
          onCopy: onCopy,
          embedded: true,
        ),
      ),
    );
  }
}
