import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';

import 'record_session_screen.dart';
import 'sessions_screen.dart';
import 'profile_screen.dart';
import '../theme/app_colors.dart';
import '../state/app_state.dart';

class _NavItem {
  final String label;
  final Icon icon;
  final Icon selectedIcon;
  final Widget Function() builder;
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
  });
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1; // default to Record (middle)
  bool _appliedInitialIndex = false;
  bool _deferEffects = true;

  late final List<_NavItem> _items;
  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    _items = [
      _NavItem(
        label: 'Sessions',
        icon: Icon(CupertinoIcons.list_bullet),
        selectedIcon: Icon(CupertinoIcons.list_bullet_indent),
        builder: () => const SessionsScreen(),
      ),
      _NavItem(
        label: 'SuperThink',
        icon: Icon(CupertinoIcons.mic),
        selectedIcon: Icon(CupertinoIcons.mic_fill),
        builder: () => const RecordSessionScreen(),
      ),
      _NavItem(
        label: 'Profile',
        icon: Icon(CupertinoIcons.person),
        selectedIcon: Icon(CupertinoIcons.person_fill),
        builder: () => const ProfileScreen(),
      ),
    ];
    _pages = List<Widget?>.filled(_items.length, null, growable: false);

    // Avoid heavy blur on first frame to prevent jank, enable right after
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _deferEffects = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedInitialIndex) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is int && args >= 0 && args < 3) {
      _index = args;
    }
    _appliedInitialIndex = true;
  }

  @override
  Widget build(BuildContext context) {
    // Ensure current page is built (lazily)
    _pages[_index] ??= _items[_index].builder();

    final navBar = NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (i) => setState(() {
        // Always clear any open session when interacting with the nav
        context.read<AppState>().setOpenSession(null);
        _index = i;
        // lazily build next page when selected
        _pages[_index] ??= _items[_index].builder();
      }),
      destinations: _items
          .map(
            (e) => NavigationDestination(
              icon: e.icon,
              selectedIcon: e.selectedIcon,
              label: e.label,
            ),
          )
          .toList(growable: false),
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.white.withOpacity(0.12),
      height: 56,
      surfaceTintColor: Colors.transparent,
    );

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(
          _items.length,
          (i) => _pages[i] ?? const SizedBox.shrink(),
          growable: false,
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(left: 12, right: 12, bottom: 5),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: _deferEffects
                ? Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: navBar,
                  )
                : BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: navBar,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
