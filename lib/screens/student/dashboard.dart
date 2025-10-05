import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/api/api_client.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
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
        _name = (me['user']?['name'] as String?) ?? 'Student';
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
      backgroundColor: const Color(0xFF121212), // Dark mode background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white, // Set the color for all icons in the AppBar
        ),
        title: Row(
          children: [
            // App logo
            Image.asset(
              "assets/images/IIITNR_Logo.png",
              height: 24,
              width: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _loading ? 'Loading...' : 'Welcome, ${_name ?? 'Student'}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Grid Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildDashboardTile(context, Icons.warning, "Complaint"),
                  _buildDashboardTile(
                      context, Icons.directions_walk, "Gatepass"),
                  _buildDashboardTile(context, Icons.shopping_cart, "Buy/Sell"),
                  _buildDashboardTile(context, Icons.contacts, "Contacts"),
                  _buildDashboardTile(context, Icons.search, "Found/Lost"),
                  _buildDashboardTile(
                      context, Icons.help_outline, "Contact\nDevelopers"),
                  _buildDashboardTile(
                      context, Icons.calendar_today, "Attendance"),
                ],
              ),
            ),

            // Announcement Card
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
                    "Happy b'day gatepass",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Can you believe it's been a year since the IIIT NR app launched? Still crashes less than our GPA but "
                    "more than our will to live. Cheers to 365 days of “please try again later”!!",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Image.asset(
                        "assets/images/Anniversary.png",
                        height: 300,
                        width: 300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTile(
      BuildContext context, IconData icon, String label) {
    return GestureDetector(
      onTap: () {
        if (label == 'Attendance') {
          context.push('/student/attendance');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFB39DDB), // Lavender tile color
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
