import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'widgets/surface_card.dart';
import '../services/tenant_service.dart';

/// Admin console: send alerts, manage timezone, and grant admin roles.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _functions = FirebaseFunctions.instance;
  final _auth = FirebaseAuth.instance;
  final _configRef = FirebaseFirestore.instance.doc('config/admin');

  static const List<String> _timeZones = <String>[
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Phoenix',
    'America/Los_Angeles',
    'America/Anchorage',
    'Pacific/Honolulu',
  ];

  String? _selectedUserId;
  String? _selectedUserName;
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _bodyCtrl = TextEditingController();
  TimeOfDay _dailyTime = const TimeOfDay(hour: 9, minute: 0);
  bool _scheduleDaily = false;
  String? _timezone;
  bool _timezoneLocked = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDailyTime() async {
    final picked = await showTimePicker(context: context, initialTime: _dailyTime);
    if (picked != null) {
      setState(() => _dailyTime = picked);
    }
  }

  Future<void> _setTimezone(String zone) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _configRef.set(
        {
          'timezone': zone,
          'timezoneLocked': true,
        },
        SetOptions(merge: true),
      );
      setState(() {
        _timezone = zone;
        _timezoneLocked = true;
      });
      messenger.showSnackBar(SnackBar(content: Text('Timezone set to $zone')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to set timezone: $e')));
    }
  }

  Future<void> _sendAlertNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final targetUser = _selectedUserId ?? _auth.currentUser?.uid;
    if (targetUser == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a user first')));
      return;
    }
    if ((_timezone ?? '').isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Set a timezone first')));
      return;
    }

    final title = _titleCtrl.text.trim().isEmpty ? 'Prep Check Alert' : _titleCtrl.text.trim();
    final message = _bodyCtrl.text.trim();
    final docRef = FirebaseFirestore.instance.collection('alerts').doc();
    await docRef.set({
      'title': title,
      'message': message,
      'userIds': [targetUser],
      'timezone': _timezone,
      'dailyAt': _formatTime(_dailyTime),
      'enabled': true,
      'sendNow': true,
      'schedule': {'daily': false},
      'lastSentDate': null,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
    });

    try {
      await _functions.httpsCallable('sendAlertNow').call({'alertId': docRef.id});
      await docRef.update({'sendNow': false});
      messenger.showSnackBar(const SnackBar(content: Text('Alert sent')));
    } on FirebaseFunctionsException catch (e) {
      if (e.code.toLowerCase() == 'not-found') {
        messenger.showSnackBar(
          const SnackBar(content: Text('Alert queued; will send shortly.')),
        );
      } else {
        messenger.showSnackBar(SnackBar(content: Text('Send failed: ${e.message ?? e.code}')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
  }

  Future<void> _createDailyAlert() async {
    final messenger = ScaffoldMessenger.of(context);
    if (!_scheduleDaily) {
      messenger.showSnackBar(const SnackBar(content: Text('Enable daily schedule to save alert')));
      return;
    }
    if ((_timezone ?? '').isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Set a timezone first')));
      return;
    }
    if (_selectedUserId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a user first')));
      return;
    }
    final title = _titleCtrl.text.trim().isEmpty ? 'Prep Check Daily Reminder' : _titleCtrl.text.trim();
    final message = _bodyCtrl.text.trim();
    await FirebaseFirestore.instance.collection('alerts').add({
      'title': title,
      'message': message,
      'userIds': [_selectedUserId],
      'dailyAt': _formatTime(_dailyTime),
      'timezone': _timezone,
      'enabled': true,
      'sendNow': false,
      'schedule': {'daily': true},
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': _auth.currentUser?.uid,
    });
    messenger.showSnackBar(const SnackBar(content: Text('Daily alert saved')));
  }

  Future<void> _grantAdmin(bool makeAdmin) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedUserId == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Pick a user first')));
      return;
    }
    try {
      final callable = _functions.httpsCallable('setAdminRole');
      // Server accepts 'makeAdmin' and (for backward-compat) 'isAdmin'.
      await callable.call({'uid': _selectedUserId, 'makeAdmin': makeAdmin});
      await FirebaseFirestore.instance.collection('admins').doc(_selectedUserId).set({
        'isAdmin': makeAdmin,
        'displayName': _selectedUserName,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      messenger.showSnackBar(
        SnackBar(content: Text(makeAdmin ? 'Granted admin access' : 'Revoked admin access')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Admin update failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _configRef.snapshots(),
        builder: (context, configSnap) {
          final data = configSnap.data?.data();
          if (data != null) {
            final tz = (data['timezone'] ?? '').toString();
            _timezoneLocked = data['timezoneLocked'] == true;
            if (tz.isNotEmpty) {
              _timezone = tz;
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              FutureBuilder<String?>(
                future: TenantService.getBusinessId(),
                builder: (context, bizSnap) {
                  final biz = bizSnap.data;
                  if (biz == null) {
                    return SurfaceCard(
                      title: 'Business',
                      subtitle: 'No business selected',
                      trailing: FilledButton.icon(
                        onPressed: () => _pickBusiness(context),
                        icon: const Icon(Icons.store_mall_directory_outlined),
                        label: const Text('Choose Business'),
                      ),
                      child: const SizedBox.shrink(),
                    );
                  }
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.doc('businesses/$biz').snapshots(),
                    builder: (context, snap) {
                      final name = (snap.data?.data()?['name'] ?? biz).toString();
                      final ctrl = TextEditingController(text: name);
                      return SurfaceCard(
                        title: 'Business',
                        subtitle: 'ID: $biz',
                        trailing: OutlinedButton.icon(
                          onPressed: () => _pickBusiness(context),
                          icon: const Icon(Icons.swap_horiz),
                          label: const Text('Change'),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(labelText: 'Business name'),
                            ),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final newName = ctrl.text.trim();
                                try {
                                  await FirebaseFirestore.instance.doc('businesses/$biz').set({'name': newName}, SetOptions(merge: true));
                                  await FirebaseFirestore.instance.doc('settings/app').set({'businessName': newName}, SetOptions(merge: true));
                                  messenger.showSnackBar(const SnackBar(content: Text('Business name saved')));
                                } catch (e) {
                                  messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
                                }
                              },
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 12),
              if (!_timezoneLocked)
                SurfaceCard(
                  title: 'Set Timezone',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Timezone'),
                        initialValue: _timezone,
                        items: [
                          for (final zone in _timeZones)
                            DropdownMenuItem(value: zone, child: Text(zone)),
                        ],
                        onChanged: (v) => setState(() => _timezone = v),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _timezone == null ? null : () => _setTimezone(_timezone!),
                          icon: const Icon(Icons.lock_outline),
                          label: const Text('Lock Timezone'),
                        ),
                      ),
                    ],
                  ),
                )
              else
                SurfaceCard(
                  title: 'Timezone: ${_timezone ?? 'Unknown'}',
                  subtitle: 'Timezone is locked. Contact support to change.',
                  child: const SizedBox.shrink(),
                ),
              SurfaceCard(
                title: 'Alerts & Access',
                subtitle: 'Send alerts, schedule, manage admins',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select User', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('displayName')
                          .limit(500)
                          .snapshots(),
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        return DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'User'),
                          initialValue: _selectedUserId,
                          items: [
                            for (final doc in docs)
                              DropdownMenuItem(
                                value: doc.id,
                                child: Text(
                                  (doc.data()['displayName'] ?? doc.data()['name'] ?? doc.data()['email'] ?? doc.id)
                                      .toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedUserId = value;
                              if (value == null) {
                                _selectedUserName = null;
                              } else {
                                final match = docs.firstWhere((d) => d.id == value).data();
                                _selectedUserName =
                                    (match['displayName'] ?? match['name'] ?? match['email'] ?? value).toString();
                              }
                            });
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Text('Compose Alert', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Alert title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bodyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Alert message'),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _scheduleDaily,
                      onChanged: (v) => setState(() => _scheduleDaily = v),
                      title: const Text('Schedule daily alert'),
                      subtitle: const Text('Sends every day at the selected time'),
                    ),
                    if (_scheduleDaily) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Daily time: ${_formatTime(_dailyTime)}'),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _pickDailyTime,
                            icon: const Icon(Icons.schedule),
                            label: const Text('Change'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sendAlertNow,
                        icon: const Icon(Icons.campaign_outlined),
                        label: const Text('Send alert now'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _scheduleDaily ? _createDailyAlert : null,
                        icon: const Icon(Icons.save_alt),
                        label: const Text('Save daily alert'),
                      ),
                    ),
                    const Divider(height: 32),
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Grant admin',
                          onPressed: () => _grantAdmin(true),
                          icon: const Icon(Icons.check_circle_outline),
                        ),
                        IconButton(
                          tooltip: 'Revoke admin',
                          onPressed: () => _grantAdmin(false),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                title: 'Manage Positions',
                child: _PositionsManager(),
              ),
              const SizedBox(height: 16),
              SurfaceCard(
                title: 'Maintenance',
                subtitle: 'Migrate lists or reset data',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.drive_file_move_outline),
                      label: const Text('Move top-level lists into current business'),
                      onPressed: _migrateTopLevelListsToBiz,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.warning_amber_outlined),
                      label: const Text('Clear ALL business + user data (fresh start)'),
                      onPressed: _confirmAndClearAll,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _migrateTopLevelListsToBiz() async {
    final messenger = ScaffoldMessenger.of(context);
    final biz = await TenantService.getBusinessId();
    if (biz == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Select a business first (Business card above)')));
      return;
    }
    try {
      final db = FirebaseFirestore.instance;
      final pairs = [
        ('inventory_lists', 'inventory_lists'),
        ('prep_lists', 'prep_lists'),
      ];
      for (final p in pairs) {
        final sourceCol = db.collection(p.$1);
        final destCol = db.collection('businesses/$biz/${p.$2}');
        final docs = await sourceCol.get();
        for (final doc in docs.docs) {
          final data = doc.data();
          await destCol.doc(doc.id).set(data, SetOptions(merge: true));
          final items = await doc.reference.collection('items').get();
          for (final item in items.docs) {
            await destCol.doc(doc.id).collection('items').doc(item.id).set(item.data(), SetOptions(merge: true));
          }
          for (final item in items.docs) { try { await item.reference.delete(); } catch (_) {} }
          try { await doc.reference.delete(); } catch (_) {}
        }
      }
      messenger.showSnackBar(const SnackBar(content: Text('Migration complete')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Migration failed: $e')));
    }
  }

  Future<void> _confirmAndClearAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear ALL data?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This removes business lists and user profiles. Type CLEAR to proceed.'),
            const SizedBox(height: 8),
            TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Type CLEAR')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, ctrl.text.trim().toUpperCase() == 'CLEAR'),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final db = FirebaseFirestore.instance;
      final biz = await TenantService.getBusinessId();
      if (biz != null) {
        await _deleteCollectionWithItems(db.collection('businesses/$biz/inventory_lists'));
        await _deleteCollectionWithItems(db.collection('businesses/$biz/prep_lists'));
        try { await _deleteCollection(db.collection('businesses/$biz/shifts')); } catch (_) {}
        try { await db.doc('businesses/$biz').set({'name': FieldValue.delete()}, SetOptions(merge: true)); } catch (_) {}
      }
      await _deleteCollectionWithItems(db.collection('inventory_lists'));
      await _deleteCollectionWithItems(db.collection('prep_lists'));
      await _deleteCollection(db.collection('users'));
      try { await db.doc('settings/app').set({'businessName': FieldValue.delete()}, SetOptions(merge: true)); } catch (_) {}
      await TenantService.setBusinessId(null);
      messenger.showSnackBar(const SnackBar(content: Text('All data cleared. Fresh start ready.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Clear failed: $e')));
    }
  }

  Future<void> _deleteCollectionWithItems(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    for (final d in snap.docs) {
      try {
        final items = await d.reference.collection('items').get();
        for (final it in items.docs) { try { await it.reference.delete(); } catch (_) {} }
      } catch (_) {}
      try { await d.reference.delete(); } catch (_) {}
    }
  }

  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
    final snap = await col.get();
    for (final d in snap.docs) { try { await d.reference.delete(); } catch (_) {} }
  }
}


class _PositionsManager extends StatefulWidget {
  const _PositionsManager();
  @override
  State<_PositionsManager> createState() => _PositionsManagerState();
}

class _PositionsManagerState extends State<_PositionsManager> {
  final _ref = FirebaseFirestore.instance.doc('settings/app');
  final _addCtrl = TextEditingController();

  @override
  void dispose() {
    _addCtrl.dispose();
    super.dispose();
  }

  

  

  Future<void> _add() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    await _ref.set({'positions': FieldValue.arrayUnion([name])}, SetOptions(merge: true));
    _addCtrl.clear();
  }

  Future<void> _remove(String name) async {
    await _ref.set({'positions': FieldValue.arrayRemove([name])}, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _ref.snapshots(),
      builder: (context, snap) {
        final positions = ((snap.data?.data()?['positions'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title provided by parent SurfaceCard
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in positions)
                InputChip(
                  label: Text(p),
                  onDeleted: () => _remove(p),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _addCtrl, decoration: const InputDecoration(labelText: 'New position'))),
              const SizedBox(width: 8),
              FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add')),
            ]),
          ],
        );
      },
    );
  }
}

Future<void> _pickBusiness(BuildContext context) async {
  final col = FirebaseFirestore.instance.collection('businesses');
  final snap = await col.orderBy(FieldPath.documentId).limit(200).get();
  if (!context.mounted) return;
  String? selected;
  final manualIdCtrl = TextEditingController();
  final manualNameCtrl = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Select Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selected,
                  items: [
                    for (final d in snap.docs)
                      DropdownMenuItem(
                        value: d.id,
                        child: Text((d.data()['name'] ?? d.id).toString(), overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setStateDialog(() => selected = v),
                  decoration: const InputDecoration(labelText: 'Business'),
                ),
                if (snap.docs.isEmpty) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: manualIdCtrl,
                    decoration: const InputDecoration(labelText: 'New Business ID (e.g., my-store)')
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: manualNameCtrl,
                    decoration: const InputDecoration(labelText: 'Business Name'),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                String? toUse = selected;
                if (toUse == null) {
                  final id = manualIdCtrl.text.trim();
                  if (id.isNotEmpty) {
                    final name = manualNameCtrl.text.trim();
                    await col.doc(id).set({'name': name.isEmpty ? id : name, 'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                    toUse = id;
                  }
                }
                if (toUse != null) {
                  await TenantService.setBusinessId(toUse);
                  // Bootstrap membership so rules permit access for this user
                  try {
                    final me = FirebaseAuth.instance.currentUser;
                    if (me != null) {
                      await FirebaseFirestore.instance
                          .doc('businessMembers/$toUse/users/${me.uid}')
                          .set({
                        'role': 'owner',
                        'addedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    }
                  } catch (_) {}
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Use'),
            ),
          ],
        );
      },
    ),
  );
}
