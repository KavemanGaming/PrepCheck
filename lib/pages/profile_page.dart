import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _uploadAvatar() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    setState(() => _saving = true);
    try {
      final ref = FirebaseStorage.instance.ref('avatars/${u.uid}.jpg');
      await ref.putFile(File(picked.path), SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      await u.updatePhotoURL(url);
      await FirebaseFirestore.instance.doc('users/${u.uid}').set({'photoURL': url}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
        setState(() {});
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return const Center(child: Text('Not signed in'));
    final userDoc = FirebaseFirestore.instance.doc('users/${u.uid}');
    final settingsDoc = FirebaseFirestore.instance.doc('settings/app');

    return StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
      stream: userDoc.snapshots(),
      builder: (context, snap) {
        final userData = snap.data?.data() ?? {};
        final isAdmin = userData['isAdmin'] == true;

        return FutureBuilder<DocumentSnapshot<Map<String,dynamic>>>(
          future: settingsDoc.get(),
          builder: (context, settingsSnap) {
            final settings = settingsSnap.data?.data() ?? {};
            nameCtrl.text = (settings['businessName'] ?? '').toString();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundImage: u.photoURL != null ? NetworkImage(u.photoURL!) : null,
                        child: u.photoURL == null ? const Icon(Icons.person, size: 48) : null,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _uploadAvatar,
                        icon: const Icon(Icons.photo),
                        label: const Text('Change photo'),
                      ),
                      const SizedBox(height: 8),
                      Text(u.displayName ?? u.email ?? 'User', style: Theme.of(context).textTheme.titleMedium),
                      Text(isAdmin ? 'Admin' : 'User', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ListTile(
                  title: const Text('Theme palette'),
                  subtitle: const Text('Choose Teal or Coffee'),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () => userDoc.set({'prefs': {'themePalette':'teal'}}, SetOptions(merge: true)),
                      child: const Text('Teal'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () => userDoc.set({'prefs': {'themePalette':'coffee'}}, SetOptions(merge: true)),
                      child: const Text('Coffee'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: nameCtrl,
                  enabled: isAdmin,
                  decoration: InputDecoration(
                    labelText: 'Business name',
                    helperText: isAdmin ? 'Visible under app title' : 'Admins only',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: isAdmin ? () async {
                      await settingsDoc.set({'businessName': nameCtrl.text.trim()}, SetOptions(merge: true));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business name saved')));
                      }
                    } : null,
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
