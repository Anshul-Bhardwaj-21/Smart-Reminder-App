import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'presentation/viewmodels/reminder_viewmodel.dart';
import 'presentation/viewmodels/theme_viewmodel.dart';
import 'presentation/screens/home_screen.dart';

/// Main application widget with proper dependency injection
class SmartReminderApp extends StatelessWidget {
  final ReminderViewModel reminderViewModel;
  final ThemeViewModel themeViewModel;

  const SmartReminderApp({
    super.key,
    required this.reminderViewModel,
    required this.themeViewModel,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeViewModel),
        ChangeNotifierProvider.value(value: reminderViewModel),
      ],
      child: Consumer<ThemeViewModel>(
        builder: (context, themeViewModel, _) {
          return MaterialApp(
            title: 'Smart Reminder',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeViewModel.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
