import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:spendkit_ui/spendkit_ui.dart';

import 'core.dart';
import 'screens.dart';

final _startupProvider = FutureProvider<void>(
  (ref) => ref.read(sessionProvider).load(),
);

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.read(sessionProvider);
  final router = GoRouter(
    refreshListenable: session,
    redirect: (_, state) {
      final signingIn = state.matchedLocation == '/sign-in';
      if (!session.signedIn) return signingIn ? null : '/sign-in';
      return signingIn ? '/' : null;
    },
    routes: [
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/activity',
                builder: (_, _) => const ActivityScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/card',
                builder: (_, _) => const CardScreen(),
                routes: [
                  GoRoute(
                    path: 'simulator',
                    builder: (_, _) => const CardSimulatorScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'gallery',
                    builder: (_, _) => const GalleryScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: SpendButton(
          label: 'Back to home',
          onPressed: () => context.go('/'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  return router;
});

class SpendKitApp extends ConsumerWidget {
  const SpendKitApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(_startupProvider);
    final session = ref.watch(sessionProvider);
    final theme = SpendTheme.build(
      session.darkMode ? Brightness.dark : Brightness.light,
      highContrast: session.highContrast,
    );
    return startup.when(
      data: (_) => MaterialApp.router(
        title: 'SpendKit',
        debugShowCheckedModeBanner: false,
        theme: theme,
        routerConfig: ref.watch(routerProvider),
      ),
      loading: () => MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              semanticsLabel: 'Loading SpendKit',
            ),
          ),
        ),
      ),
      error: (_, _) => MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SpendPanel(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SpendNotice(
                    message: 'SpendKit could not read your settings.',
                    error: true,
                  ),
                  const SizedBox(height: SpendSpace.medium),
                  SpendButton(
                    label: 'Try again',
                    onPressed: () => ref.invalidate(_startupProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.space_dashboard_outlined),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        label: 'Activity',
      ),
      NavigationDestination(
        icon: Icon(Icons.credit_card_outlined),
        label: 'Card',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ];
    void select(int index) =>
        shell.goBranch(index, initialLocation: index == shell.currentIndex);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= 850;
    return Scaffold(
      body: SafeArea(
        bottom: useRail,
        child: Row(
          children: [
            if (useRail)
              NavigationRail(
                extended: width >= 1100,
                labelType: width >= 1100
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                selectedIndex: shell.currentIndex,
                onDestinationSelected: select,
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: destination.icon,
                      label: Text(destination.label),
                    ),
                ],
              ),
            if (useRail) const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              destinations: destinations,
            ),
    );
  }
}
