import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../data/providers/job_provider.dart';
import '../../domain/models/job_application.dart';

// Status filter options shown as horizontal chips
const _kStatuses = <(String, String)>[
  ('', 'Semua'),
  ('APPLIED', 'Dilamar'),
  ('UNDER_REVIEW', 'Dalam Review'),
  ('SHORTLISTED', 'Shortlist'),
  ('OFFERED', 'Ditawarkan'),
  ('OFFER_ACCEPTED', 'Tawaran Diterima'),
  ('OFFER_DECLINED', 'Tawaran Ditolak'),
  ('PLACED', 'Ditempatkan'),
  ('COMPLETED', 'Selesai'),
  ('REJECTED', 'Ditolak'),
  ('WITHDRAWN', 'Dicabut'),
];

class MyApplicationsPage extends ConsumerStatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  ConsumerState<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends ConsumerState<MyApplicationsPage> {
  String _selectedStatus = '';

  @override
  Widget build(BuildContext context) {
    final status = _selectedStatus.isEmpty ? null : _selectedStatus;
    final applicationsAsync = ref.watch(myApplicationsProvider(status));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text(AppStrings.myApplications),
        backgroundColor: AppColors.primaryDarkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Status filter chips ────────────────────────────────────
          Container(
            color: cs.surface,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _kStatuses.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final (value, label) = _kStatuses[i];
                  final isSelected = _selectedStatus == value;
                  return FilterChip(
                    label: Text(label),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedStatus = value),
                    backgroundColor: cs.surfaceContainerHighest,
                    selectedColor:
                        AppColors.primaryDarkGreen.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primaryDarkGreen,
                    labelStyle: tt.labelMedium?.copyWith(
                      color: isSelected
                          ? AppColors.primaryDarkGreen
                          : cs.onSurfaceVariant,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primaryDarkGreen
                          : Colors.transparent,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // ── List ───────────────────────────────────────────────────
          Expanded(
            child: applicationsAsync.when(
              data: (applications) {
                if (applications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 64,
                            color: cs.onSurfaceVariant
                                .withValues(alpha: 0.35)),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada lamaran',
                          style: tt.titleMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lamar lowongan dari halaman Lowongan Kerja',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(myApplicationsProvider(status).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: applications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _ApplicationCard(
                        application: applications[index],
                        onTap: () => context.push(
                          '/jobs/applications/${applications[index].id}',
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('$error',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(myApplicationsProvider(status)),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(AppStrings.retry),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryDarkGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Application Card
// ─────────────────────────────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    required this.application,
    required this.onTap,
  });

  final JobApplication application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ───────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.jobTitle ?? 'Lowongan',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (application.companyName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            application.companyName!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(status: application.status),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant, height: 1),
              const SizedBox(height: 10),

              // ── Meta row ─────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy', 'id_ID')
                        .format(application.appliedAt),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    application.source == 'ADMIN_ASSIGN'
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline_rounded,
                    size: 13,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    application.sourceDisplay,
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final app = JobApplication(
      id: 0,
      applicant: 0,
      job: 0,
      status: status,
      appliedAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final color = app.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        app.statusDisplay,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

