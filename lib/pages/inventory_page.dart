import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'order_preview_page.dart';

class InventoryPage extends StatefulWidget {
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  String? _listId;

  @override
  Widget build(BuildContext context) {
    final listsCol = FirebaseFirestore.instance.collection('inventory_lists');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listsCol.orderBy('label').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final lists = snap.data!.docs;
        _listId ??= lists.isNotEmpty ? lists.first.id : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory'),
            actions: [
              if (_listId != null)
                IconButton(
                  tooltip: 'Order Preview',
                  icon: const Icon(Icons.shopping_cart_checkout_outlined),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OrderPreviewPage(listRef: listsCol.doc(_listId!)),
                    ));
                  },
                )
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _createList(listsCol),
            icon: const Icon(Icons.add),
            label: const Text('Add list'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
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
                        decoration: const InputDecoration(labelText: 'Select inventory list'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_listId != null)
                      IconButton(
                        tooltip: 'Delete list',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteList(listsCol.doc(_listId!)),
                      ),
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
                    ? const Center(child: Text('No lists. Tap Add list.'))
                    : _Items(listRef: listsCol.doc(_listId!)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createList(CollectionReference<Map<String, dynamic>> listsCol) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New inventory list'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      final doc = await listsCol.add({'label': ctrl.text.trim(), 'createdAt': FieldValue.serverTimestamp()});
      setState(() => _listId = doc.id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('List created')));
    }
  }

  Future<void> _addItem(DocumentReference<Map<String, dynamic>> listRef) async {
    final nameCtrl = TextEditingController();
    final parCtrl = TextEditingController(text: '0');
    final qohCtrl = TextEditingController(text: '0');

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add inventory item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Item name')),
            TextField(controller: parCtrl, decoration: const InputDecoration(labelText: 'Par'), keyboardType: TextInputType.number),
            TextField(controller: qohCtrl, decoration: const InputDecoration(labelText: 'On hand'), keyboardType: TextInputType.number),
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
        'par': int.tryParse(parCtrl.text) ?? 0,
        'qoh': int.tryParse(qohCtrl.text) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item added')));
    }
  }

  Future<void> _deleteList(DocumentReference<Map<String, dynamic>> listRef) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete inventory list?'),
        content: const Text('This will remove the list and all its items.'),
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

class _Items extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const _Items({required this.listRef});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listRef.collection('items').orderBy('name').snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snap.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No items'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, i) {
            final ref = docs[i].reference;
            final d = docs[i].data();
            final name = (d['name'] ?? '').toString();
            final par = (d['par'] ?? 0) as int;
            final qoh = (d['qoh'] ?? 0) as int;
            final order = (par - qoh) > 0 ? (par - qoh) : 0;
            final danger = par > 0 && qoh < par * 0.5;
            final warn = par > 0 && qoh < par;

            return ListTile(
              title: Text(name),
              subtitle: Text('Par: $par   On hand: $qoh   Order: $order'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decrease on hand',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => ref.update({'qoh': (qoh - 1).clamp(0, 100000)}),
                  ),
                  IconButton(
                    tooltip: 'Increase on hand',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => ref.update({'qoh': qoh + 1}),
                  ),
                ],
              ),
              tileColor: danger
                  ? Colors.red.withOpacity(0.05)
                  : (warn ? Colors.orange.withOpacity(0.05) : null),
            );
          },
        );
      },
    );
  }
}
