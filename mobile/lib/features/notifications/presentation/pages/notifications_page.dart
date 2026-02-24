import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/auth_wave_header.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/notification_provider.dart';
import '../../domain/models/app_notification.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const headerH = 140.0;
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          SizedBox(
            height: headerH + topPad,
            child: Stack(
              children: [
                Positioned.fill(
                    child:
                        AuthWaveHeader(height: headerH + topPad)),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, topPad + 10, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white
                                .withValues(alpha: 0.18),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Notifikasi',
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (state.unreadCount > 0)
                              Text(
                                '${state.unreadCount} belum dibaca',
                                style: tt.bodySmall?.copyWith(
                                  color: Colors.white
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (state.unreadCount > 0)
                        GestureDetector(
                          onTap: () {
                            ref
                                .read(notificationProvider.notifier)
                                .markAllRead();
                            CustomToast.show(context,
                                message: 'Semua notifikasi ditandai dibaca',
                                type: ToastType.success);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white
                                  .withValues(alpha: 0.18),
                              border: Border.all(
                                color: Colors.white
                                    .withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: const Icon(
                                Icons.done_all_rounded,
                                color: Colors.white,
                                size: 18),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primaryDarkGreen,
                        strokeWidth: 2.5))
                : state.notifications.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryDarkGreen,
                        onRefresh: () =>
                            ref.read(notificationProvider.notifier).load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                              20, 16, 20, 32),
                          itemCount: state.notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final n = state.notifications[i];
                            return _NotificationCard(
                              notification: n,
                              onTap: () => ref
                                  .read(notificationProvider.notifier)
                                  .markRead(n.id),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationCard
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });
  final AppNotification notification;
  final VoidCallback onTap;

  static const _typeConfig = {
    'SYSTEM': (Color(0xFF2563EB), Color(0xFFDBEAFE), Icons.settings_rounded),
    'JOB': (AppColors.primaryDarkGreen, AppColors.secondaryLightGreen, Icons.work_outline_rounded),
    'APPLICATION': (AppColors.primaryDarkGreen, AppColors.secondaryLightGreen, Icons.assignment_outlined),
    'DOCUMENT': (Color(0xFFD97706), Color(0xFFFEF3C7), Icons.folder_open_outlined),
    'PROFILE': (Color(0xFF7C3AED), Color(0xFFEDE9FE), Icons.person_outline_rounded),
    'BROADCAST': (AppColors.error, Color(0xFFFFE4E6), Icons.campaign_outlined),
    'INFO': (Color(0xFF0284C7), Color(0xFFE0F2FE), Icons.info_outline_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final cfg = _typeConfig[notification.notificationType] ??
        _typeConfig['SYSTEM']!;
    final (Color iconFg, Color iconBg, IconData icon) = cfg;

    final timeStr = _relativeTime(notification.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: notification.isRead
              ? cs.surface
              : iconBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? cs.outlineVariant
                : iconFg.withValues(alpha: 0.25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconFg, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: iconFg,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.message,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        timeStr,
                        style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 7) {
      return DateFormat('dd MMM yyyy', 'id').format(dt);
    }
    if (diff.inDays >= 1) return '${diff.inDays} hari lalu';
    if (diff.inHours >= 1) return '${diff.inHours} jam lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes} menit lalu';
    return 'Baru saja';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmptyState
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.secondaryLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_outlined,
                  size: 40, color: AppColors.primaryDarkGreen),
            ),
            const SizedBox(height: 16),
            Text('Belum Ada Notifikasi',
                style: tt.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Notifikasi terbaru akan muncul di sini.',
              style: tt.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
