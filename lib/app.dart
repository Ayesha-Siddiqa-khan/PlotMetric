import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/models/calculation.dart';
import 'features/calculator/presentation/calculator_screen.dart';
import 'features/dimensions/presentation/dimension_screen.dart';
import 'features/land/presentation/land_screen.dart';
import 'features/land/state/land_controller.dart';
import 'features/records/presentation/records_screen.dart';
import 'features/scan/presentation/scan_screen.dart';
import 'features/settings/presentation/settings_screen.dart';

class PlotMetricApp extends StatelessWidget {
  const PlotMetricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlotMetric',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RootNavigationShell(),
    );
  }
}

class RootNavigationShell extends ConsumerStatefulWidget {
  const RootNavigationShell({super.key});

  @override
  ConsumerState<RootNavigationShell> createState() => _RootNavigationShellState();
}

class _RootNavigationShellState extends ConsumerState<RootNavigationShell> {
  int _currentIndex = 0;
  final _tabHistory = <int>[];

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _tabHistory.add(_currentIndex);
      _currentIndex = index;
    });
  }

  void _onOpenCalculation(Calculation calc) {
    final landCtrl = ref.read(landControllerProvider);
    landCtrl.loadCalculation(calc);
    _onTabSelected(0);
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop || _tabHistory.isEmpty) return;
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _currentIndex = _tabHistory.removeLast());
    },
    child: _buildNavigation(context),
  );

  Widget _buildNavigation(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;

    final screens = [
      LandScreen(
        onNavigateToRecords: () => _onTabSelected(3),
        onNavigateToDimensions: () => _onTabSelected(1),
        onNavigateToSettings: () => _onTabSelected(5),
      ),
      DimensionScreen(
        onNavigateToLand: () => _onTabSelected(0),
        isActive: _currentIndex == 1,
      ),
      const CalculatorScreen(),
      RecordsScreen(
        onOpenCalculation: _onOpenCalculation,
        onNavigateToSettings: () => _onTabSelected(5),
        isActive: _currentIndex == 3,
      ),
      ScanScreen(onNavigateToLand: () => _onTabSelected(0)),
      SettingsScreen(
        onDataCleared: () {
          ref.read(landControllerProvider).clearToNew();
        },
      ),
    ];

    if (isDesktop) {
      // Desktop / Web Wide Layout with NavigationRail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              backgroundColor: AppTheme.primaryNavy,
              selectedIconTheme: const IconThemeData(color: Colors.white),
              unselectedIconTheme: const IconThemeData(color: Colors.white60),
              selectedLabelTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              unselectedLabelTextStyle: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
              useIndicator: true,
              indicatorColor: AppTheme.accentTeal,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(Icons.straighten, color: Colors.white, size: 28),
                    SizedBox(height: 6),
                    Text(
                      'PlotMetric',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.square_foot_outlined),
                  selectedIcon: Icon(Icons.square_foot),
                  label: Text('Land'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.architecture_outlined),
                  selectedIcon: Icon(Icons.architecture),
                  label: Text('Dimensions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.calculate_outlined),
                  selectedIcon: Icon(Icons.calculate),
                  label: Text('Calculator'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: Text('Records'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  selectedIcon: Icon(Icons.document_scanner),
                  label: Text('Scan'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1, color: AppTheme.dividerColor),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Tablet Narrow Layout with Persistent BottomNavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.square_foot_outlined),
            activeIcon: Icon(Icons.square_foot),
            label: 'Land',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.architecture_outlined),
            activeIcon: Icon(Icons.architecture),
            label: 'Dimensions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate_outlined),
            activeIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.document_scanner_outlined),
            activeIcon: Icon(Icons.document_scanner),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
