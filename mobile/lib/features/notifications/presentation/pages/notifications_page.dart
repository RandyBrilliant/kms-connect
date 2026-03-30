import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../core/widgets/custom_toast.dart';
import '../../data/providers/notification_provider.dart';
import '../../domain/models/app_notification.dart';

/// Professional notifications page with clean Material Design 3 styling
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationProvider);
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        children: [
          // ── Professional Header ──────────────────────────────────────────────
          _ProfessionalNotificationHeader(
            topPad: topPad,
            unreadCount: state.unreadCount,
            onBack: () => Navigator.pop(context),
            onMarkAllRead: state.unreadCount > 0 
              ? () {
                  ref.read(notificationProvider.notifier).markAllRead();
                  CustomToast.show(
                    context,
                    message: 'Semua notifikasi ditandai dibaca',
                    type: ToastType.success,
                  );
                }
              : null,
          ),

          // ── Content ───────────────────────────────────────────────────────────
          Expanded(
            child: state.isLoading && state.notifications.isEmpty
                ? const _ProfessionalLoadingState()
                : state.notifications.isEmpty
                    ? const _ProfessionalEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primaryDarkGreen,
                        backgroundColor: Colors.white,
                        onRefresh: () => ref.read(notificationProvider.notifier).load(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                          itemCount: state.notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final n = state.notifications[i];
                            return _ProfessionalNotificationCard(
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
// Professional Notification Header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNotificationHeader extends StatelessWidget {
  const _ProfessionalNotificationHeader({
    required this.topPad,
    required this.unreadCount,
    required this.onBack,
    this.onMarkAllRead,
  });

  final double topPad;
  final int unreadCount;
  final VoidCallback onBack;
  final VoidCallback? onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.divider.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Back button + Title + Action
          Row(
            children: [
              // Back button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDarkGreen.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryDarkGreen.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: AppColors.primaryDarkGreen,
                      size: 20,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifikasi',
                      style: tt.headlineSmall?.copyWith(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (unreadCount > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$unreadCount belum dibaca',
                            style: tt.bodyMedium?.copyWith(
                              color: AppColors.textMedium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              
              // Mark all read button
              if (onMarkAllRead != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onMarkAllRead,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDarkGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDarkGreen.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.done_all_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tandai Semua',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Professional Notification Card
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalNotificationCard extends StatelessWidget {
  const _ProfessionalNotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  // Enhanced type configuration with professional colors
  static const _typeConfig = {
    'SYSTEM': (Color(0xFF3B82F6), Color(0xFFEFF6FF), Icons.settings_rounded),
    'JOB': (AppColors.primaryDarkGreen, Color(0xFFF0F9F4), Icons.work_outline_rounded),
    'APPLICATION': (Color(0xFF0891B2), Color(0xFFECFCFF), Icons.description_outlined),
    'DOCUMENT': (Color(0xFFF59E0B), Color(0xFFFFFBEB), Icons.folder_open_outlined),
    'PROFILE': (Color(0xFF8B5CF6), Color(0xFFF3F4F6), Icons.person_outline_rounded),
    'BROADCAST': (Color(0xFFEF4444), Color(0xFFFEF2F2), Icons.campaign_outlined),
    'INFO': (Color(0xFF06B6D4), Color(0xFFECFDF5), Icons.info_outline_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cfg = _typeConfig[notification.notificationType] ?? _typeConfig['SYSTEM']!;
    final (Color iconFg, Color iconBg, IconData icon) = cfg;
    final timeStr = _relativeTime(notification.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.divider.withValues(alpha: 0.3)
                  : iconFg.withValues(alpha: 0.3),
              width: notification.isRead ? 1 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: notification.isRead 
                    ? Colors.black.withValues(alpha: 0.04)
                    : iconFg.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced icon with status indicator
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: iconFg.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: Icon(icon, color: iconFg, size: 22),
                  ),
                  if (!notification.isRead)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title with professional typography
                    Text(
                      notification.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Message
                    Text(
                      notification.message,
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.textMedium,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Time and type badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: tt.labelMedium?.copyWith(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        
                        // Type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: iconFg.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getTypeLabel(notification.notificationType),
                            style: tt.labelSmall?.copyWith(
                              color: iconFg,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTypeLabel(String? type) {
    switch (type) {
      case 'SYSTEM': return 'Sistem';
      case 'JOB': return 'Lowongan';
      case 'APPLICATION': return 'Lamaran';
      case 'DOCUMENT': return 'Dokumen';
      case 'PROFILE': return 'Profil';
      case 'BROADCAST': return 'Pengumuman';
      case 'INFO': return 'Info';
      default: return 'Umum';
    }
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
// Professional Loading State
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalLoadingState extends StatelessWidget {
  const _ProfessionalLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryDarkGreen,
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Memuat notifikasi...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Professional Empty State
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalEmptyState extends StatelessWidget {
  const _ProfessionalEmptyState();

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with professional styling
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryDarkGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.primaryDarkGreen,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Title
            Text(
              'Belum Ada Notifikasi',
              style: tt.headlineSmall?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Subtitle
            Text(
              'Notifikasi terbaru akan muncul di sini.\nAnda akan mendapat pemberitahuan untuk lowongan,\nlamaran, dan pengumuman penting.',
              style: tt.bodyMedium?.copyWith(
                color: AppColors.textMedium,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            // Decorative elements
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _EmptyStateIcon(
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(width: 16),
                _EmptyStateIcon(
                  icon: Icons.description_outlined,
                  color: AppColors.primaryDarkGreen,
                ),
                const SizedBox(width: 16),
                _EmptyStateIcon(
                  icon: Icons.campaign_outlined,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateIcon extends StatelessWidget {
  const _EmptyStateIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
