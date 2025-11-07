import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'order_preview_page.dart';
import '../services/tenant_service.dart';
import '../auth/role_stream.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String? _listId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: TenantService.getBusinessId(),
      builder: (context, bizSnap) {
        final biz = bizSnap.data;
        Future<CollectionReference<Map<String, dynamic>>> resolveCol() async {
          if (biz == null) return FirebaseFirestore.instance.collection('inventory_lists');
          try {
            // Permission probe: if denied, fall back to top-level
            await FirebaseFirestore.instance.doc('businesses/$biz').get();
            return FirebaseFirestore.instance.collection('businesses/$biz/inventory_lists');
          } catch (_) {
            return FirebaseFirestore.instance.collection('inventory_lists');
          }
        }

        return FutureBuilder<CollectionReference<Map<String, dynamic>>>(
          future: resolveCol(),
          builder: (context, colSnap) {
            if (!colSnap.hasData) return const Center(child: CircularProgressIndicator());
            final listsCol = colSnap.data!;
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listsCol.orderBy('label').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final lists = snap.data!.docs;
        _listId ??= lists.isNotEmpty ? lists.first.id : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory'),
            actions: [
              if (_listId != null) ...[
                Builder(
                  builder: (context) {
                    final today = DateTime.now().toIso8601String().substring(0, 10);
                    final listRef = listsCol.doc(_listId!);
                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      // Avoid composite index: filter by date only, count with order > 0 client-side
                      stream: listRef
                          .collection('items')
                          .where('orderEditedOn', isEqualTo: today)
                          .snapshots(),
                      builder: (context, snap) {
                        final count = snap.hasData
                            ? snap.data!.docs.where((d) {
                                final raw = d.data()['order'];
                                int n = 0;
                                if (raw is int) {
                                  n = raw;
                                } else if (raw is num) {
                                  n = raw.toInt();
                                } else if (raw is String) {
                                  n = int.tryParse(raw) ?? 0;
                                }
                                return n > 0;
                              }).length
                            : 0;
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            IconButton(
                              tooltip: 'Order Preview',
                              icon: const Icon(Icons.shopping_cart_checkout_outlined),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => OrderPreviewPage(listId: _listId!),
                                  ),
                                );
                              },
                            ),
                            if (count > 0)
                              Positioned(
                                right: 8,
                                top: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11)),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                FutureBuilder<bool>(
                  future: Role.isAdminOnce(),
                  builder: (context, snap) {
                    final isAdmin = snap.data == true;
                    if (!isAdmin) return const SizedBox.shrink();
                    return PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'delete_list') {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Delete list?'),
                              content: const Text('This will delete the list and all its items.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (ok == true) {
                            final ref = listsCol.doc(_listId!);
                            final items = await ref.collection('items').get();
                            for (final d in items.docs) { try { await d.reference.delete(); } catch (_) {} }
                            try { await ref.delete(); } catch (_) {}
                            if (mounted) setState(() => _listId = null);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'delete_list', child: Text('Delete list')),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _listId,
                        items: [
                          for (final d in lists)
                            DropdownMenuItem<String>(
                              value: d.id,
                              child: Text(d.data()['label']?.toString() ?? d.id),
                            ),
                        ],
                        onChanged: (v) => setState(() => _listId = v),
                        decoration: const InputDecoration(labelText: 'Inventory list'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_listId != null)
                      IconButton(
                        tooltip: 'Add item',
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () => _addItem(listsCol.doc(_listId!)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _listId == null
                    ? const Center(child: Text('No lists. Create one.'))
                    : _Items(listRef: listsCol.doc(_listId!)),
              ),
              if (_listId != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.receipt_long),
                        label: const Text('Review Order'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => OrderPreviewPage(listId: _listId!)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
          },
        );
      },
    );
  }

  Future<void> _addItem(DocumentReference<Map<String, dynamic>> listRef) async {
    final nameCtrl = TextEditingController();
    final parCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add inventory item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: parCtrl, decoration: const InputDecoration(labelText: 'Par'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await listRef.collection('items').add({
        'name': nameCtrl.text.trim(),
        'par': int.tryParse(parCtrl.text) ?? 0,
        'order': 0,
        'ownerId': FirebaseAuth.instance.currentUser?.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
      }
    }
  }
}

class _Items extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const _Items({required this.listRef});

  @override
  State<_Items> createState() => _ItemsState();
}

class _ItemsState extends State<_Items> {
  Timer? _midnightTimer;
  bool _showHiddenForToday = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _scheduleMidnightTick();
    Role.isAdminOnce().then((v) {
      if (!mounted) return;
      setState(() => _isAdmin = v);
    });
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    super.dispose();
  }

  void _scheduleMidnightTick() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final duration = nextMidnight.difference(now);
    _midnightTimer?.cancel();
    _midnightTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {});
      // reschedule for the following day
      _scheduleMidnightTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.listRef.collection('items').orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No items yet'));
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final listView = ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final ref = docs[i].reference;
            final d = docs[i].data();
            final name = (d['name'] ?? '').toString();
            final par = _parseInt(d['par'] ?? 0);
            final manualOrder = _parseInt(d['order']);
            final editedOn = (d['orderEditedOn'] ?? '').toString();
            final isToday = editedOn == today;

            if (manualOrder > 0 && editedOn.isNotEmpty && !isToday) {
              Future.microtask(() async {
                try {
                  await ref.update({'order': 0, 'orderEditedOn': FieldValue.delete()});
                } catch (_) {}
              });
            }

            if (manualOrder > 0 && isToday && !_showHiddenForToday) {
              // Already filled for today; hide entry.
              return const SizedBox.shrink();
            }

            final controller = TextEditingController(text: '');

            final tile = ListTile(
              isThreeLine: true,
              title: Text(name.isEmpty ? ref.id : name),
              subtitle: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Chip(label: Text('Par: $par')),
                  if (manualOrder > 0 && isToday && _showHiddenForToday)
                    const Chip(label: Text('Filled'), visualDensity: VisualDensity.compact),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit Par',
                    icon: const Icon(Icons.tune),
                    onPressed: () async {
                      final isAdmin = await Role.isAdminOnce();
                      if (!isAdmin) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Admin only: cannot edit Par')),
                        );
                        return;
                      }
                      final ctrl = TextEditingController(text: par.toString());
                      if (!context.mounted) return;
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Edit Par'),
                          content: TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Par'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final np = int.tryParse(ctrl.text) ?? par;
                        try {
                          await ref.set({'par': np}, SetOptions(merge: true));
                        } catch (_) {}
                      }
                    },
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      controller: controller,
                      enabled: !(manualOrder > 0 && isToday && !_showHiddenForToday),
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        hintText: '0',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (value) async {
                        final n = int.tryParse(value) ?? 0;
                        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                        final payload = n <= 0
                            ? {
                                'order': 0,
                                'orderEditedOn': FieldValue.delete(),
                              }
                            : {
                                'order': n,
                                'orderEditedOn': todayStr,
                              };
                        try {
                          await ref.update(payload);
                        } catch (_) {
                          await ref.set(payload, SetOptions(merge: true));
                        }
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Set and preview',
                    icon: const Icon(Icons.arrow_outward),
                    onPressed: () async {
                      final n = int.tryParse(controller.text) ?? 0;
                      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
                      final payload = n <= 0
                          ? {
                              'order': 0,
                              'orderEditedOn': FieldValue.delete(),
                            }
                          : {
                              'order': n,
                              'orderEditedOn': todayStr,
                            };
                      try { await ref.update(payload); } catch (_) { await ref.set(payload, SetOptions(merge: true)); }
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => OrderPreviewPage(listId: widget.listRef.id)),
                      );
                    },
                  ),
                  if (_isAdmin)
                    IconButton(
                      tooltip: 'Delete item',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Delete item?'),
                            content: Text('Delete "${name.isEmpty ? ref.id : name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (ok == true) { try { await ref.delete(); } catch (_) {} }
                      },
                    ),
                ],
              ),
            );

            if (_isAdmin) {
              return Dismissible(
                key: ValueKey(ref.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.red.withValues(alpha: 0.12),
                  child: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                confirmDismiss: (_) async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete item?'),
                      content: Text('Delete "${name.isEmpty ? ref.id : name}"?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  );
                  return ok == true;
                },
                onDismissed: (_) async { try { await ref.delete(); } catch (_) {} },
                child: tile,
              );
            }

            return tile;
          },
        );

        if (!_isAdmin) return listView;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  const Icon(Icons.visibility, size: 18),
                  const SizedBox(width: 8),
                  const Text("Show today's filled items"),
                  const Spacer(),
                  Switch(value: _showHiddenForToday, onChanged: (v) => setState(() => _showHiddenForToday = v)),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(child: listView),
          ],
        );
      },
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
