import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String? _listForItem;
  TimeOfDay _time = const TimeOfDay(hour: 15, minute: 0);
  final _days = <int>{1,2,3,4,5,6,0};
  bool _alertsEnabled = true;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.doc('settings/alerts').get().then((s) {
      final d = s.data() ?? {};
      setState(() {
        _alertsEnabled = d['enabled'] ?? true;
        final hm = (d['time'] ?? '15:00').split(':');
        _time = TimeOfDay(hour: int.tryParse(hm[0]) ?? 15, minute: int.tryParse(hm[1]) ?? 0);
        final days = (d['days'] as List?)?.map((e) => int.tryParse(e.toString()) ?? 0).toSet();
        if (days != null && days.isNotEmpty) _days..clear()..addAll(days);
      });
    });
  }

  Future<void> _addInventoryList() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (_) {
      return AlertDialog(
        title: const Text('New inventory list'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      );
    });
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await FirebaseFirestore.instance.collection('inventory_lists').add({
        'label': ctrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List created')));
    }
  }

  Future<void> _addInventoryItem() async {
    String? listId = _listForItem;
    final nameCtrl = TextEditingController();
    final parCtrl = TextEditingController(text: '0');

    final lists = await FirebaseFirestore.instance.collection('inventory_lists').orderBy('label').get();
    if (lists.docs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a list first')));
      return;
    }
    listId ??= lists.docs.first.id;

    final ok = await showDialog<bool>(context: context, builder: (_) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Add item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: listId,
                items: [
                  for (final d in lists.docs)
                    DropdownMenuItem(value: d.id, child: Text((d.data()['label'] ?? d.id).toString())),
                ],
                onChanged: (v) => setStateDialog(() => listId = v),
                decoration: const InputDecoration(labelText: 'List'),
              ),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item name')),
              TextField(controller: parCtrl, decoration: const InputDecoration(labelText: 'Par'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        );
      });
    });

    if (ok == true && listId != null && nameCtrl.text.trim().isNotEmpty) {
      final par = int.tryParse(parCtrl.text.trim()) ?? 0;
      await FirebaseFirestore.instance.collection('inventory_lists').doc(listId).collection('items').add({
        'name': nameCtrl.text.trim(),
        'par': par,
        'qoh': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
    }
  }

  Future<void> _cleanupInventoryItems() async {
    final lists = await FirebaseFirestore.instance.collection('inventory_lists').get();
    int removed = 0;
    final batch = FirebaseFirestore.instance.batch();
    for (final l in lists.docs) {
      final items = await l.reference.collection('items').get();
      for (final it in items.docs) {
        final data = it.data();
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) { batch.delete(it.reference); removed++; }
      }
    }
    if (removed > 0) await batch.commit();
    if (!mounted) return;
    // FIX: use Dart string interpolation
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cleanup complete: removed $removed empty items')));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _saveAlerts() async {
    await FirebaseFirestore.instance.doc('settings/alerts').set({
      'enabled': _alertsEnabled,
      'time': '${_time.hour.toString().padLeft(2,'0')}:${_time.minute.toString().padLeft(2,'0')}',
      'days': _days.toList(),
      'tz': 'America/New_York',
    }, SetOptions(merge: true));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.add_box_outlined),
            title: const Text('Add inventory list'),
            onTap: _addInventoryList,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.playlist_add_outlined),
            title: const Text('Add item to a list'),
            onTap: _addInventoryItem,
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Clean up empty items'),
            subtitle: const Text('Deletes items with blank names across lists'),
            onTap: _cleanupInventoryItems,
          ),
        ),
        const Divider(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text('Daily alerts', style: Theme.of(context).textTheme.titleMedium),
        ),
        SwitchListTile(
          value: _alertsEnabled,
          onChanged: (v) => setState(() => _alertsEnabled = v),
          title: const Text('Enable alerts for admins'),
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: Text('Time: ${_time.format(context)} (ET)'),
          onTap: _pickTime,
        ),
        Wrap(
          spacing: 8,
          children: List<Widget>.generate(7, (i) {
            const labels = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
            final on = _days.contains(i);
            return FilterChip(
              label: Text(labels[i]),
              selected: on,
              onSelected: (v) => setState(() {
                if (v) { _days.add(i); } else { _days.remove(i); }
              }),
            );
          }),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _saveAlerts,
            icon: const Icon(Icons.save),
            label: const Text('Save alerts'),
          ),
        ),
      ],
    );
  }
}
