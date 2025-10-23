import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../auth/role_stream.dart';
import 'video_player_page.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _textCtrl = TextEditingController();
  String? _chatId;
  Object? _loadError;
  final List<_Attachment> _queue = [];

  @override
  void initState() {
    super.initState();
    _ensureChat();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureChat() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final q = await FirebaseFirestore.instance
          .collection('chats')
          .where('members', arrayContains: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        setState(() { _chatId = q.docs.first.id; _loadError = null; });
        return;
      }
      final ref = await FirebaseFirestore.instance.collection('chats').add({
        'name': 'Team Chat',
        'members': [uid],
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() { _chatId = ref.id; _loadError = null; });
    } catch (e) { setState(() => _loadError = e); }
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    setState(() => _queue.add(_Attachment(File(x.path), 'image')));
  }

  Future<void> _pickVideo() async {
    final v = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 3));
    if (v == null) return;
    setState(() => _queue.add(_Attachment(File(v.path), 'video')));
  }

  String _mimeFromPath(String path, {required String fallback}) {
    final p = path.toLowerCase();
    if (p.endsWith('.jpg') || p.endsWith('.jpeg')) return 'image/jpeg';
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.gif')) return 'image/gif';
    if (p.endsWith('.mp4')) return 'video/mp4';
    if (p.endsWith('.mov')) return 'video/quicktime';
    if (p.endsWith('.mkv')) return 'video/x-matroska';
    return fallback;
  }

  Future<Map<String, String>> _uploadFile(File file, String type) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final chatId = _chatId!;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final name = file.path.split('/').last;
    final storagePath = 'chat_uploads/$chatId/$uid/$ts-$name';
    final contentType = _mimeFromPath(file.path, fallback: type == 'image' ? 'image/jpeg' : 'application/octet-stream');
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    final url = await ref.getDownloadURL();
    return {'url': url, 'storagePath': storagePath, 'contentType': contentType};
  }

  Future<void> _send() async {
    if (_chatId == null) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final msgs = FirebaseFirestore.instance.collection('chats').doc(_chatId).collection('messages');

    final text = _textCtrl.text.trim();
    if (text.isNotEmpty) {
      await msgs.add({
        'type': 'text',
        'text': text,
        'senderId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _textCtrl.clear();
    }

    if (_queue.isNotEmpty) {
      final local = List<_Attachment>.from(_queue);
      _queue.clear();
      if (mounted) setState(() {});
      for (final a in local) {
        try {
          final up = await _uploadFile(a.file, a.type);
          await msgs.add({
            'type': a.type,
            'url': up['url'],
            'storagePath': up['storagePath'],
            'contentType': up['contentType'],
            'senderId': uid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        }
      }
    }
  }

  Future<void> _maybeDelete(DocumentSnapshot<Map<String,dynamic>> doc, Map<String,dynamic> d, bool isMe) async {
    final admin = await Role.isAdminOnce();
    if (!isMe && !admin) return;
    showModalBottomSheet(context: context, builder: (_) {
      return SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete message'),
          onTap: () async {
            Navigator.of(context).pop();
            try {
              await doc.reference.delete();
              final sp = (d['storagePath'] ?? '').toString();
              if (sp.isNotEmpty) {
                try { await FirebaseStorage.instance.ref(sp).delete(); } catch (_) {}
              }
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
            }
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Chat unavailable (permissions).\n\n$_loadError', textAlign: TextAlign.center),
        ),
      );
    }
    if (_chatId == null) return const Center(child: CircularProgressIndicator());

    final stream = FirebaseFirestore.instance
        .collection('chats').doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) return const Center(child: Text('Say hello 👋'));
              return ListView.builder(
                reverse: true,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final d = doc.data();
                  final isMe = d['senderId'] == FirebaseAuth.instance.currentUser?.uid;
                  final type = (d['type'] ?? 'text').toString();
                  return GestureDetector(
                    onLongPress: () => _maybeDelete(doc, d, isMe),
                    child: Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: _bubbleBody(type, d),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_queue.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surface,
            child: Wrap(spacing: 8, runSpacing: 8,
              children: _queue.map((a) => Chip(label: Text('${a.type.toUpperCase()}: ${a.file.path.split('/').last}'))).toList(),
            ),
          ),
        SafeArea(
          child: Row(
            children: [
              IconButton(onPressed: _pickImage, icon: const Icon(Icons.photo)),
              IconButton(onPressed: _pickVideo, icon: const Icon(Icons.videocam)),
              Expanded(child: TextField(controller: _textCtrl, decoration: const InputDecoration(hintText: 'Message...', border: OutlineInputBorder()))),
              const SizedBox(width: 8),
              IconButton(onPressed: _send, icon: const Icon(Icons.send)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bubbleBody(String type, Map<String, dynamic> d) {
    final text = (d['text'] ?? '').toString();

    if (type == 'image' && d['url'] != null) {
      return InkWell(
        onTap: () {
          showDialog(context: context, builder: (_) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: InteractiveViewer(child: Image.network(d['url'], fit: BoxFit.contain)),
          ));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image, size: 20),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 160),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(d['url'], fit: BoxFit.cover),
              ),
            ),
          ],
        ),
      );
    }

    if (type == 'video' && d['url'] != null) {
      return InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => VideoPlayerPage(url: d['url'] as String),
          ));
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.play_circle_fill, size: 22),
            SizedBox(width: 8),
            Text('Play video'),
          ],
        ),
      );
    }

    return Text(text);
  }
}

class _Attachment {
  final File file; final String type;
  _Attachment(this.file, this.type);
}
