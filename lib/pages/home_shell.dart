import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/role_stream.dart';
import 'chat_page.dart';
import 'inventory_page.dart';
import 'prep_page.dart';
import 'profile_page.dart';
import 'admin_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _pg = PageController();
  int _index = 0;
  bool _isAdmin = false;
  String _business = '';
  String _palette = 'teal';

  @override
  void initState() {
    super.initState();
    Role.isAdminStream().listen((v) => setState(() => _isAdmin = v));
    FirebaseFirestore.instance.doc('settings/app').snapshots().listen((snap) {
      setState(() => _business = (snap.data()?['businessName'] ?? '').toString());
    });
    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      FirebaseFirestore.instance.doc('users/${u.uid}').snapshots().listen((s) {
        final p = (s.data()?['prefs']?['themePalette'])?.toString();
        if (p == 'coffee' || p == 'teal') setState(() => _palette = p!);
      });
    }
  }

  @override
  void dispose() {
    _pg.dispose();
    super.dispose();
  }

  ColorScheme _schemeOf(BuildContext ctx) {
    final seed = _palette == 'coffee' ? const Color(0xFF6B4F3B) : const Color(0xFF00A6A6);
    final b = Theme.of(ctx).brightness;
    return ColorScheme.fromSeed(seedColor: seed, brightness: b);
  }

  List<_TabSpec> get _tabs {
    final base = <_TabSpec>[
      _TabSpec('Inventory', const Icon(Icons.inventory_2_outlined), InventoryPage()),
      _TabSpec('Prep', const Icon(Icons.fact_check_outlined), PrepPage()),
      _TabSpec('Chat', const Icon(Icons.chat_bubble_outline), ChatPage()),
      _TabSpec('Profile', const Icon(Icons.person_outline), ProfilePage()),
    ];
    if (_isAdmin) {
      base.insert(2, _TabSpec('Admin', const Icon(Icons.admin_panel_settings_outlined), const AdminPage()));
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final themed = Theme.of(context).copyWith(colorScheme: _schemeOf(context));

    return Theme(
      data: themed,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prep Check'),
              if (_business.isNotEmpty)
                Text(_business, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
        body: PageView(
          controller: _pg,
          onPageChanged: (i) => setState(() => _index = i),
          children: tabs.map((t) => t.page).toList(),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            _pg.jumpToPage(i);
          },
          destinations: tabs.map((t) => NavigationDestination(icon: t.icon, label: t.label)).toList(),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final Icon icon;
  final Widget page;
  _TabSpec(this.label, this.icon, this.page);
}
