import 'package:material_ui/material_ui.dart';

/// One entry in the adaptive navigation.
class AppDestination {
  const AppDestination({
    required this.label,
    required this.path,
    required this.branchIndex,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final String path;

  /// Index of the [StatefulShellBranch] backing this destination.
  final int branchIndex;

  final IconData icon;
  final IconData activeIcon;
}

// Branch indices are fixed — the router builds branches in this order.
const AppDestination homeDestination = AppDestination(
  label: 'Home',
  path: '/home',
  branchIndex: 0,
  icon: Icons.home_outlined,
  activeIcon: Icons.home_rounded,
);

const AppDestination exploreDestination = AppDestination(
  label: 'Explore',
  path: '/explore',
  branchIndex: 1,
  icon: Icons.search_outlined,
  activeIcon: Icons.search_rounded,
);

const AppDestination libraryDestination = AppDestination(
  label: 'Library',
  path: '/library',
  branchIndex: 2,
  icon: Icons.video_library_outlined,
  activeIcon: Icons.video_library_rounded,
);

const AppDestination profileDestination = AppDestination(
  label: 'Profile',
  path: '/profile',
  branchIndex: 3,
  icon: Icons.person_outline_rounded,
  activeIcon: Icons.person_rounded,
);

const AppDestination historyDestination = AppDestination(
  label: 'History',
  path: '/history',
  branchIndex: 4,
  icon: Icons.history_rounded,
  activeIcon: Icons.history_rounded,
);

const AppDestination settingsDestination = AppDestination(
  label: 'Settings',
  path: '/settings',
  branchIndex: 5,
  icon: Icons.settings_outlined,
  activeIcon: Icons.settings_rounded,
);

/// Four tabs on phones and small windows.
const List<AppDestination> mobileDestinations = <AppDestination>[
  homeDestination,
  exploreDestination,
  libraryDestination,
  profileDestination,
];

/// Five entries in the desktop sidebar (History replaces Profile; Settings is
/// promoted, matching the approved Windows direction).
const List<AppDestination> desktopDestinations = <AppDestination>[
  homeDestination,
  exploreDestination,
  libraryDestination,
  historyDestination,
  settingsDestination,
];

/// Destinations that count as "Profile" for tab highlighting on Android, so
/// Settings and History keep the Profile tab active.
const Set<int> profileFamilyBranches = <int>{3, 4, 5};
