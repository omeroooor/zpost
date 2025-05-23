import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_snackbar.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Post> _posts = [];
  int _currentPage = 1;
  bool _hasMore = true;
  String _sortBy = 'date_desc';
  String? _filter;
  bool _followedOnly = false; // Changed to false to show public posts by default

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      if (_filter != null) {
        setState(() {
          _filter = null;
        });
        _loadPosts(reset: true);
      }
    } else {
      setState(() {
        _filter = _searchController.text;
      });
      _loadPosts(reset: true);
    }
  }

  Future<void> _loadPosts({bool reset = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _posts = [];
        _hasMore = true;
      });
    }

    if (!mounted) return;
    
    setState(() {
      _isLoading = reset;
      _error = null;
    });

    try {
      final results = await ApiService.getFeedPosts(
        page: _currentPage,
        sortBy: _sortBy,
        filter: _filter,
        followedOnly: _followedOnly,
      );
      
      if (!mounted) return;

      final newPosts = (results['posts'] as List)
          .map((post) => Post.fromJson(post as Map<String, dynamic>))
          .toList();

      setState(() {
        if (reset) {
          _posts = newPosts;
        } else {
          _posts.addAll(newPosts);
        }
        _hasMore = results['pagination']['hasMore'] as bool;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading feed posts: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load posts';
          _isLoading = false;
        });
        CustomSnackbar.showError(
          context,
          message: 'Failed to load posts',
        );
      }
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    _currentPage++;
    await _loadPosts();

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _changeSortOrder(String newSortBy) {
    if (_sortBy != newSortBy) {
      setState(() {
        _sortBy = newSortBy;
      });
      _loadPosts(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Z-Post'),
        actions: [
          IconButton(
            icon: Icon(_followedOnly ? Icons.people : Icons.public),
            tooltip: _followedOnly ? 'Show All Posts' : 'Show Following Only',
            onPressed: () {
              setState(() {
                _followedOnly = !_followedOnly;
              });
              _loadPosts(reset: true);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: _changeSortOrder,
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'date_desc',
                child: Text('Recent'),
              ),
              const PopupMenuItem(
                value: 'date_asc',
                child: Text('Oldest'),
              ),
              const PopupMenuItem(
                value: 'rps_desc',
                child: Text('Decreasing RPs'),
              ),
              const PopupMenuItem(
                value: 'rps_asc',
                child: Text('Increasing RPs'),
              ),
            ],
          ),
          // IconButton(
          //   icon: const Icon(Icons.edit_note),
          //   tooltip: 'My Posts',
          //   onPressed: () {
          //     Navigator.pushNamed(context, '/my-posts');
          //   },
          // ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Feed',
            onPressed: () => _loadPosts(reset: true),
          ),
          // IconButton(
          //   icon: const Icon(Icons.logout),
          //   tooltip: 'Logout',
          //   onPressed: () {
          //     context.read<AuthProvider>().logout();
          //   },
          // ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filter != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading && _posts.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _loadPosts(reset: true),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _posts.isEmpty
                        ? const Center(
                            child: Text(
                              'No posts yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadPosts(reset: true),
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: _posts.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == _posts.length) {
                                  return const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                return PostCard(
                                  post: _posts[index],
                                  showActions: false,
                                  showAuthorName: true,
                                  showAuthorImage: true,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-post');
        },
        tooltip: 'Create Post',
        child: const Icon(Icons.add),
      ),
    );
  }
}
