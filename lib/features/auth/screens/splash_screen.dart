import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hipop/blocs/auth/auth_bloc.dart';
import 'package:hipop/blocs/auth/auth_state.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Listen to auth state changes and navigate accordingly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthState();
    });
  }

  void _handleAuthState() {
    final authBloc = context.read<AuthBloc>();
    authBloc.stream.listen((state) {
      if (mounted) {
        if (state is Unauthenticated) {
          context.go('/auth');
        } else if (state is Authenticated) {
          if (state.userType == 'vendor') {
            context.go('/vendor');
          } else {
            context.go('/shopper');
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF558B6E), Color(0xFF6F9686)], // Deep Sage to Soft Sage
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HiPop',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 24),
              CircularProgressIndicator(
                color: Colors.white,
              ),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}