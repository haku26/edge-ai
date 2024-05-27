import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';

class HomeView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(navigationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Screen'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Counter Value: $counter'),
            ElevatedButton(
              onPressed: () {
                ref.read(navigationProvider.notifier).state++;
              },
              child: const Text('Increment Counter'),
            ),
          ],
        ),
      ),
    );
  }
}
