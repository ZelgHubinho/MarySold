import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/auth_controller.dart';
import 'core/constants.dart';
import 'views/login_screen.dart';
import 'views/pos_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedIp = prefs.getString('server_ip');
  if (savedIp != null && savedIp.isNotEmpty) {
    ApiConstants.serverIp = savedIp;
  }
  runApp(const MarySoldApp());
}

class MarySoldApp extends StatefulWidget {
  const MarySoldApp({super.key});

  @override
  State<MarySoldApp> createState() => _MarySoldAppState();
}

class _MarySoldAppState extends State<MarySoldApp> {
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = AuthController();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MarySold POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF1E3C72),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E3C72),
          primary: const Color(0xFF1E3C72),
          secondary: const Color(0xFF2A5298),
          surface: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1E3C72), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
          ),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 4,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      home: ListenableBuilder(
        listenable: _authController,
        builder: (context, _) {
          // If checking initial session, show a clean loader
          if (_authController.isLoading && !_authController.isAuthenticated) {
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF1E3C72)),
                    SizedBox(height: 16),
                    Text(
                      'Cargando MarySold POS...',
                      style: TextStyle(
                        color: Color(0xFF1E3C72),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Route to POS Dashboard or Login Screen
          if (_authController.isAuthenticated) {
            return PosDashboard(authController: _authController);
          } else {
            return LoginScreen(authController: _authController);
          }
        },
      ),
    );
  }
}
