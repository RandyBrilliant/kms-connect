import 'package:flutter/material.dart';

/// App-wide [ScaffoldMessenger] so snackbars (e.g. delete undo) survive route changes.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
