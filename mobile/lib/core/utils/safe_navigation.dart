import 'package:flutter/scheduler.dart';

/// Runs [fn] after the current frame and a microtask, so route operations
/// don't hit `Navigator` `!_debugLocked` (e.g. after [TextField] tap or
/// [Overlay.insert] in the same synchronous stack).
void runWhenNavigatorUnlocked(VoidCallback fn) {
  SchedulerBinding.instance.addPostFrameCallback((_) {
    Future.microtask(fn);
  });
}
