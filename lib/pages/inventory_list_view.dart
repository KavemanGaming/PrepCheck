import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InventoryListViewPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const InventoryListViewPage({super.key, required this.listRef});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory list')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: listRef.snapshots(),
        builder: (context, listSnap) {
          if (listSnap.hasError) return Center(child: Text('Error: ${listSnap.error}'));
          if (!listSnap.hasData) return const Center(child: CircularProgressIndicator());
          final label = (listSnap.data!.data()?['label'] ?? listRef.id).toString();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt_outlined),
                    const SizedBox(width: 8),
                    Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: listRef.collection('items').orderBy('name').snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) return const Center(child: Text('No items in this list.'));
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, i) {
                        final ref = docs[i].reference;
                        final d = docs[i].data();
                        final name = (d['name'] ?? '').toString();
                        final par  = (d['par'] ?? 0) as int;
                        final qoh  = (d['qoh'] ?? 0) as int;
                        final order = (par - qoh) > 0 ? (par - qoh) : 0;
                        final danger = par > 0 && qoh < par * 0.5;
                        final warn   = par > 0 && qoh < par;
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
                          tileColor: danger ? Colors.red.withOpacity(0.05)
                                            : (warn ? Colors.orange.withOpacity(0.05) : null),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
