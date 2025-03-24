import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  String? _currentIP;
  String? _currentPort;

  @override
  void initState() {
    super.initState();
    _loadSavedConfig();
  }

  Future<void> _loadSavedConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('backend_ip');
    final port = prefs.getString('backend_port');
    setState(() {
      _currentIP = ip ?? '172.16.176.235';
      _currentPort = port ?? '8000';
      _ipController.text = ip ?? '';
      _portController.text = port ?? '';
    });
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_ip', _ipController.text.trim());
    await prefs.setString('backend_port', _portController.text.trim());
    setState(() {
      _currentIP = _ipController.text.trim();
      _currentPort = _portController.text.trim();
    });
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('IP & Port saved successfully!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Config:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'IP: ${_currentIP ?? 'Loading...'}',
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            Text(
              'Port: ${_currentPort ?? 'Loading...'}',
              style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter Backend IP',
                hintText: 'e.g. 192.168.0.10',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter Backend Port',
                hintText: 'e.g. 8000',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Save Settings'),
              onPressed: _saveConfig,
            ),
          ],
        ),
      ),
    );
  }
}
