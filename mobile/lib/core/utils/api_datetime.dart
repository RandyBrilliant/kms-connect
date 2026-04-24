class ApiDateTime {
  const ApiDateTime._();

  /// Parses an API datetime value safely.
  ///
  /// - Returns `null` when [value] is null/empty/invalid.
  /// - Converts UTC timestamps to local device time (WIB/WITA/WIT).
  /// - Keeps naive/local timestamps as-is.
  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Parses a required API datetime value.
  ///
  /// Throws [FormatException] when missing/invalid.
  static DateTime parseRequired(dynamic value, {required String fieldName}) {
    final parsed = parse(value);
    if (parsed == null) {
      throw FormatException('Invalid or missing datetime for "$fieldName".');
    }
    return parsed;
  }
}
