import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminAlertsPage extends StatefulWidget {
  const AdminAlertsPage({super.key});

  @override
  State<AdminAlertsPage> createState() => _AdminAlertsPageState();
}

class _AdminAlertsPageState extends State<AdminAlertsPage> {
  bool _enabled = true;
  int _hour = 15;
  int _minute = 0;
  String _tz = 'America/New_York';
  List<int> _days = [0,1,3,4,5,6];
  final _messageCtrl = TextEditingController(text: 'Time for daily prep check!');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('settings').doc('alerts').get();
    if (doc.exists) {
      final d = doc.data()!;
      setState(() {
        _enabled = d['enabled'] ?? true;
        _hour = (d['hour'] ?? 15) as int;
        _minute = (d['minute'] ?? 0) as int;
        _tz = (d['tz'] ?? 'America/New_York') as String;
        final days = d['days'];
        if (days is List) _days = days.map<int>((e) => (e as num).toInt()).toList();
        _messageCtrl.text = (d['message'] ?? 'Time for daily prep check!').toString();
      });
    }
  }

  Future<void> _save() async {
    await FirebaseFirestore.instance.collection('settings').doc('alerts').set({
      'enabled': _enabled,
      'hour': _hour,
      'minute': _minute,
      'tz': _tz,
      'days': _days,
      'message': _messageCtrl.text.trim(),
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved alert settings')));
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = const ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Alerts (Admins)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enabled'),
            value: _enabled,
            onChanged: (v) => setState(() => _enabled = v),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _hour,
                  decoration: const InputDecoration(labelText: 'Hour (0–23)'),
                  items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text('$i'))),
                  onChanged: (v) => setState(() => _hour = v ?? _hour),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _minute,
                  decoration: const InputDecoration(labelText: 'Minute'),
                  items: [0,5,10,15,20,25,30,35,40,45,50,55].map((m)=>DropdownMenuItem(value: m, child: Text('$m'))).toList(),
                  onChanged: (v) => setState(() => _minute = v ?? _minute),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _tz,
            decoration: const InputDecoration(labelText: 'Time zone (IANA)', helperText: 'e.g. America/New_York', border: OutlineInputBorder()),
            onChanged: (v) => _tz = v.trim(),
          ),
          const SizedBox(height: 12),
          Text('Days', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(7, (i) {
              final selected = _days.contains(i);
              return FilterChip(
                label: Text(dayLabels[i]),
                selected: selected,
                onSelected: (v) {
                  setState(() {
                    if (v) { if (!_days.contains(i)) _days.add(i); }
                    else { _days.remove(i); }
                  });
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _messageCtrl,
            decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
