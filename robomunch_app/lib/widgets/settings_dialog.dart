import 'package:flutter/material.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.localUrl,
    required this.cloudUrl,
  });

  final String localUrl;
  final String cloudUrl;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _local;
  late final TextEditingController _cloud;

  @override
  void initState() {
    super.initState();
    _local = TextEditingController(text: widget.localUrl);
    _cloud = TextEditingController(text: widget.cloudUrl);
  }

  @override
  void dispose() {
    _local.dispose();
    _cloud.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Backend URLs"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Backend Server 1 (your computer / Flask)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _local,
              decoration: const InputDecoration(
                hintText: "http://<computer-LAN-IP>:5000",
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Backend Server 2 (cloud VM / Django)",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _cloud,
              decoration: const InputDecoration(
                hintText: "http://<VM-IP>:8000",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Cancel"),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            "local": _local.text.trim(),
            "cloud": _cloud.text.trim(),
          }),
          child: const Text("Save"),
        ),
      ],
    );
  }
}
