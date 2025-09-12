import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/run_setup_view.dart';
import 'screens/progress_view.dart';
import 'screens/results_view.dart';
import 'screens/settings_view.dart';

void main() {
  runApp(const ProviderScope(child: StudioApp()));
}

class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuditMySite Studio',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const NavigationWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NavigationWrapper extends ConsumerStatefulWidget {
  const NavigationWrapper({super.key});

  @override
  ConsumerState<NavigationWrapper> createState() => _NavigationWrapperState();
}

class _NavigationWrapperState extends ConsumerState<NavigationWrapper> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    RunSetupView(),
    ProgressView(),
    ResultsView(),
    SettingsView(),
  ];
  
  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.play_circle),
      label: 'Setup',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_graph),
      label: 'Progress',
    ),
    NavigationDestination(
      icon: Icon(Icons.list_alt),
      label: 'Results',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final useRail = screenWidth > 800;
    
    return Scaffold(
      body: Row(
        children: [
          if (useRail)
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              elevation: 1,
              labelType: NavigationRailLabelType.all,
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.play_circle_outline),
                  selectedIcon: Icon(Icons.play_circle),
                  label: Text('Setup'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.auto_graph_outlined),
                  selectedIcon: Icon(Icons.auto_graph),
                  label: Text('Progress'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.list_alt_outlined),
                  selectedIcon: Icon(Icons.list_alt),
                  label: Text('Results'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
          Expanded(
            child: _screens[_currentIndex],
          ),
        ],
      ),
      bottomNavigationBar: useRail ? null : NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _destinations,
        elevation: 2,
      ),
    );
  }
}
