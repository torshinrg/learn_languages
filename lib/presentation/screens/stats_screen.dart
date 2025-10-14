import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/home_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Consumer<HomeProvider>(
        builder: (ctx, provider, child) {
          return Column(
            children: [
              ListTile(
                title: const Text('Known Words'),
                trailing: Text(provider.knownCount.toString()),
              ),
              ListTile(
                title: const Text('In Progress Words'),
                trailing: Text(provider.inProgressCount.toString()),
              ),
              ListTile(
                title: const Text('New Words'),
                trailing: Text(provider.newWordsCount.toString()),
              ),
            ],
          );
        },
      ),
    );
  }
}