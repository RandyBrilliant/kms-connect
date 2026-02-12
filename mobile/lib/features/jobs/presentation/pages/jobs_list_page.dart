import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../../home/presentation/widgets/bottom_nav_bar.dart';
import '../../data/providers/job_provider.dart';

class JobsListPage extends ConsumerStatefulWidget {
  const JobsListPage({super.key});

  @override
  ConsumerState<JobsListPage> createState() => _JobsListPageState();
}

class _JobsListPageState extends ConsumerState<JobsListPage> {
  final _searchController = TextEditingController();
  String? _selectedEmploymentType;
  String? _selectedLocation;
  JobFilters? _cachedFilters;

  JobFilters _getFilters() {
    final search = _searchController.text.isEmpty ? null : _searchController.text;
    final filters = JobFilters(
      search: search,
      employmentType: _selectedEmploymentType,
      locationCountry: _selectedLocation,
    );
    
    // Only update cached filters if values actually changed
    if (_cachedFilters == null ||
        _cachedFilters!.search != filters.search ||
        _cachedFilters!.employmentType != filters.employmentType ||
        _cachedFilters!.locationCountry != filters.locationCountry) {
      _cachedFilters = filters;
    }
    
    return _cachedFilters!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filters = _getFilters();
    final jobsAsyncValue = ref.watch(jobsProvider(filters));

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.jobs),
        actions: [
          IconButton(
            icon: const Icon(Icons.assignment),
            onPressed: () {
              context.push('/jobs/my-applications');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppStrings.search,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedEmploymentType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Jenis Kerja',
                          prefixIcon: Icon(Icons.work_outline),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Semua')),
                          DropdownMenuItem(value: 'FULL_TIME', child: Text('Penuh Waktu')),
                          DropdownMenuItem(value: 'PART_TIME', child: Text('Paruh Waktu')),
                          DropdownMenuItem(value: 'CONTRACT', child: Text('Kontrak')),
                          DropdownMenuItem(value: 'INTERNSHIP', child: Text('Magang')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedEmploymentType = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Negara',
                          prefixIcon: Icon(Icons.location_on),
                          isDense: true,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedLocation = value.isEmpty ? null : value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Jobs List
          Expanded(
            child: jobsAsyncValue.when(
              data: (jobs) {
                if (jobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.work_off, size: 64, color: AppColors.textLight),
                        const SizedBox(height: 16),
                        Text(
                          AppStrings.noData,
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
                    ref.invalidate(jobsProvider(filters));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: jobs.length,
                    itemBuilder: (context, index) {
                      final job = jobs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            job.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.business, size: 16),
                                  const SizedBox(width: 4),
                                  Text(job.companyName),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16),
                                  const SizedBox(width: 4),
                                  Text(job.locationDisplay),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.work, size: 16),
                                  const SizedBox(width: 4),
                                  Text(job.employmentTypeDisplay),
                                ],
                              ),
                              if (job.salaryMin != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.attach_money, size: 16),
                                    const SizedBox(width: 4),
                                    Text(job.salaryDisplay),
                                  ],
                                ),
                              ],
                              if (job.deadline != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Deadline: ${DateFormat('dd MMM yyyy', 'id_ID').format(job.deadline!)}',
                                      style: TextStyle(
                                        color: job.deadline!.isBefore(DateTime.now())
                                            ? AppColors.error
                                            : AppColors.textMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            context.push('/jobs/${job.id}');
                          },
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
                      onPressed: () => ref.invalidate(jobsProvider(filters)),
                      child: const Text(AppStrings.retry),
                    ),
                  ],
                ),
              ),
            ),
          ),
          BottomNavBar(currentRoute: '/jobs'),
        ],
      ),
    );
  }
}
