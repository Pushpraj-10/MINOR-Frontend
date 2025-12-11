import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/api/api_client.dart';

class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({Key? key}) : super(key: key);

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  DateTime _selectedMonth = DateTime.now();
  final TextEditingController _batchCtrl = TextEditingController();
  bool _isLoading = false;
  String? _csv;
  List<List<String>> _rows = [];

  @override
  void dispose() {
    _batchCtrl.dispose();
    super.dispose();
  }

  String get monthParam => DateFormat('yyyy-MM').format(_selectedMonth);

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 3, 1),
      lastDate: DateTime(now.year, now.month, 28),
      helpText: 'Select Any Day In Month',
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF0f1d3a),
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  Future<void> _fetchCsv() async {
    setState(() {
      _isLoading = true;
      _csv = null;
      _rows = [];
    });
    try {
      final params = {
        'month': monthParam,
        if (_batchCtrl.text.trim().isNotEmpty) 'batch': _batchCtrl.text.trim(),
      };
      final res =
          await ApiClient.I.getCsv('/admin/reports/monthly', query: params);
      setState(() {
        _csv = res;
        _rows = _parseCsv(res);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load report: $e')),
      );
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  List<List<String>> _parseCsv(String csv) {
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    return lines.map((l) => l.split(',')).toList();
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
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rows.isEmpty
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
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _pickMonth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A282C),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _batchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Batch (optional) e.g. CSE 2024',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: const Color(0xFF2A282C),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDCC8FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _isLoading ? null : _fetchCsv,
              child: const Text('Generate Report',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable() {
    final header = _rows.first;
    final data = _rows.skip(1).toList();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length + 1,
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
