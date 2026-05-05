import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/colors.dart';
import '../../../core/navigation/root_scaffold_messenger.dart';
import '../data/providers/notification_provider.dart';

/// Shown after a queued delete; undo calls [NotificationNotifier.cancelPendingDelete].
void showNotificationDeleteUndoSnackBar(WidgetRef ref, int notificationId) {
  rootScaffoldMessengerKey.currentState?.clearSnackBars();
  rootScaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      content: Text(
        'Notifikasi dihapus',
        style: GoogleFonts.plusJakartaSans(color: Colors.white),
      ),
      action: SnackBarAction(
        label: 'Urungkan',
        textColor: Colors.white,
        onPressed: () {
          ref
              .read(notificationProvider.notifier)
              .cancelPendingDelete(notificationId);
        },
      ),
      duration: NotificationNotifier.deleteUndoDuration,
      backgroundColor: AppColors.textDark,
    ),
  );
}
