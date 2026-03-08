import 'package:flutter/foundation.dart';

class OcrSearchInput {
  final String text;
  final String query;
  const OcrSearchInput(this.text, this.query);
}

class OcrSearchResult {
  final int matchCount;
  final List<int> matchStarts;
  final List<int> matchEnds;
  const OcrSearchResult(this.matchCount, this.matchStarts, this.matchEnds);

  static const empty = OcrSearchResult(0, [], []);
}

/// Top-level function so it can be passed to [compute].
OcrSearchResult performOcrSearch(OcrSearchInput input) {
  if (input.query.isEmpty) return OcrSearchResult.empty;

  final pattern = RegExp(RegExp.escape(input.query), caseSensitive: false);
  final matches = pattern.allMatches(input.text).toList();
  if (matches.isEmpty) return OcrSearchResult.empty;

  return OcrSearchResult(
    matches.length,
    matches.map((m) => m.start).toList(),
    matches.map((m) => m.end).toList(),
  );
}

const _isolateThreshold = 5000;

/// Runs search synchronously for short texts, on an isolate for long texts.
Future<OcrSearchResult> ocrSearch(String text, String query) {
  if (query.isEmpty) return SynchronousFuture(OcrSearchResult.empty);

  final input = OcrSearchInput(text, query);

  if (text.length < _isolateThreshold) {
    return SynchronousFuture(performOcrSearch(input));
  }

  return compute(performOcrSearch, input);
}
