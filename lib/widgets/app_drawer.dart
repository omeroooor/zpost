import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundImage: authProvider.profileImage != null
                      ? MemoryImage(base64Decode(authProvider.profileImage!))
                      : null,
                  child: authProvider.profileImage == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                accountName: Text(authProvider.name ?? 'Anonymous'),
                accountEmail: Text(authProvider.publicKeyHash ?? ''),
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
