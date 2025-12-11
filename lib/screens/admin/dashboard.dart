import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  String? _name;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final me = await ApiClient.I.me();
      if (!mounted) return;
      setState(() {
        _name = (me['user']?['name'] as String?) ?? 'Admin';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await ApiClient.I.logout();
    } finally {
      if (!mounted) return;
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Image.asset('assets/images/IIITNR_Logo.png', height: 24, width: 24),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Loading...' : 'Welcome, ${_name ?? 'Admin'}',
              style: const TextStyle(fontSize: 16, color: Colors.white),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'logout') _logout();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildTile(context, Icons.people, 'Users'),
                    _buildTile(context, Icons.event_available, 'Sessions'),
                    _buildTile(context, Icons.list_alt, 'Reports',
                        route: '/admin/reports'),
                    _buildTile(context, Icons.settings, 'Settings'),
                    _buildTile(context, Icons.security, 'Roles'),
                    _buildTile(context, Icons.analytics, 'Logs'),
                    _buildTile(context, Icons.manage_accounts, 'Manage User',
                        route: '/admin/manage-users'),
                    _buildTile(context, Icons.fingerprint,
                        'Manage Biometrics Requests',
                        route: '/admin/biometric-requests'),
                    _buildTile(context, Icons.cloud_upload, 'Bulk Import Users',
                        route: '/admin/bulk-users'),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Panel',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the tiles above to manage users, sessions and biometric approval requests.',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String label,
      {String? route}) {
    return GestureDetector(
      onTap: () {
        if (route != null) context.push(route);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFB39DDB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
