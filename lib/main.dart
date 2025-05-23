import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'providers/post_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/create_post_screen.dart';
import 'screens/drafts_screen.dart';
import 'screens/following_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/edit_post_screen.dart';
import 'screens/user_posts_screen.dart';
import 'services/api_service.dart';
import 'services/key_storage_service.dart';
import 'services/otp_service.dart';
import 'services/deep_link_service.dart';
import 'models/post.dart';
import 'providers/auth_provider.dart';
import 'config/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize OTP service for deep linking
  await OTPService.init();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
  
  runApp(
    MultiProvider(
      providers: [
        Provider<KeyStorageService>(
          create: (_) => KeyStorageService(),
        ),
        ChangeNotifierProvider(
          create: (context) {
            final authProvider = AuthProvider(
              keyStorageService: context.read<KeyStorageService>(),
            );
            ApiService.initialize(authProvider);
            return authProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _deepLinkService = DeepLinkService();
  final _appLinks = AppLinks();
  
  @override
  void initState() {
    super.initState();
    _initializeDeepLinks();
  }
  
  Future<void> _initializeDeepLinks() async {
    // Handle deep links when app is already running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    
    // Handle deep links when app is started from a link
    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }
  }
  
  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: ${uri.toString()}');
    
    // Check if this is a post URL
    if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'posts') {
      _deepLinkService.handlePostDeepLink(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Z-Post',
      debugShowCheckedModeBanner: false,
      navigatorKey: DeepLinkService.navigatorKey,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.themeMode,
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return authProvider.isAuthenticated
              ? const HomeScreen()
              : FutureBuilder(
                  future: authProvider.tryAutoLogin(),
                  builder: (ctx, authResultSnapshot) {
                    if (authResultSnapshot.connectionState == ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }
                    return const LoginScreen();
                  },
                );
        },
      ),
      routes: {
        '/create-post': (context) => const CreatePostScreen(),
        '/drafts': (context) => const DraftsScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/search': (context) => const SearchScreen(),
        '/following': (context) => const FollowingScreen(),
        '/my-posts': (context) => const UserPostsScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/edit-post') {
          final post = settings.arguments as Post;
          return MaterialPageRoute(
            builder: (context) => EditPostScreen(post: post),
          );
        }
        return null;
      },
    );
  }
}
