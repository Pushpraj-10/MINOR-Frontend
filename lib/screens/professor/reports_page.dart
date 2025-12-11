import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/api/api_client.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

class ProfessorReportsPage extends StatefulWidget {
  const ProfessorReportsPage({Key? key}) : super(key: key);

  @override
  State<ProfessorReportsPage> createState() => _ProfessorReportsPageState();
}

class _ProfessorReportsPageState extends State<ProfessorReportsPage> {
  DateTime _selectedMonth = DateTime.now();
  bool _isLoading = false;
  List<List<String>> _rows = [];

  String get monthParam => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int tempYear = _selectedMonth.year;
    int tempMonth = _selectedMonth.month;
    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Text('Select Month',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: 12,
                        itemBuilder: (ctx, i) {
                          final month = i + 1;
                          final selected = month == tempMonth;
                          return ListTile(
                            dense: true,
                            title: Text(
                              DateFormat('MMMM')
                                  .format(DateTime(2000, month, 1)),
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              tempMonth = month;
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: 4,
                        itemBuilder: (ctx, i) {
                          final year = now.year - 3 + i;
                          final selected = year == tempYear;
                          return ListTile(
                            dense: true,
                            title: Text(
                              '$year',
                              style: TextStyle(
                                color: selected ? Colors.white : Colors.white70,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            onTap: () {
                              tempYear = year;
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDCC8FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedMonth = DateTime(tempYear, tempMonth, 1);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Apply',
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchCsv() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _rows = [];
    });
    try {
      final csv =
          await ApiClient.I.getCsv('/admin/reports/monthly/professor', query: {
        'month': monthParam,
      });
      if (!mounted) return;
      setState(() {
        _rows = _parseCsv(csv);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<List<String>> _parseCsv(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final rows = lines.map((l) => l.split(',')).toList();
    if (rows.isEmpty)
      return [
        ['student_name', 'days_present', 'days_absent']
      ];
    final header = rows.first;
    if (header.length < 3) {
      rows[0] = ['student_name', 'days_present', 'days_absent'];
    }
    return rows.map((r) {
      final a = List<String>.from(r);
      while (a.length < 3) {
        a.add('');
      }
      return a.take(3).toList();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Monthly Reports',
            style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _fetchCsv,
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: 'Download CSV',
            onPressed: (_rows.isEmpty || _isLoading) ? null : _downloadCsv,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_rows.isEmpty || _rows.length == 1)
                    ? const Center(
                        child: Text('No data loaded',
                            style: TextStyle(color: Colors.white70)),
                      )
                    : _buildTable(),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadCsv() async {
    try {
      // Rebuild CSV from rows for simplicity
      final csv = _rows.map((r) => r.join(',')).join('\n');
      // Prefer the public Downloads folder where possible
      Directory? targetDir;
      if (Platform.isAndroid) {
        final androidDownloads = Directory('/storage/emulated/0/Download');
        if (await androidDownloads.exists()) {
          targetDir = androidDownloads;
        }
      }
      // Desktop platforms support getDownloadsDirectory()
      targetDir ??= await getDownloadsDirectory();
      // Fallback to app-specific storage
      targetDir ??= (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
      final fileName = 'monthly_report_${monthParam}.csv';
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(utf8.encode(csv), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickMonth,
                  child: SizedBox(
                    height: 48,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A282C),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              color: Colors.white70),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              DateFormat('MMMM yyyy').format(_selectedMonth),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDCC8FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isLoading ? null : _fetchCsv,
                    child: const Text('Generate',
                        style: TextStyle(color: Colors.black)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final header = _rows.first;
    final data = _rows.skip(1).toList();
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildRow(header, isHeader: true);
        }
        return _buildRow(data[index - 1]);
      },
    );
  }

  Widget _buildRow(List<String> cols, {bool isHeader = false}) {
    final bg = isHeader ? const Color(0xFF2A282C) : const Color(0xFF1E1E1E);
    final fw = isHeader ? FontWeight.bold : FontWeight.normal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(cols.elementAt(0),
                style: TextStyle(color: Colors.white, fontWeight: fw)),
          ),
          Expanded(
            child: Text(cols.elementAt(1),
                style: TextStyle(color: Colors.white70, fontWeight: fw)),
          ),
          Expanded(
            child: Text(cols.elementAt(2),
                style: TextStyle(color: Colors.white70, fontWeight: fw)),
          ),
        ],
      ),
    );
  }
}
