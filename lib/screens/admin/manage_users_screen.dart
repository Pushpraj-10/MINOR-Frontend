import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/repositories/admin_repository.dart';
import 'package:frontend/utils/error_utils.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final AdminRepository _repo = AdminRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _users = [];
  String _roleFilter = 'all';
  String _lastSearch = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _fetchUsers(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers({bool reset = false, bool loadMore = false}) async {
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
      final res = await _repo.fetchUsers(
        role: _roleFilter == 'all' ? null : _roleFilter,
        search: _lastSearch.isEmpty ? null : _lastSearch,
        page: targetPage,
        pageSize: _pageSize,
      );
      final raw = ((res['users'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        if (reset) {
          _users
            ..clear()
            ..addAll(raw);
        } else {
          _users.addAll(raw);
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
        final msg = formatError(err, fallback: 'Failed to load users');
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
    _fetchUsers(reset: true);
  }

  void _changeRole(String? role) {
    if (role == null || role == _roleFilter) return;
    setState(() => _roleFilter = role);
    _fetchUsers(reset: true);
  }

  Future<void> _openEdit(Map<String, dynamic> user) async {
    final uid = user['uid'] as String?;
    if (uid == null) return;
    final result = await context.push(
      '/admin/users/$uid/edit-role',
      extra: user,
    );
    if (result is Map<String, dynamic>) {
      final idx = _users.indexWhere((u) => u['uid'] == result['uid']);
      if (idx >= 0) {
        setState(() => _users[idx] = result);
      }
    }
  }

  Future<void> _refresh() => _fetchUsers(reset: true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        title:
            const Text('Manage Users', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: _loading && _users.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(32),
                          children: const [
                            Center(
                              child: Text(
                                'No users match your filters.',
                                style: TextStyle(color: Colors.white54),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _users.length + (_hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= _users.length) {
                              _fetchUsers(loadMore: true);
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
                            final user = _users[index];
                            return _buildUserCard(user);
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
              hintText: 'Search by name, email, uid',
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
              const Text('Role:', style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _roleFilter,
                dropdownColor: const Color(0xFF2A2A2A),
                underline: const SizedBox.shrink(),
                style: const TextStyle(color: Colors.white),
                onChanged: _changeRole,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(
                      value: 'professor', child: Text('Professor')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final name = (user['name'] as String?)?.trim();
    final email = user['email'] as String? ?? 'unknown@email';
    final role = user['role'] as String? ?? 'student';
    final uid = user['uid'] as String? ?? '';

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          name == null || name.isEmpty ? email : name,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 2),
            Text(uid,
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            Chip(
              label: Text(role.toUpperCase()),
              backgroundColor: _roleColor(role).withOpacity(0.2),
              labelStyle: TextStyle(
                  color: _roleColor(role), fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              onPressed: () => _openEdit(user),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.purpleAccent;
      case 'professor':
        return Colors.lightBlueAccent;
      default:
        return Colors.greenAccent;
    }
  }
}
