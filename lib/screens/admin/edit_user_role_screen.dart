import 'package:flutter/material.dart';
import 'package:frontend/repositories/admin_repository.dart';
import 'package:frontend/utils/error_utils.dart';

class EditUserRoleScreen extends StatefulWidget {
  final String uid;
  final dynamic initialUser;

  const EditUserRoleScreen({super.key, required this.uid, this.initialUser});

  @override
  State<EditUserRoleScreen> createState() => _EditUserRoleScreenState();
}

class _EditUserRoleScreenState extends State<EditUserRoleScreen> {
  final AdminRepository _repo = AdminRepository();
  final List<String> _roles = const ['student', 'professor', 'admin'];

  String _role = 'student';
  String? _name;
  String? _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = _coerceMap(widget.initialUser);
    _role = initial?['role'] as String? ?? 'student';
    _name = initial?['name'] as String?;
    _email = initial?['email'] as String?;
  }

  Map<String, dynamic>? _coerceMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data as Map);
    return null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final res = await _repo.updateUserRole(uid: widget.uid, role: _role);
      final updated = Map<String, dynamic>.from(res['user'] as Map);
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (err) {
      if (mounted) {
        final msg = formatError(err, fallback: 'Failed to update role');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f1d3a),
        title:
            const Text('Edit User Role', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 20),
            const Text('Select Role', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _roles
                  .map(
                    (role) => ChoiceChip(
                      backgroundColor: const Color.fromARGB(255, 47, 47, 47),
                      label: Text(role.toUpperCase()),
                      selected: _role == role,
                      selectedColor: Colors.blueAccent,
                      onSelected: (_) => setState(() => _role = role),
                      labelStyle: TextStyle(
                        color: _role == role ? const Color.fromARGB(255, 46, 46, 46) : const Color.fromARGB(179, 183, 183, 183),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFB39DDB),
                  foregroundColor: Colors.black,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _name?.isNotEmpty == true ? _name! : 'Unknown user',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(_email ?? 'No email',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Text('UID: ${widget.uid}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
