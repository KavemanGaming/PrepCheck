import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/time_helper.dart';
import '../services/roles.dart';

class PrepListDetailPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const PrepListDetailPage({super.key, required this.listRef});

  @override
  Widget build(BuildContext context) {
    final items = listRef.collection('items').orderBy('name').snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: items,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final docs = snap.data!.docs;
        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: listRef.get(),
              builder: (context, s) => Text(s.data?.data()?['title'] ?? 'Prep List'),
            ),
          ),
          body: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final d = doc.data();
              final qty = (d['qtyNeeded'] ?? 0).toString();
              final completed = d['completed'] == true;
              final when = formatETFromTimestamp(d['completedAt']);
              return Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: completed,
                        onChanged: (v) async {
                          final user = FirebaseAuth.instance.currentUser!;
                          if (v == true) {
                            await doc.reference.update({
                              'completed': true,
                              'completedBy': user.uid,
                              'completedByName': user.displayName ?? user.email,
                              'completedAt': FieldValue.serverTimestamp(),
                            });
                          } else {
                            await doc.reference.update({
                              'completed': false,
                              'completedBy': null,
                              'completedByName': null,
                              'completedAt': null,
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['name'] ?? 'Item', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Text('Qty needed:'),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: qty,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                                    onFieldSubmitted: (v) async => await doc.reference.update({'qtyNeeded': num.tryParse(v) ?? 0}),
                                  ),
                                ),
                              ],
                            ),
                            if (completed && d['completedByName'] != null && d['completedAt'] != null) ...[
                              const SizedBox(height: 6),
                              Text('Completed by ${d['completedByName']} at $when', style: Theme.of(context).textTheme.bodySmall),
                            ]
                          ],
                        ),
                      ),
                      _AdminDelete(itemRef: doc.reference),
                    ],
                  ),
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final controller = TextEditingController();
              final qtyC = TextEditingController(text: '0');
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Add prep item'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 8),
                    TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty needed')),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    FilledButton(
                      onPressed: () async {
                        await listRef.collection('items').add({
                          'name': controller.text.trim(),
                          'qtyNeeded': num.tryParse(qtyC.text) ?? 0,
                          'completed': false,
                          'createdAt': FieldValue.serverTimestamp(),
                        });
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}

class _AdminDelete extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> itemRef;
  const _AdminDelete({required this.itemRef});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: loadAdminClaim(),
      builder: (context, s) {
        if (s.data == true) {
          return IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async => await itemRef.delete(),
            tooltip: 'Delete item',
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
