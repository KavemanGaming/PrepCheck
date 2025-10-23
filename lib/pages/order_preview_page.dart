import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class OrderPreviewPage extends StatelessWidget {
  static const route = '/orderPreview';
  final String? orderId;
  final String? listId;
  const OrderPreviewPage({super.key, this.orderId, this.listId});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final a = (args is Map) ? args : null;
    final oid = orderId ?? a?['orderId'];
    final lid = listId ?? a?['listId'];
    if (oid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Preview')),
        body: const Center(child: Text('Missing order id')),
      );
    }
    final doc = FirebaseFirestore.instance.collection('orders').doc(oid);
    return Scaffold(
      appBar: AppBar(title: const Text('Order Preview')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: doc.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists) return const Center(child: Text('Order not found.'));
          final d = snap.data!.data()!;
          final summary = (d['summary'] ?? '') as String;
          final listId2 = d['listId'] ?? lid;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('List: ${listId2 ?? ''}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(child: Text(summary, style: Theme.of(context).textTheme.bodyLarge)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => Share.share(summary),
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share as text'),
                    ),
                    const SizedBox(width: 12),
                    if (listId2 != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamed('/inventoryList', arguments: {'listId': listId2});
                        },
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Open list'),
                      ),
                  ],
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
