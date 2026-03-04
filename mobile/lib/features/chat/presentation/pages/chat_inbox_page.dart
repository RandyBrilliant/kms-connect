import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../data/providers/chat_provider.dart';
import '../../domain/models/chat_thread_preview.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';

/// Applicant chat inbox — shows all conversation threads.
///
/// Each thread corresponds to a job application. Tapping a row opens the
/// [ChatThreadPage] for that application.
class ChatInboxPage extends ConsumerStatefulWidget {
  const ChatInboxPage({super.key});

  @override
  ConsumerState<ChatInboxPage> createState() => _ChatInboxPageState();
}

class _ChatInboxPageState extends ConsumerState<ChatInboxPage> {
  @override
  void initState() {
    super.initState();
    // Always refresh inbox data when the page opens so threads created
    // after the initial provider load (e.g. new job application) appear.
    Future.microtask(() => ref.read(chatInboxProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatInboxProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Pesan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
        elevation: 0,
        // Unread badge in title area
        actions: [
          if (state.totalUnread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _Badge(count: state.totalUnread),
              ),
            ),
        ],
      ),
      body: _Body(state: state),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/chat'),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — delegates to the appropriate state view
// ---------------------------------------------------------------------------

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final ChatInboxState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.threads.isEmpty) {
      return const _LoadingSkeleton();
    }

    if (state.error != null && state.threads.isEmpty) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(chatInboxProvider.notifier).load(),
      );
    }

    if (state.threads.isEmpty) {
      return const _EmptyView();
    }

    return RefreshIndicator(
      color: AppColors.primaryDarkGreen,
      onRefresh: () => ref.read(chatInboxProvider.notifier).load(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: state.threads.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          return _ThreadTile(thread: state.threads[index]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Thread tile
// ---------------------------------------------------------------------------

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});

  final ChatThreadPreview thread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasUnread = thread.unreadCount > 0;

    return InkWell(
      onTap: () => context.push(
        '/jobs/applications/${thread.applicationId}/chat',
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar ────────────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.secondaryLightGreen,
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primaryDarkGreen,
                    size: 26,
                  ),
                ),
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: _Badge(count: thread.unreadCount),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // ── Main content ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job title + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          thread.jobTitle.isEmpty
                              ? 'Lamaran #${thread.applicationId}'
                              : thread.jobTitle,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: hasUnread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: cs.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(thread.updatedAt),
                        style: tt.labelSmall?.copyWith(
                          color: hasUnread
                              ? AppColors.primaryDarkGreen
                              : cs.onSurfaceVariant,
                          fontWeight: hasUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message preview + closed tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _LastMessagePreview(
                          lastMessage: thread.lastMessage,
                          hasUnread: hasUnread,
                        ),
                      ),
                      if (thread.isClosed) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Ditutup',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a human-readable relative time string.
  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 365) {
      return DateFormat('d MMM yy', 'id_ID').format(dt);
    }
    if (diff.inDays >= 7) {
      return DateFormat('d MMM', 'id_ID').format(dt);
    }
    if (diff.inDays >= 1) return '${diff.inDays}h';
    if (diff.inHours >= 1) return '${diff.inHours}j';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'Baru';
  }
}

// ---------------------------------------------------------------------------
// Last message preview row
// ---------------------------------------------------------------------------

class _LastMessagePreview extends StatelessWidget {
  const _LastMessagePreview({
    required this.lastMessage,
    required this.hasUnread,
  });

  final ChatLastMessage? lastMessage;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (lastMessage == null) {
      return Text(
        'Belum ada pesan',
        style: tt.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // Show "Anda: ..." for messages sent by the applicant themselves
    final isOwnMessage = lastMessage!.senderRole == 'APPLICANT';
    final prefix = isOwnMessage ? 'Anda: ' : '';

    return Text(
      '$prefix${lastMessage!.body}',
      style: tt.bodySmall?.copyWith(
        color: hasUnread ? cs.onSurface : cs.onSurfaceVariant,
        fontWeight:
            hasUnread ? FontWeight.w500 : FontWeight.normal,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ---------------------------------------------------------------------------
// Unread count badge
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: const BoxDecoration(
        color: AppColors.primaryDarkGreen,
        borderRadius: BorderRadius.all(Radius.circular(9)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading skeleton (placeholder while fetching)
// ---------------------------------------------------------------------------

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, _) => const _SkeletonTile(),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shimmerColor = cs.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar placeholder
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: shimmerColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 160,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: shimmerColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 72,
              color: cs.onSurfaceVariant.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada pesan',
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pesan dari admin terkait lamaranmu\nakan muncul di sini.',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat pesan',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryDarkGreen,
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
