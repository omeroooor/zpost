import 'package:flutter/material.dart';
import '../models/author.dart';
import '../services/api_service.dart';

class FollowingScreen extends StatefulWidget {
  const FollowingScreen({super.key});

  @override
  State<FollowingScreen> createState() => _FollowingScreenState();
}

class _FollowingScreenState extends State<FollowingScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Author> _following = [];
  List<Author> _filteredFollowing = [];
  bool _isLoading = false;
  String? _error;
  bool _needsProfile = false;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current profile to create it if it doesn't exist
      await ApiService.getCurrentProfile();
      
      // After profile is created, load following
      await _loadFollowing();
      
      setState(() {
        _needsProfile = false;
      });
    } catch (e) {
      print('Error creating profile: $e');
      setState(() => _error = 'Failed to create profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFollowing() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('Loading following list...');
      final following = await ApiService.getFollowing();
      print('Received following data: $following');
      
      if (following.isEmpty) {
        print('Following list is empty');
      }
      
      setState(() {
        _following = following.map((f) {
          print('Processing following item: $f');
          return Author.fromJson(f);
        }).toList();
        _filterFollowing();
        _needsProfile = false;
      });
    } catch (e, stackTrace) {
      print('Error loading following: $e');
      print('Stack trace: $stackTrace');
      
      if (e.toString().contains('Profile not found')) {
        setState(() {
          _needsProfile = true;
          _error = null;
        });
      } else {
        setState(() {
          _needsProfile = false;
          _error = e.toString();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterFollowing() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFollowing = _following.where((author) {
        final name = author.name?.toLowerCase() ?? '';
        final publicKeyHash = author.publicKeyHash.toLowerCase();
        return name.contains(query) || publicKeyHash.contains(query);
      }).toList();
    });
  }

  Future<void> _unfollowUser(Author author) async {
    try {
      await ApiService.unfollowUser(author.publicKeyHash);
      setState(() {
        _following.removeWhere((f) => f.publicKeyHash == author.publicKeyHash);
        _filterFollowing();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unfollowed ${author.name ?? 'user'}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unfollowing user: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Following'),
      ),
      body: Column(
        children: [
          if (!_needsProfile) Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or public key',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (_) => _filterFollowing(),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _needsProfile
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'You need to create a profile first',
                              style: TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _createProfile,
                              child: const Text('Create Profile'),
                            ),
                          ],
                        ),
                      )
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadFollowing,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredFollowing.isEmpty
                            ? const Center(
                                child: Text(
                                  'No users found',
                                  style: TextStyle(fontSize: 16),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadFollowing,
                                child: ListView.builder(
                                  itemCount: _filteredFollowing.length,
                                  itemBuilder: (context, index) {
                                    final author = _filteredFollowing[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        child: Text(
                                          (author.name?.isNotEmpty ?? false)
                                              ? author.name![0].toUpperCase()
                                              : 'A',
                                        ),
                                      ),
                                      title: Text(author.name ?? 'Anonymous'),
                                      subtitle: Text(
                                        author.publicKeyHash,
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.person_remove),
                                        onPressed: () => _unfollowUser(author),
                                      ),
                                    );
                                  },
                                ),
                              ),
          ),
        ],
      ),
    );
  }
}
