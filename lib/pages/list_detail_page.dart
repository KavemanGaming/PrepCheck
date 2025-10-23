import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ListDetailPage extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> listRef;
  const ListDetailPage({super.key, required this.listRef});

  @override
  Widget build(BuildContext context) {
    final items = listRef.collection('items').orderBy('name').snapshots();
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: items,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return Scaffold(
          appBar: AppBar(title: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: listRef.get(),
            builder: (context, s) => Text(s.data?.data()?['title'] ?? 'List'),
          )),
          body: ListView(
            children: snap.data!.docs.map((doc) {
              final d = doc.data();
              final qty = (d['qtyNeeded'] ?? 0).toString();
              final completed = d['completed'] == true;
              return ListTile(
                title: Text(d['name'] ?? 'Item'),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Qty needed: '),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: qty,
                        keyboardType: TextInputType.number,
                        onFieldSubmitted: (v) async => await doc.reference.update({'qtyNeeded': num.tryParse(v) ?? 0}),
                      ),
                    ),
                  ]),
                  if (completed && d['completedByName'] != null && d['completedAt'] != null)
                    Text('Completed by ${d['completedByName']} at ${d['completedAt'].toDate()}'),
                ]),
                trailing: Checkbox(
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
              );
            }).toList(),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final controller = TextEditingController();
              await showDialog(context: context, builder: (_) => AlertDialog(
                title: const Text('Add item'),
                content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  FilledButton(onPressed: () async {
                    await listRef.collection('items').add({
                      'name': controller.text.trim(),
                      'qtyNeeded': 0,
                      'completed': false,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    // ignore: use_build_context_synchronously
                    Navigator.pop(context);
                  }, child: const Text('Add')),
                ],
              ));
            },
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
