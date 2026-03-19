import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/room_lobby_screen.dart';
import 'screens/preference_input_screen.dart';
import 'screens/waiting_screen.dart';
import 'screens/results_screen.dart';
import 'screens/final_result_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return HomeScreen(initialCode: code);
      },
    ),
    GoRoute(
      path: '/lobby/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        final isHost = state.uri.queryParameters['host'] == 'true';
        return RoomLobbyScreen(roomId: roomId, isHost: isHost);
      },
    ),
    GoRoute(
      path: '/input/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return PreferenceInputScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: '/waiting/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return WaitingScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: '/results/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return ResultsScreen(roomId: roomId);
      },
    ),
    GoRoute(
      path: '/final/:roomId',
      builder: (context, state) {
        final roomId = state.pathParameters['roomId']!;
        return FinalResultScreen(roomId: roomId);
      },
    ),
  ],
);
