import 'package:flutter/material.dart';
import 'dart:async';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import '../widgets/custom_snackbar.dart';

enum SearchIn { both, content, author }

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Post> _posts = [];
  SearchIn _searchIn = SearchIn.both;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
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
      print('Loading posts: page $_currentPage, reset: $reset');
      final results = await ApiService.searchPosts(
        query: _searchController.text,
        searchIn: _searchIn.name,
        page: _currentPage,
      );
      
      if (!mounted) return;

      final newPosts = (results['posts'] as List)
          .map((post) => Post.fromJson(post))
          .toList();
      
      print('Received ${newPosts.length} posts');
      
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _loadPosts(reset: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search posts...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Search in:'),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Both'),
                        selected: _searchIn == SearchIn.both,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _searchIn = SearchIn.both;
                            });
                            _loadPosts(reset: true);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Content'),
                        selected: _searchIn == SearchIn.content,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _searchIn = SearchIn.content;
                            });
                            _loadPosts(reset: true);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Author'),
                        selected: _searchIn == SearchIn.author,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _searchIn = SearchIn.author;
                            });
                            _loadPosts(reset: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
                              'No posts found',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
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
                              return PostCard(post: _posts[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
