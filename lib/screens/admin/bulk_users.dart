import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:frontend/repositories/admin_repository.dart';

class BulkUsersScreen extends StatefulWidget {
  const BulkUsersScreen({super.key});

  @override
  State<BulkUsersScreen> createState() => _BulkUsersScreenState();
}

class _BulkUsersScreenState extends State<BulkUsersScreen> {
  final AdminRepository _repo = AdminRepository();

  PlatformFile? _file;
  String? _uploadId;
  List<String> _headers = [];
  List<Map<String, dynamic>> _sampleRows = [];
  Map<String, String?> _mapping = {
    'email': null,
    'uid': null,
    'password': null,
    'name': null,
    'batch': null,
    'role': null,
  };

  bool _loadingPreview = false;
  bool _loadingImport = false;
  String? _statusMessage;
  Map<String, dynamic>? _importResult;

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    setState(() {
      _file = picked;
      _uploadId = null;
      _headers = [];
      _sampleRows = [];
      _mapping.updateAll((key, value) => null);
      _importResult = null;
      _statusMessage = null;
    });
    await _fetchPreview(picked);
  }

  Map<String, String?> _autoMapHeaders(List<String> headers) {
    final lowerHeaders = headers.map((h) => h.toLowerCase()).toList();

    String? match(String key) {
      final idx = lowerHeaders.indexOf(key);
      if (idx != -1) return headers[idx];
      return null;
    }

    return {
      'email': match('email'),
      'uid':
          match('uid') ?? match('roll') ?? match('rollno') ?? match('roll_no'),
      'password': match('password') ?? match('pass') ?? match('pwd'),
      'name': match('name'),
      'batch': match('batch') ?? match('year'),
      'role': match('role'),
    };
  }

  Future<void> _fetchPreview(PlatformFile file) async {
    final lowerName = file.name.toLowerCase();
    if (!lowerName.endsWith('.csv')) {
      setState(() {
        _statusMessage = 'Please upload a .csv file (not Excel .xlsx).';
      });
      _showSnack('Please upload a .csv file (not Excel .xlsx).', error: true);
      return;
    }

    final bytes = file.bytes;
    if (bytes != null && bytes.length >= 4) {
      final isZip = bytes[0] == 0x50 &&
          bytes[1] == 0x4b &&
          bytes[2] == 0x03 &&
          bytes[3] == 0x04;
      if (isZip) {
        setState(() {
          _statusMessage =
              'File looks like an Excel workbook (.xlsx). Export/save as CSV first.';
        });
        _showSnack('File looks like Excel (.xlsx). Please export to CSV.',
            error: true);
        return;
      }
    }

    setState(() {
      _loadingPreview = true;
      _statusMessage = 'Uploading and parsing CSV...';
    });
    try {
      final res = await _repo.bulkPreviewUsers(file: file);
      final headers = List<String>.from(res['headers'] as List);
      final sample = (res['sampleRows'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final uploadId = res['uploadId'] as String;

      final mapped = _autoMapHeaders(headers);

      if (!mounted) return;
      setState(() {
        _headers = headers;
        _sampleRows = sample;
        _uploadId = uploadId;
        _mapping = {..._mapping, ...mapped};
        _statusMessage = 'Preview ready. Map columns then import.';
      });
      _showSnack('Preview ready. Map columns to import.');
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Failed to preview CSV: $err';
      });
      _showSnack('Preview failed: $err', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingPreview = false;
        });
      }
    }
  }

  bool get _hasRequiredMapping {
    return _mapping['email'] != null &&
        _mapping['uid'] != null &&
        _mapping['password'] != null;
  }

  Future<void> _importUsers() async {
    if (_uploadId == null || !_hasRequiredMapping) return;
    setState(() {
      _loadingImport = true;
      _statusMessage = 'Importing users...';
      _importResult = null;
    });
    try {
      final cleanMapping = <String, String>{};
      _mapping.forEach((key, value) {
        if (value != null && value.isNotEmpty) cleanMapping[key] = value;
      });

      final res = await _repo.bulkImportUsers(
        uploadId: _uploadId!,
        mapping: cleanMapping,
      );

      if (!mounted) return;
      setState(() {
        _importResult = res;
        _statusMessage =
            'Import finished: ${res['successCount']} success, ${res['failureCount']} failed';
      });
      _showSnack(
        'Import complete: ${res['successCount']} success, ${res['failureCount']} failed',
        error: (res['failureCount'] ?? 0) > 0,
      );
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Import failed: $err';
      });
      _showSnack('Import failed: $err', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingImport = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final darkBg = const Color(0xFF0f1d3a);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        title: const Text('Bulk Import Users',
            style: TextStyle(color: Colors.white)),
        backgroundColor: darkBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard(
              title: '1. Upload CSV',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose a CSV file and we will show a preview so you can map columns to user fields.',
                    style: TextStyle(color: Colors.white.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _loadingPreview ? null : _pickFile,
                        icon: const Icon(Icons.upload_file),
                        label:
                            Text(_file == null ? 'Select CSV' : 'Change File'),
                      ),
                      const SizedBox(width: 12),
                      if (_file != null)
                        Text(
                          _file!.name,
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                  if (_loadingPreview)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            if (_headers.isNotEmpty)
              _buildCard(
                title: '2. Map columns to fields',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Match your CSV columns to the user fields. Email, UID, and Password are required.',
                      style: TextStyle(color: Colors.white.withOpacity(0.8)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        _buildMappingDropdown('email', requiredField: true),
                        _buildMappingDropdown('uid', requiredField: true),
                        _buildMappingDropdown('password', requiredField: true),
                        _buildMappingDropdown('name'),
                        _buildMappingDropdown('batch'),
                        _buildMappingDropdown('role'),
                      ],
                    ),
                  ],
                ),
              ),
            if (_sampleRows.isNotEmpty)
              _buildCard(
                title: '3. Preview sample rows',
                child: _buildSampleTable(),
              ),
            if (_uploadId != null)
              _buildCard(
                title: '4. Import',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _hasRequiredMapping && !_loadingImport
                          ? _importUsers
                          : null,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Import Users'),
                    ),
                    if (!_hasRequiredMapping)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Email, UID, and Password must be mapped.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    if (_loadingImport)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: LinearProgressIndicator(),
                      ),
                    if (_importResult != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildImportSummary(),
                      ),
                  ],
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _statusMessage!,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMappingDropdown(String field, {bool requiredField = false}) {
    final display = field[0].toUpperCase() + field.substring(1);
    return SizedBox(
      width: 220,
      child: DropdownButtonFormField<String?>(
        value: _mapping[field],
        dropdownColor: const Color(0xFF1E1E1E),
        decoration: InputDecoration(
          iconColor: Colors.white,
          labelText: '$display ${requiredField ? "*" : ""}',
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Color(0xFFB39DDB)),
          ),
        ),
        items: [
          if (!requiredField)
            const DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Not mapped',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ..._headers.map(
            (h) => DropdownMenuItem<String?>(
              value: h,
              child: Text(
                h,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
        onChanged: (val) {
          setState(() {
            _mapping[field] = val;
          });
        },
      ),
    );
  }

  Widget _buildSampleTable() {
    final displayHeaders = _headers.take(6).toList();
    final rows = _sampleRows.take(5).toList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: displayHeaders
            .map((h) => DataColumn(
                  label: Text(
                    h,
                    style: const TextStyle(color: Colors.white),
                  ),
                ))
            .toList(),
        rows: rows
            .map(
              (r) => DataRow(
                cells: displayHeaders
                    .map(
                      (h) => DataCell(
                        Text(
                          '${r[h] ?? ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildImportSummary() {
    if (_importResult == null) return const SizedBox.shrink();
    final success = _importResult!['successCount'];
    final failed = _importResult!['failureCount'];
    final errors = (_importResult!['errors'] as List?) ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Result: $success succeeded, $failed failed',
          style: const TextStyle(color: Colors.white70),
        ),
        if (errors.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: errors.take(5).map((e) {
                final row = e['row'];
                final error = e['error'];
                return Text(
                  'Row ${row ?? ''}: $error',
                  style: const TextStyle(color: Colors.redAccent),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
