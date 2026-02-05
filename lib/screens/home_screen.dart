import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/heart_painter.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String _userName = '';
  late AnimationController _fillController;
  late Animation<double> _fillAnimation;
  int _currentDrop = 0;
  final int _totalDrops = 12;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _setupAnimation();
    _scheduleNotification();
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? 'human';
    });
  }

  void _setupAnimation() {
    _fillController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _fillAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fillController, curve: Curves.easeIn),
    );

    _startDropAnimation();
  }

  void _startDropAnimation() {
    _currentDrop = 0;
    _animateNextDrop();
  }

  void _animateNextDrop() {
    if (_currentDrop >= _totalDrops) {
      // Full - pause then drain
      Future.delayed(const Duration(milliseconds: 2500), () {
        _fillController.reverse().then((_) {
          Future.delayed(const Duration(milliseconds: 2000), () {
            _startDropAnimation();
          });
        });
      });
      return;
    }

    _currentDrop++;
    final targetFill = _currentDrop / _totalDrops;

    _fillController.animateTo(targetFill).then((_) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        _animateNextDrop();
      });
    });
  }

  Future<void> _scheduleNotification() async {
    await NotificationService().scheduleInactivityNotification();
  }

  @override
  void dispose() {
    _fillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated heart
              AnimatedBuilder(
                animation: _fillAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    size: const Size(150, 150),
                    painter: HeartPainter(fillAmount: _fillAnimation.value),
                  );
                },
              ),

              const SizedBox(height: 50),

              // Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  '$_userName, you seem to be alive',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 3,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
