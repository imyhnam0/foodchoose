import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'router.dart';
import 'utils/deep_link_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FoodChooseApp());
}

class FoodChooseApp extends StatefulWidget {
  const FoodChooseApp({super.key});

  @override
  State<FoodChooseApp> createState() => _FoodChooseAppState();
}

class _FoodChooseAppState extends State<FoodChooseApp> {
  final _deepLinkHandler = DeepLinkHandler();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() async {
    final initialCode = await _deepLinkHandler.getInitialCode();
    if (initialCode != null) {
      appRouter.go('/?code=$initialCode');
    }

    _deepLinkHandler.onDeepLink.listen((code) {
      if (code != null) {
        appRouter.go('/?code=$code');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '골라음식',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE85D04)),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
