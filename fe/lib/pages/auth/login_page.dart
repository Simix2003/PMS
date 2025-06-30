import 'package:flutter/material.dart';

import '../dashboard/dashboard_data.dart';
import '../dashboard/dashboard_home.dart';
import '../dashboard/dashboard_stringatrice.dart';

class LoginPage extends StatefulWidget {
  final String targetPage;

  const LoginPage({super.key, required this.targetPage});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  void _handleLogin() {
    // TODO: Validate credentials here if needed
    if (widget.targetPage == 'Home') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardHome()),
      );
    } else if (widget.targetPage == 'Data') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardData()),
      );
    } else if (widget.targetPage == 'Stringatrice') {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardStringatrice()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Accesso richiesto',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Effettua il login per accedere a: ${widget.targetPage}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('Entra'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
