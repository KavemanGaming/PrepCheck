import 'package:cloud_firestore/cloud_firestore.dart';

class OrderExport {
  static Future<String> buildShoppingListForList(DocumentReference<Map<String, dynamic>> listRef) async {
    final listSnap = await listRef.get();
    final label = (listSnap.data()?['label'] ?? listRef.id).toString();
    final itemsSnap = await listRef.collection('items').orderBy('name').get();

    final lines = <String>[];
    lines.add('Shopping List — $label');
    lines.add('');

    for (final d in itemsSnap.docs) {
      final data = d.data();
      final name = (data['name'] ?? '').toString();
      final par = (data['par'] ?? 0) as int;
      final qoh = (data['qoh'] ?? 0) as int;
      final order = (par - qoh) > 0 ? (par - qoh) : 0;
      if (order > 0) {
        lines.add('- $name x$order');
      }
    }

    if (lines.length <= 2) {
      lines.add('(nothing to order)');
    }
    return lines.join('\n');
  }
}
