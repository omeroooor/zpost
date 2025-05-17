import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_snackbar.dart';

class UserPostsScreen extends StatefulWidget {
  const UserPostsScreen({Key? key}) : super(key: key);

  @override
  State<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends State<UserPostsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Post> _posts = [];
  int _currentPage = 1;
  bool _hasMore = true;
  String _sortBy = 'rps_desc'; // Default sort by reputation points descending
  String? _filter;
  bool _showDrafts = false;

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
      final results = await ApiService.getPaginatedUserPosts(
        page: _currentPage,
        sortBy: _sortBy,
        filter: _filter,
        showDrafts: _showDrafts,
      );
      
      if (!mounted) return;

      final newPosts = (results['posts'] as List)
          .map((post) => Post.fromJson(post))
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
      print('Error loading posts: $e');
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
        title: const Text('My Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create Post',
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/create-post',
              ).then((_) => _loadPosts(reset: true));
            },
          ),
          IconButton(
            icon: Icon(_showDrafts ? Icons.visibility_off : Icons.visibility),
            tooltip: _showDrafts ? 'Show All Posts' : 'Show Drafts Only',
            onPressed: () {
              setState(() {
                _showDrafts = !_showDrafts;
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
                value: 'rps_desc',
                child: Text('Decreasing RPs'),
              ),
              const PopupMenuItem(
                value: 'rps_asc',
                child: Text('Increasing RPs'),
              ),
              const PopupMenuItem(
                value: 'date_desc',
                child: Text('Recent'),
              ),
              const PopupMenuItem(
                value: 'date_asc',
                child: Text('Oldest'),
              ),
            ],
          ),
        ],
      ),
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
                                  showActions: _posts[index].reputationPoints == 0,
                                  showAuthorName: false,
                                  showAuthorImage: false,
                                  onEdit: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/edit-post',
                                      arguments: _posts[index],
                                    ).then((_) => _loadPosts(reset: true));
                                  },
                                  onDelete: () async {
                                    try {
                                      await ApiService.deletePost(_posts[index].id);
                                      _loadPosts(reset: true);
                                      if (mounted) {
                                        CustomSnackbar.show(
                                          context,
                                          message: 'Post deleted successfully',
                                          type: SnackbarType.success,
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        CustomSnackbar.show(
                                          context,
                                          message: 'Failed to delete post',
                                          type: SnackbarType.error,
                                        );
                                      }
                                    }
                                  },
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
