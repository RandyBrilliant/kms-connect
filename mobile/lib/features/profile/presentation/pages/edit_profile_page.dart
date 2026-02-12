import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/colors.dart';
import '../../../../config/strings.dart';
import '../../data/providers/profile_provider.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  DateTime? _selectedBirthDate;
  String? _selectedGender;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'full_name': TextEditingController(),
      'nik': TextEditingController(),
      'birth_place': TextEditingController(),
      'address': TextEditingController(),
      'contact_phone': TextEditingController(),
      'father_name': TextEditingController(),
      'father_age': TextEditingController(),
      'father_occupation': TextEditingController(),
      'mother_name': TextEditingController(),
      'mother_age': TextEditingController(),
      'mother_occupation': TextEditingController(),
      'spouse_name': TextEditingController(),
      'spouse_age': TextEditingController(),
      'spouse_occupation': TextEditingController(),
      'family_address': TextEditingController(),
      'family_contact_phone': TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.editProfile),
        actions: [
          TextButton(
            onPressed: () => _handleSave(context),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
      body: profileAsync.when(
        data: (profile) {
          _populateForm(profile);
          return _buildForm(context);
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
                onPressed: () => ref.refresh(profileProvider),
                child: const Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _populateForm(profile) {
    _controllers['full_name']!.text = profile.fullName ?? '';
    _controllers['nik']!.text = profile.nik ?? '';
    _controllers['birth_place']!.text = profile.birthPlace ?? '';
    _controllers['address']!.text = profile.address ?? '';
    _controllers['contact_phone']!.text = profile.contactPhone ?? '';
    _controllers['father_name']!.text = profile.fatherName ?? '';
    _controllers['father_age']!.text = profile.fatherAge?.toString() ?? '';
    _controllers['father_occupation']!.text = profile.fatherOccupation ?? '';
    _controllers['mother_name']!.text = profile.motherName ?? '';
    _controllers['mother_age']!.text = profile.motherAge?.toString() ?? '';
    _controllers['mother_occupation']!.text = profile.motherOccupation ?? '';
    _controllers['spouse_name']!.text = profile.spouseName ?? '';
    _controllers['spouse_age']!.text = profile.spouseAge?.toString() ?? '';
    _controllers['spouse_occupation']!.text = profile.spouseOccupation ?? '';
    _controllers['family_address']!.text = profile.familyAddress ?? '';
    _controllers['family_contact_phone']!.text = profile.familyContactPhone ?? '';
    _selectedBirthDate = profile.birthDate;
    _selectedGender = profile.gender;
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Personal Data Section
            _buildSection(
              context,
              'Data Pribadi',
              [
                TextFormField(
                  controller: _controllers['full_name'],
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['nik'],
                  decoration: const InputDecoration(
                    labelText: 'NIK *',
                    prefixIcon: Icon(Icons.badge),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'NIK wajib diisi';
                    }
                    if (value.length != 16 || !RegExp(r'^\d+$').hasMatch(value)) {
                      return 'NIK harus 16 digit angka';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['birth_place'],
                  decoration: const InputDecoration(
                    labelText: 'Tempat Lahir',
                    prefixIcon: Icon(Icons.location_city),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectBirthDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Lahir',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      _selectedBirthDate != null
                          ? DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedBirthDate!)
                          : 'Pilih tanggal',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Jenis Kelamin',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'F', child: Text('Perempuan')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['address'],
                  decoration: const InputDecoration(
                    labelText: 'Alamat *',
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Alamat wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['contact_phone'],
                  decoration: const InputDecoration(
                    labelText: 'No. HP *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'No. HP wajib diisi';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Family Data Section
            _buildSection(
              context,
              'Data Keluarga (Opsional)',
              [
                TextFormField(
                  controller: _controllers['father_name'],
                  decoration: const InputDecoration(
                    labelText: 'Nama Ayah',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['father_age'],
                  decoration: const InputDecoration(
                    labelText: 'Umur Ayah',
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['father_occupation'],
                  decoration: const InputDecoration(
                    labelText: 'Pekerjaan Ayah',
                    prefixIcon: Icon(Icons.work),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['mother_name'],
                  decoration: const InputDecoration(
                    labelText: 'Nama Ibu',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['mother_age'],
                  decoration: const InputDecoration(
                    labelText: 'Umur Ibu',
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['mother_occupation'],
                  decoration: const InputDecoration(
                    labelText: 'Pekerjaan Ibu',
                    prefixIcon: Icon(Icons.work),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['spouse_name'],
                  decoration: const InputDecoration(
                    labelText: 'Nama Suami/Istri',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['spouse_age'],
                  decoration: const InputDecoration(
                    labelText: 'Umur Suami/Istri',
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['spouse_occupation'],
                  decoration: const InputDecoration(
                    labelText: 'Pekerjaan Suami/Istri',
                    prefixIcon: Icon(Icons.work),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['family_address'],
                  decoration: const InputDecoration(
                    labelText: 'Alamat Keluarga',
                    prefixIcon: Icon(Icons.home),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _controllers['family_contact_phone'],
                  decoration: const InputDecoration(
                    labelText: 'No. HP Keluarga',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDarkGreen,
                  ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _selectBirthDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _handleSave(BuildContext context) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final data = <String, dynamic>{
      'full_name': _controllers['full_name']!.text,
      'nik': _controllers['nik']!.text,
      'birth_place': _controllers['birth_place']!.text.isEmpty ? null : _controllers['birth_place']!.text,
      'birth_date': _selectedBirthDate?.toIso8601String(),
      'address': _controllers['address']!.text,
      'contact_phone': _controllers['contact_phone']!.text,
      'gender': _selectedGender,
      'father_name': _controllers['father_name']!.text.isEmpty ? null : _controllers['father_name']!.text,
      'father_age': _controllers['father_age']!.text.isEmpty ? null : int.tryParse(_controllers['father_age']!.text),
      'father_occupation': _controllers['father_occupation']!.text.isEmpty ? null : _controllers['father_occupation']!.text,
      'mother_name': _controllers['mother_name']!.text.isEmpty ? null : _controllers['mother_name']!.text,
      'mother_age': _controllers['mother_age']!.text.isEmpty ? null : int.tryParse(_controllers['mother_age']!.text),
      'mother_occupation': _controllers['mother_occupation']!.text.isEmpty ? null : _controllers['mother_occupation']!.text,
      'spouse_name': _controllers['spouse_name']!.text.isEmpty ? null : _controllers['spouse_name']!.text,
      'spouse_age': _controllers['spouse_age']!.text.isEmpty ? null : int.tryParse(_controllers['spouse_age']!.text),
      'spouse_occupation': _controllers['spouse_occupation']!.text.isEmpty ? null : _controllers['spouse_occupation']!.text,
      'family_address': _controllers['family_address']!.text.isEmpty ? null : _controllers['family_address']!.text,
      'family_contact_phone': _controllers['family_contact_phone']!.text.isEmpty ? null : _controllers['family_contact_phone']!.text,
    };

    final notifier = ref.read(profileNotifierProvider.notifier);
    final success = await notifier.updateProfile(data);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.refresh(profileProvider);
        context.pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifier.state.error ?? 'Gagal memperbarui profil'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
