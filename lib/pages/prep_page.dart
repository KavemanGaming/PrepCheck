import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PrepPage extends StatefulWidget {
  const PrepPage({super.key});
  @override
  State<PrepPage> createState() => _PrepPageState();
}

class _PrepPageState extends State<PrepPage> {
  String? _listId;

  @override
  Widget build(BuildContext context) {
    final listsCol = FirebaseFirestore.instance.collection('prep_lists');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listsCol.orderBy('label').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final lists = snap.data!.docs;
        _listId ??= lists.isNotEmpty ? lists.first.id : null;
        return Scaffold(
          floatingActionButton: _buildFab(listsCol),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _listId,
                        items: [
                          for (final d in lists)
                            DropdownMenuItem(value: d.id, child: Text((d.data()['label'] ?? d.id).toString())),
                        ],
                        onChanged: (v) => setState(() => _listId = v),
                        decoration: const InputDecoration(labelText: 'Select prep list'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_listId != null)
                      IconButton(
                        tooltip: 'Add item',
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () => _addItem(listsCol.doc(_listId!)),
                      ),
                    if (_listId != null)
                      IconButton(
                        tooltip: 'Delete list',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deletePrepList(listsCol.doc(_listId!)),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _listId == null
                    ? const Center(child: Text('No prep lists yet. Tap + to create one.'))
                    : _PrepItems(listRef: listsCol.doc(_listId!)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFab(CollectionReference<Map<String, dynamic>> listsCol) {
    return FloatingActionButton.extended(
      onPressed: () async {
        final ctrl = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('New prep list'),
            content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Label')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
            ],
          ),
        );
        if (ok == true && ctrl.text.trim().isNotEmpty) {
          final u = FirebaseAuth.instance.currentUser;
          final doc = await listsCol.add({
            'label': ctrl.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': u != null ? {'uid': u.uid, 'email': u.email, 'name': u.displayName} : null,
          });
          setState(() => _listId = doc.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prep list created')));
          }
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Add prep list'),
    );
  }

  Future<void> _addItem(DocumentReference<Map<String, dynamic>> listRef) async {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final unitCtrl = TextEditingController(text: 'ea');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add prep item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Qty needed'), keyboardType: TextInputType.number),
            TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'Unit (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await listRef.collection('items').add({
        'name': nameCtrl.text.trim(),
        'qty': int.tryParse(qtyCtrl.text) ?? 1,
        'unit': unitCtrl.text.trim(),
        'done': false,
        'completedBy': null,
        'completedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prep item added')));
      }
    }
  }

  Future<void> _deletePrepList(DocumentReference<Map<String, dynamic>> listRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete prep list?'),
        content: const Text('This will remove the list and its items.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    final items = await listRef.collection('items').get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in items.docs) {
      batch.delete(d.reference);
    }
    batch.delete(listRef);
    await batch.commit();
    setState(() => _listId = null);
  }
}

class _PrepItems extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const _PrepItems({required this.listRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listRef.collection('items').orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No items yet'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final ref = docs[i].reference;
            final d = docs[i].data();
            final name = (d['name'] ?? '').toString();
            final qty = d['qty'] ?? 0;
            final unit = (d['unit'] ?? '').toString();
            final done = d['done'] == true;
            final completedBy = d['completedBy']?['name'] ?? d['completedBy']?['email'];
            final completedAt = (d['completedAt'] as Timestamp?)?.toDate();

            return CheckboxListTile(
              value: done,
              onChanged: (v) async {
                await ref.update({
                  'done': v == true,
                  'completedBy': v == true
                      ? {'name': (FirebaseAuth.instance.currentUser?.displayName ?? ''), 'email': FirebaseAuth.instance.currentUser?.email}
                      : null,
                  'completedAt': v == true ? FieldValue.serverTimestamp() : null,
                });
              },
              title: Text(name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Needed: $qty ${unit.isNotEmpty ? unit : ''}'),
                  if (done && completedAt != null)
                    Text('Completed by ${completedBy ?? 'unknown'} at ${completedAt.toLocal()}',
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
