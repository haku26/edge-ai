import 'package:edge_ai/providers/navigation_provider.dart';
import 'package:edge_ai/views/home_view.dart';
import 'package:edge_ai/widgets/detector_widget.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class MainView extends ConsumerWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navigationIndex = ref.watch(navigationProvider);

    return MaterialApp(
      title: 'Flutter Navigation with Riverpod',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        body: IndexedStack(
          index: navigationIndex,
          children: [
            HomeView(),
            const DetectorWidget(),
            // const CameraView()],
            HomeView()
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: navigationIndex,
          onTap: (index) {
            ref.read(navigationProvider.notifier).state = index;
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.details),
              label: 'Details',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
