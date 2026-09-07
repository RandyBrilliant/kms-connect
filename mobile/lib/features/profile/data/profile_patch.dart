bool profileFieldEquals(Object? a, Object? b) {
  if (a is String && b is String) return a.trim() == b.trim();
  return a == b;
}

/// PATCH body with only keys whose values differ from [baseline].
///
/// Empty optional strings are omitted unless they changed (so a failed
/// hydrate cannot wipe stored biodata). Clearing a previously filled field
/// still sends the empty value.
Map<String, dynamic> changedProfileFields({
  required Map<String, dynamic> baseline,
  required Map<String, dynamic> current,
}) {
  final out = <String, dynamic>{};
  for (final entry in current.entries) {
    if (!profileFieldEquals(entry.value, baseline[entry.key])) {
      out[entry.key] = entry.value;
    }
  }
  return out;
}
