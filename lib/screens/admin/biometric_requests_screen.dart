import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:frontend/repositories/admin_repository.dart';
import 'package:frontend/utils/error_utils.dart';

class BiometricRequestsScreen extends StatefulWidget {
  const BiometricRequestsScreen({super.key});

  @override
  State<BiometricRequestsScreen> createState() =>
      _BiometricRequestsScreenState();
}

class _BiometricRequestsScreenState extends State<BiometricRequestsScreen> {
  final AdminRepository _repo = AdminRepository();
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _requests = [];

  final DateFormat _dateFormat = DateFormat('MMM d, HH:mm');
  static const int _pageSize = 20;

  String _statusFilter = 'pending';
  String _lastSearch = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _approvingUserId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchRequests(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests(
      {bool reset = false, bool loadMore = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _hasMore = true;
        _page = 1;
      });
    } else if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() => _loading = true);
    }

    final targetPage = reset ? 1 : (_page + 1);

    try {
      final res = await _repo.fetchBiometricRequests(
        status: _statusFilter == 'all' ? null : _statusFilter,
        search: _lastSearch.isEmpty ? null : _lastSearch,
        page: targetPage,
        pageSize: _pageSize,
      );
      final raw = ((res['requests'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        if (reset) {
          _requests
            ..clear()
            ..addAll(raw);
        } else {
          _requests.addAll(raw);
        }
        _page = targetPage;
        final total = (res['total'] as num?)?.toInt() ?? 0;
        final currentPage = (res['page'] as num?)?.toInt() ?? targetPage;
        final serverPageSize = (res['pageSize'] as num?)?.toInt() ?? _pageSize;
        if (total <= 0) {
          _hasMore = raw.length >= serverPageSize;
        } else {
          _hasMore = currentPage * serverPageSize < total;
        }
      });
    } catch (err) {
      if (mounted) {
        final msg = formatError(err, fallback: 'Failed to load requests');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _applySearch() {
    _lastSearch = _searchController.text.trim();
    _fetchRequests(reset: true);
  }

  void _changeStatus(String? status) {
    if (status == null || status == _statusFilter) return;
    setState(() => _statusFilter = status);
    _fetchRequests(reset: true);
  }

  Future<void> _approve(String userId) async {
    setState(() => _approvingUserId = userId);
    try {
      await _repo.approveBiometric(userId);
      final idx = _requests.indexWhere((r) => r['userId'] == userId);
      if (idx >= 0) {
        setState(() {
          _requests[idx] = {
            ..._requests[idx],
            'status': 'approved',
            'pendingPublicKeyHash': null,
            'pendingCreatedAt': null,
          };
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric key approved')),
        );
      }
    } catch (err) {
      if (mounted) {
        final msg = formatError(err, fallback: 'Approval failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _approvingUserId = null);
    }
  }

  Future<void> _refresh() => _fetchRequests(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        title: const Text('Biometric Requests',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _loading && _requests.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _requests.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: const [
                            Center(
                              child: Text(
                                'No biometric requests found.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _requests.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _requests.length) {
                              _fetchRequests(loadMore: true);
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _loadingMore
                                      ? const CircularProgressIndicator()
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }
                            final request = _requests[index];
                            return _buildRequestCard(request);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search by user, email, hash',
              hintStyle: const TextStyle(color: Colors.white54),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              suffixIcon: _searchController.text.isEmpty
                  ? IconButton(
                      icon: const Icon(Icons.search, color: Colors.white54),
                      onPressed: _applySearch,
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54),
                      onPressed: () {
                        _searchController.clear();
                        _applySearch();
                      },
                    ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.white38),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.blue),
              ),
            ),
            onSubmitted: (_) => _applySearch(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Status:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                dropdownColor: const Color(0xFF2A2A2A),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white),
                onChanged: _changeStatus,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'approved', child: Text('Approved')),
                  DropdownMenuItem(value: 'revoked', child: Text('Revoked')),
                  DropdownMenuItem(value: 'all', child: Text('All')),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final user = request['user'] is Map
        ? Map<String, dynamic>.from(request['user'] as Map)
        : <String, dynamic>{};
    final name = (user['name'] as String?)?.trim();
    final email = user['email'] as String? ?? 'unknown@email';
    final status = request['status'] as String? ?? 'pending';
    final pendingHash = request['pendingPublicKeyHash'] as String?;
    final activeHash = request['publicKeyHash'] as String?;
    final submitted = request['pendingCreatedAt'] as String? ??
        request['updatedAt'] as String?;
    final userId = request['userId'] as String? ?? '';

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name == null || name.isEmpty ? email : name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(email,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 4),
                      Text(userId,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Chip(
                  label: Text(status.toUpperCase()),
                  backgroundColor: _statusColor(status).withOpacity(0.2),
                  labelStyle: TextStyle(
                      color: _statusColor(status), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingHash != null)
              Text('Pending hash: ${_hashPreview(pendingHash)}',
                  style: const TextStyle(color: Colors.white70)),
            if (activeHash != null &&
                (pendingHash == null || pendingHash != activeHash))
              Text('Active hash: ${_hashPreview(activeHash)}',
                  style: const TextStyle(color: Colors.white38)),
            const SizedBox(height: 8),
            Text('Updated: ${_formatDate(submitted)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
            if (status == 'pending') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _approvingUserId == userId
                      ? null
                      : () => _approve(userId),
                  icon: _approvingUserId == userId
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB39DDB),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'revoked':
        return Colors.redAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  String _formatDate(String? value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value);
    if (dt == null) return value;
    return _dateFormat.format(dt.toLocal());
  }

  String _hashPreview(String hash) {
    if (hash.length <= 16) return hash;
    return '${hash.substring(0, 16)}…';
  }
}
