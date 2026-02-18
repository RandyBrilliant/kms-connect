import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../data/providers/job_provider.dart';

class MyApplicationsPage extends ConsumerStatefulWidget {
  const MyApplicationsPage({super.key});

  @override
  ConsumerState<MyApplicationsPage> createState() => _MyApplicationsPageState();
}

class _MyApplicationsPageState extends ConsumerState<MyApplicationsPage> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final applicationsAsync = ref.watch(myApplicationsProvider(_selectedStatus));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myApplications),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter Status',
                prefixIcon: Icon(Icons.filter_list),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Semua')),
                DropdownMenuItem(value: 'APPLIED', child: Text('Dilamar')),
                DropdownMenuItem(value: 'UNDER_REVIEW', child: Text('Dalam Review')),
                DropdownMenuItem(value: 'ACCEPTED', child: Text('Diterima')),
                DropdownMenuItem(value: 'REJECTED', child: Text('Ditolak')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ),
          Expanded(
            child: applicationsAsync.when(
              data: (applications) {
                if (applications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.assignment_outlined, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          'Belum ada lamaran',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textMedium,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.refresh(myApplicationsProvider(_selectedStatus));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: applications.length,
                    itemBuilder: (context, index) {
                      final application = applications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            application.jobTitle ?? 'Lowongan',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              if (application.companyName != null)
                                Text('Perusahaan: ${application.companyName}'),
                              const SizedBox(height: 4),
                              Text(
                                'Status: ${application.statusDisplay}',
                                style: TextStyle(
                                  color: _getStatusColor(application.status),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Dilamar: ${DateFormat('dd MMM yyyy', 'id_ID').format(application.appliedAt)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (application.notes != null && application.notes!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundOffWhite,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    application.notes!,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.refresh(myApplicationsProvider(_selectedStatus)),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'APPLIED':
        return AppColors.info;
      case 'UNDER_REVIEW':
        return AppColors.warning;
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
        return AppColors.error;
      default:
        return AppColors.textMedium;
    }
  }
}
