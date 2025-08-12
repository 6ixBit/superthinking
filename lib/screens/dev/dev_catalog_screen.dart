import 'package:flutter/material.dart';

class DevCatalogScreen extends StatelessWidget {
  const DevCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_DevItem>[
      _DevItem('Welcome (Onboarding 1/4)', '/'),
      _DevItem('Onboarding Frequency (2/4)', '/onboarding-frequency'),
      _DevItem('Onboarding Focus (3/4)', '/onboarding-focus'),
      _DevItem('Overthinking Time (4/4)', '/overthinking-time'),
      _DevItem('Home', '/home'),
      _DevItem('Login', '/login'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dev: Screen Catalog')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, i) {
          final it = items[i];
          return ListTile(
            title: Text(it.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed(it.route),
          );
        },
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemCount: items.length,
      ),
    );
  }
}

class _DevItem {
  final String title;
  final String route;
  const _DevItem(this.title, this.route);
}
