import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chats = FirebaseFirestore.instance
        .collection('chats')
        .where('members', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chats,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No chats yet'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Group'),
                  onPressed: () => _createGroup(context),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Start DM (enter UID)'),
                  onPressed: () => _startDm(context),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final title = d['type'] == 'dm' ? (d['name'] ?? 'DM') : (d['name'] ?? 'Group');
              return ListTile(
                title: Text(title),
                subtitle: Text((d['type'] ?? 'group').toString().toUpperCase()),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatPage(chatRef: docs[i].reference))),
              );
            },
          ),
          floatingActionButton: PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              if (v == 'dm') {
                await _startDm(context);
              } else {
                await _createGroup(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'dm', child: Text('Start DM (enter UID)')),
              PopupMenuItem(value: 'group', child: Text('New Group')),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createGroup(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New group name'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final me = FirebaseAuth.instance.currentUser!;
              await FirebaseFirestore.instance.collection('chats').add({
                'type': 'group',
                'name': controller.text.trim().isEmpty ? 'Group' : controller.text.trim(),
                'members': [me.uid],
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _startDm(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start DM with user uid'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'User UID')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final other = controller.text.trim();
              if (other.isEmpty) return;
              final me = FirebaseAuth.instance.currentUser!;
              await FirebaseFirestore.instance.collection('chats').add({
                'type': 'dm',
                'name': 'DM',
                'members': [me.uid, other],
                'createdAt': FieldValue.serverTimestamp(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
