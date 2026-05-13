import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/bootstrap.dart';
import 'core/di/injection_container.dart';
import 'core/theme/app_theme.dart';
import 'features/app_shell/presentation/screens/main_shell_screen.dart';
import 'features/app_state/presentation/cubits/app_cubit.dart';
import 'features/transactions/presentation/cubits/transaction_cubit.dart';

class MezanyaApp extends StatelessWidget {
  const MezanyaApp({
    super.key,
    required this.cubit,
    required this.controllers,
  });

  final AppCubit cubit;
  final AppControllers controllers;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppCubit>.value(value: cubit),
        BlocProvider<TransactionCubit>(
          create: (_) => sl<TransactionCubit>()..initialize(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mezanya',
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.tactileManuscript(),
        builder: (context, child) => _PaperAppBackground(child: child),
        home: MainShellScreen(cubit: cubit, controllers: controllers),
      ),
    );
  }
}

class _PaperAppBackground extends StatelessWidget {
  const _PaperAppBackground({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final paper = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: paper,
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFAF4E8),
                  Color(0xFFFFFBF2),
                  Color(0xFFF3E7D4),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PaperGrainPainter(),
            ),
          ),
        ),
        if (child != null) child!,
      ],
    );
  }
}

class _PaperGrainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = const Color(0xFF8B7355).withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final fiberPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.22)
      ..strokeWidth = 0.8;

    for (double y = 7; y < size.height; y += 19) {
      for (double x = 5; x < size.width; x += 23) {
        final offset = ((x * 17 + y * 11) % 9) - 4;
        canvas.drawCircle(Offset(x + offset, y), 0.55, dotPaint);
      }
    }

    for (double y = 16; y < size.height; y += 38) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + ((y % 17) - 8) * 0.18),
        fiberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
