import 'dart:async';

/// A simple debouncer that delays execution until after [milliseconds]
/// have elapsed since the last call.
///
/// Useful for search fields to avoid firing API requests on every keystroke.
///
/// ```dart
/// final _debouncer = Debouncer(milliseconds: 400);
/// _debouncer.run(() => setState(() {}));
/// // dispose in dispose():
/// _debouncer.dispose();
/// ```
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({this.milliseconds = 400});

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  /// Cancel any pending timer without executing the action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Alias for [cancel]. Call in widget's dispose().
  void dispose() {
    cancel();
  }
}
