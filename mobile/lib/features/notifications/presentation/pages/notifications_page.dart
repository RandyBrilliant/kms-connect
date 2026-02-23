import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/colors.dart';
import '../../domain/models/app_notification.dart';
import '../../data/providers/notification_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF0F172A)),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Text(
              'Notifikasi',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryDarkGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: state.isLoading
                  ? null
                  : () =>
                      ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text(
                'Tandai dibaca',
                style: TextStyle(
                  color: AppColors.primaryDarkGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryDarkGreen,
          strokeWidth: 2,
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_outlined,
                  size: 44, color: Color(0xFFCBD5E1)),
              const SizedBox(height: 16),
              const Text(
                'Gagal memuat notifikasi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () =>
                    ref.read(notificationProvider.notifier).load(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDarkGreen,
                  side: const BorderSide(color: AppColors.primaryDarkGreen),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return _EmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primaryDarkGreen,
      onRefresh: () => ref.read(notificationProvider.notifier).load(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: state.notifications.length,
        itemBuilder: (context, index) {
          return _NotificationCard(
            item: state.notifications[index],
            onTap: () {
              if (!state.notifications[index].isRead) {
                ref
                    .read(notificationProvider.notifier)
                    .markRead(state.notifications[index].id);
              }
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notification Card
// ---------------------------------------------------------------------------

class _NotificationCard extends StatelessWidget {
  final AppNotification item;
  final VoidCallback onTap;

  const _NotificationCard({required this.item, required this.onTap});

  // Map notification_type → icon + colors
  static const _typeConfig = <String, _TypeConfig>{
    'SYSTEM': _TypeConfig(Icons.settings_outlined, Color(0xFFDBEAFE), Color(0xFF2563EB)),
    'JOB': _TypeConfig(Icons.work_outline, Color(0xFFD1FAE5), Color(0xFF16A34A)),
    'APPLICATION': _TypeConfig(Icons.send_outlined, Color(0xFFF0FDF4), Color(0xFF15803D)),
    'DOCUMENT': _TypeConfig(Icons.folder_open_outlined, Color(0xFFFEF3C7), Color(0xFFD97706)),
    'PROFILE': _TypeConfig(Icons.person_outline, Color(0xFFEDE9FE), Color(0xFF7C3AED)),
    'BROADCAST': _TypeConfig(Icons.campaign_outlined, Color(0xFFFFE4E6), Color(0xFFE11D48)),
    'INFO': _TypeConfig(Icons.info_outline, Color(0xFFDBEAFE), Color(0xFF2563EB)),
  };

  static _TypeConfig _configFor(String type) =>
      _typeConfig[type.toUpperCase()] ??
      const _TypeConfig(Icons.notifications_outlined, Color(0xFFF1F5F9), Color(0xFF64748B));

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 1) return '${diff.inDays}h lalu';
    if (diff.inHours >= 1) return '${diff.inHours}j lalu';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m lalu';
    return 'Baru saja';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _configFor(item.notificationType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isRead
            ? Colors.white
            : AppColors.primaryDarkGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isRead
              ? const Color(0xFFE2E8F0)
              : AppColors.primaryDarkGreen.withOpacity(0.20),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: cfg.bg),
                  child: Icon(cfg.icon, color: cfg.fg, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: item.isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relativeTime(item.createdAt),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.message,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.actionLabel != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          item.actionLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDarkGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!item.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primaryDarkGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeConfig {
  final IconData icon;
  final Color bg;
  final Color fg;
  const _TypeConfig(this.icon, this.bg, this.fg);
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryDarkGreen.withOpacity(0.08),
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              size: 36,
              color: AppColors.primaryDarkGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada notifikasi',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Semua notifikasi akan muncul di sini.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
