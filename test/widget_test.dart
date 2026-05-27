import 'package:flutter_test/flutter_test.dart';
import 'package:location_share/main.dart';
import 'package:location_share/providers/auth_controller.dart';
import 'package:location_share/providers/sharing_controller.dart';
import 'package:location_share/services/local_prefs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App builds', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'amap_privacy_ok': true,
      'participant_id': 'test-participant',
      'sharing_enabled': false,
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => SharingController(
              prefs: LocalPrefs(),
              syncRepository: null,
            )..initialize(),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthController(
            )..initialize(),
          ),
        ],
        child: const LocationShareApp(
          firebaseConfigured: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LocationShareApp), findsOneWidget);
  });
}
