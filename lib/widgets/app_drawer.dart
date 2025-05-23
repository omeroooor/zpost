import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});
  
  // Helper method to handle different types of profile images
  ImageProvider? _getProfileImage(String? imageData) {
    if (imageData == null || imageData.isEmpty) {
      return null;
    }
    
    // Check if the image is a URL
    if (imageData.startsWith('http://') || imageData.startsWith('https://')) {
      return NetworkImage(imageData);
    }
    
    // Try to decode as base64
    try {
      return MemoryImage(base64Decode(imageData));
    } catch (e) {
      debugPrint('Error decoding profile image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      backgroundImage: _getProfileImage(authProvider.profileImage),
                      child: authProvider.profileImage == null
                          ? const Icon(Icons.person, size: 30)
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      authProvider.name ?? 'Anonymous',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      authProvider.publicKeyHash ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  if (ModalRoute.of(context)?.settings.name != '/') {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Search'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/search');
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Following'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/following');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              ListTile(
                leading: const Icon(Icons.library_books),
                title: const Text('My Posts'),
                onTap: () {
                  Navigator.pushNamed(context, '/my-posts');
                },
              ),
              const Divider(),
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) {
                  final isDarkMode = themeProvider.isDarkMode(context);
                  return ListTile(
                    leading: Icon(
                      isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    ),
                    title: Text(isDarkMode ? 'Light Mode' : 'Dark Mode'),
                    trailing: Switch(
                      value: isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeColor: Theme.of(context).colorScheme.primary,
                    ),
                    onTap: () => themeProvider.toggleTheme(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_brightness),
                title: const Text('Use System Theme'),
                onTap: () {
                  Provider.of<ThemeProvider>(context, listen: false).useSystemTheme();
                  Navigator.pop(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
