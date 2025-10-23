import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class InventoryListSelector extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>>? initial;
  final void Function(DocumentReference<Map<String, dynamic>>? ref) onChanged;
  const InventoryListSelector({super.key, required this.onChanged, this.initial});

  @override
  State<InventoryListSelector> createState() => _InventoryListSelectorState();
}

class _InventoryListSelectorState extends State<InventoryListSelector> {
  DocumentReference<Map<String, dynamic>>? _current;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final listsCol = FirebaseFirestore.instance.collection('inventory_lists');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listsCol.orderBy('name').snapshots(),
      builder: (context, snap) {
        final items = <DropdownMenuItem<DocumentReference<Map<String, dynamic>>?>>[];

        items.add(const DropdownMenuItem(
          value: null,
          child: Text('All items (root inventory)'),
        ));

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final name = (doc.data()['name'] ?? 'Untitled').toString();
            items.add(DropdownMenuItem(
              value: doc.reference,
              child: Text(name),
            ));
          }
        }

        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<DocumentReference<Map<String, dynamic>>?>(
                value: _current,
                items: items,
                decoration: const InputDecoration(
                  labelText: 'List',
                  border: OutlineInputBorder(),
                ),
                onChanged: (ref) {
                  setState(() => _current = ref);
                  widget.onChanged(ref);
                },
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Create new list',
              child: _creating
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      onPressed: () async {
                        final nameCtrl = TextEditingController();
                        final created = await showDialog<String>(context: context, builder: (ctx){
                          return AlertDialog(
                            title: const Text('New list'),
                            content: TextField(
                              controller: nameCtrl,
                              decoration: const InputDecoration(labelText: 'List name'),
                              autofocus: true,
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              FilledButton(
                                onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                                child: const Text('Create'),
                              )
                            ],
                          );
                        });
                        if (created == null || created.isEmpty) return;
                        try {
                          setState(() => _creating = true);
                          final uid = FirebaseAuth.instance.currentUser?.uid;
                          final newRef = await listsCol.add({
                            'name': created,
                            'createdAt': FieldValue.serverTimestamp(),
                            'createdBy': uid,
                          });
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('List "$created" created')));
                          setState(() {
                            _current = newRef;
                            _creating = false;
                          });
                          widget.onChanged(newRef);
                        } catch (e) {
                          if (!mounted) return;
                          setState(() => _creating = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create failed: $e')));
                        }
                      },
                      icon: const Icon(Icons.playlist_add),
                    ),
            ),
          ],
        );
      },
    );
  }
}
