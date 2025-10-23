import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'inventory_list_view.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final String? initialText;
  const OrderDetailPage({super.key, required this.orderId, this.initialText});

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  String? _text;
  bool _loading = true;
  String? _listRef;
  Timestamp? _createdAt;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _text = widget.initialText;
      _loading = false;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).get();
      if (doc.exists) {
        final d = doc.data() as Map<String, dynamic>;
        setState(() {
          _text = _text ?? (d['text'] ?? '').toString();
          _listRef = (d['listRef'] ?? '').toString();
          _createdAt = d['createdAt'] as Timestamp?;
          _loading = false;
        });
      } else {
        setState(() { _text = '(order not found)'; _loading = false; });
      }
    } catch (e) {
      setState(() { _text = 'Error: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_listRef != null && _listRef!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('List: $_listRef', style: Theme.of(context).textTheme.labelMedium),
                    ),
                  if (_createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text('Created: ${_createdAt!.toDate().toLocal()}', style: Theme.of(context).textTheme.labelMedium),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(_text ?? '(empty)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.share),
                          label: const Text('Share as text'),
                          onPressed: () => Share.share(_text ?? ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open list'),
                          onPressed: (_listRef == null || _listRef!.isEmpty) ? null : () async {
                            try {
                              final ref = FirebaseFirestore.instance.doc(_listRef!).withConverter<Map<String, dynamic>>(
                                fromFirestore: (s, _) => s.data() ?? <String, dynamic>{},
                                toFirestore: (data, _) => data,
                              );
                              if (!mounted) return;
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => InventoryListViewPage(listRef: ref),
                              ));
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open list: $e')));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy to clipboard'),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _text ?? ''));
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
