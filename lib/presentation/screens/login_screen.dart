import 'package:flutter/material.dart';
import '../../core/di.dart';
import '../../data/remote/appwrite_service.dart';
import '../widgets/buttons.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final service = getIt<AppwriteService>();
    final session = await service.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );
    if (session == null) {
      setState(() {
        _error = 'Login failed';
        _isLoading = false;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            FullWidthButton.primary(
              label: _isLoading ? 'Please wait...' : 'Login',
              onPressed: _isLoading ? null : _login,
            ),
          ],
        ),
      ),
    );
  }
}
