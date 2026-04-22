import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../data/providers/notification_provider.dart';
import '../../domain/models/app_notification.dart';

/// Full-screen view of a single notification (title, body, metadata, optional action).
class NotificationDetailPage extends ConsumerStatefulWidget {
  const NotificationDetailPage({super.key, required this.notificationId});

  final int notificationId;

  @override
  ConsumerState<NotificationDetailPage> createState() =>
      _NotificationDetailPageState();
}

class _NotificationDetailPageState extends ConsumerState<NotificationDetailPage> {
  AppNotification? _notification;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (widget.notificationId <= 0) {
      setState(() {
        _loading = false;
        _error = 'Notifikasi tidak valid';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final repo = ref.read(notificationRepositoryProvider);
    try {
      var n = await repo.getNotification(widget.notificationId);
      if (!mounted) return;
      if (!n.isRead) {
        await ref.read(notificationProvider.notifier).markRead(n.id);
        n = n.copyWith(isRead: true);
      }
      if (!mounted) return;
      setState(() {
        _notification = n;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('DioException: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFB),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DetailHeader(
            topPad: topPad,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/notifications');
              }
            },
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDarkGreen,
                    ),
                  )
                : _error != null
                    ? _ErrorBody(message: _error!, onRetry: _load)
                    : _notification == null
                        ? _ErrorBody(
                            message: 'Notifikasi tidak ditemukan',
                            onRetry: _load,
                          )
                        : _DetailBody(
                            notification: _notification!,
                            textTheme: tt,
                          ),
          ),
        ],
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.topPad, required this.onBack});

  final double topPad;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 16, 20, 20),
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
      child: Row(
        children: [
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
          Expanded(
            child: Text(
              'Detail notifikasi',
              style: tt.headlineSmall?.copyWith(
                color: AppColors.textDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.notification,
    required this.textTheme,
  });

  final AppNotification notification;
  final TextTheme textTheme;

  static const _typeConfig = {
    'SYSTEM': (Color(0xFF3B82F6), Icons.settings_rounded),
    'JOB': (AppColors.primaryDarkGreen, Icons.work_outline_rounded),
    'APPLICATION': (Color(0xFF0891B2), Icons.description_outlined),
    'DOCUMENT': (Color(0xFFF59E0B), Icons.folder_open_outlined),
    'PROFILE': (Color(0xFF8B5CF6), Icons.person_outline_rounded),
    'BROADCAST': (Color(0xFFEF4444), Icons.campaign_outlined),
    'INFO': (Color(0xFF06B6D4), Icons.info_outline_rounded),
  };

  String _typeLabel(String? type) {
    switch (type) {
      case 'SYSTEM':
        return 'Sistem';
      case 'JOB':
        return 'Lowongan';
      case 'APPLICATION':
        return 'Lamaran';
      case 'DOCUMENT':
        return 'Dokumen';
      case 'PROFILE':
        return 'Profil';
      case 'BROADCAST':
        return 'Pengumuman';
      case 'INFO':
        return 'Info';
      default:
        return 'Umum';
    }
  }

  String _formattedTime(DateTime dt) {
    return DateFormat("EEEE, d MMM yyyy · HH:mm", 'id').format(dt);
  }

  void _openActionIfPossible(BuildContext context) {
    final url = notification.actionUrl;
    if (url == null || url.isEmpty) return;
    final router = GoRouter.of(context);
    final u = url.trim();
    final parsed = Uri.tryParse(u);
    final path = parsed?.path.isNotEmpty == true ? parsed!.path : u;

    if (path.contains('/profil') || path == '/profile') {
      router.push('/profile');
      return;
    }
    if (path.contains('/dokumen') || path.contains('documents')) {
      router.push('/documents');
      return;
    }
    if (path.contains('my-applications')) {
      router.push('/jobs/my-applications');
      return;
    }
    final chatMatch = RegExp(r'/applications/(\d+)/chat').firstMatch(path);
    if (chatMatch != null) {
      final id = int.tryParse(chatMatch.group(1) ?? '');
      if (id != null && id > 0) {
        router.push('/jobs/applications/$id/chat');
        return;
      }
    }
    final appDetailMatch = RegExp(r'/(?:lamaran|applications)/(\d+)').firstMatch(path);
    if (appDetailMatch != null) {
      final id = int.tryParse(appDetailMatch.group(1) ?? '');
      if (id != null && id > 0) {
        router.push('/jobs/applications/$id');
        return;
      }
    }
    final jobMatch = RegExp(r'/(?:lowongan|jobs)/(\d+)').firstMatch(path);
    if (jobMatch != null) {
      final id = int.tryParse(jobMatch.group(1) ?? '');
      if (id != null && id > 0) {
        router.push('/jobs/$id');
        return;
      }
    }
    final batchAnnouncementsMatch =
        RegExp(r'/batch/\d+/announcements/?$').firstMatch(path);
    final batchMatch = RegExp(r'/batch/\d+/?$').firstMatch(path);
    if (batchAnnouncementsMatch != null || batchMatch != null) {
      // Applicant does not have a direct batch-detail route; announcements are shown
      // in each application detail page.
      router.push('/jobs/my-applications');
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _typeConfig[notification.notificationType] ??
        _typeConfig['SYSTEM']!;
    final (Color accent, IconData icon) = cfg;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _typeLabel(notification.notificationType),
                        style: textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      notification.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formattedTime(notification.createdAt),
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (notification.isRead) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.visibility_outlined,
                  size: 16,
                  color: AppColors.textLight,
                ),
                const SizedBox(width: 6),
                Text(
                  'Sudah dibaca',
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SelectableText(
              notification.message,
              style: textTheme.bodyLarge?.copyWith(
                color: AppColors.textDark,
                height: 1.55,
              ),
            ),
          ),
          if (notification.actionLabel != null &&
              notification.actionLabel!.isNotEmpty &&
              notification.actionUrl != null &&
              notification.actionUrl!.isNotEmpty) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _openActionIfPossible(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDarkGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: Text(
                  notification.actionLabel!,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: AppColors.textMedium),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
              ),
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
