# Quick Start Guide - Smart Reminder App v1.0

## Setup (5 minutes)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run the App
```bash
# Debug mode
flutter run

# Release mode
flutter run --release
```

### 3. Build for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## Project Structure

```
lib/
├── core/                    # Core functionality
│   ├── constants/          # App constants and enums
│   ├── utils/              # Utilities (logger, parser, date)
│   ├── services/           # Services (notifications)
│   └── theme/              # App theme
├── data/                    # Data layer
│   ├── models/             # Data models
│   ├── repositories/       # Data access
│   └── local/              # Local storage
├── presentation/            # UI layer
│   ├── viewmodels/         # Business logic
│   ├── screens/            # App screens
│   └── widgets/            # Reusable widgets
├── main.dart               # Entry point
└── main_app.dart           # App widget
```

## Key Files to Know

### Entry Point
- `lib/main.dart` - App initialization

### Core Services
- `lib/core/services/notification_service.dart` - Notification management
- `lib/core/utils/text_parser.dart` - Smart text parsing

### Data Layer
- `lib/data/models/reminder_model.dart` - Reminder data model
- `lib/data/repositories/reminder_repository.dart` - Data operations

### ViewModels
- `lib/presentation/viewmodels/reminder_viewmodel.dart` - Reminder logic
- `lib/presentation/viewmodels/theme_viewmodel.dart` - Theme management

### Main Screens
- `lib/presentation/screens/home_screen.dart` - Main screen
- `lib/presentation/screens/add_reminder_screen.dart` - Create reminder
- `lib/presentation/screens/reminder_detail_screen.dart` - View/edit reminder

## Common Tasks

### Add a New Feature

1. **Add to Model** (if needed)
```dart
// lib/data/models/reminder_model.dart
class ReminderModel {
  final String newField;
  // Add to constructor, toJson, fromJson, copyWith
}
```

2. **Add to Repository**
```dart
// lib/data/repositories/reminder_repository.dart
Future<bool> newOperation() async {
  try {
    // Implementation
    return true;
  } catch (e) {
    Logger.error('Failed', e);
    return false;
  }
}
```

3. **Add to ViewModel**
```dart
// lib/presentation/viewmodels/reminder_viewmodel.dart
Future<void> newFeature() async {
  _clearError();
  try {
    await _repository.newOperation();
    notifyListeners();
  } catch (e) {
    _setError('Failed');
  }
}
```

4. **Update UI**
```dart
// lib/presentation/screens/...
Consumer<ReminderViewModel>(
  builder: (context, viewModel, _) {
    // Use viewModel.newFeature()
  },
)
```

### Debug Issues

1. **Check Logs**
```dart
Logger.debug('Message', 'Tag');
Logger.error('Error', error, stackTrace, 'Tag');
```

2. **Check State**
```dart
// In ViewModel
print('Reminders: ${_reminders.length}');
print('Loading: $_isLoading');
print('Error: $_error');
```

3. **Check Storage**
```dart
// In Repository
final data = await _localStorage.getJsonList(key);
print('Stored data: $data');
```

### Test Notifications

1. **Schedule a reminder for 1 minute from now**
2. **Close the app completely**
3. **Wait for notification**
4. **Verify it appears**

### Change Theme

```dart
// In settings or anywhere
context.read<ThemeViewModel>().toggleTheme();
```

## Smart Text Input Examples

Try these in the app:

```
"Remind me to take medicine every day at 9 AM"
"Meeting tomorrow at 2 PM"
"Urgent: Submit report on 12/25 at 5 PM"
"Call mom tonight"
"Gym every week at 6 AM"
"Pay bills on 1/1 at 10 AM"
```

## Troubleshooting

### Notifications Not Working

**Android:**
1. Check permissions in Settings
2. Verify notification channel is created
3. Check battery optimization settings
4. Ensure exact alarms are allowed

**iOS:**
1. Check notification permissions
2. Verify app is not in Low Power Mode
3. Check notification settings

### Data Not Persisting

1. Check SharedPreferences initialization
2. Verify JSON serialization
3. Check error logs
4. Ensure proper error handling

### Build Errors

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Lint Warnings

```bash
# Analyze code
flutter analyze

# Fix formatting
dart format lib/
```

## Performance Tips

1. **Use const constructors** where possible
2. **Dispose controllers** in StatefulWidgets
3. **Use Consumer** for targeted rebuilds
4. **Avoid rebuilding entire tree**
5. **Profile with DevTools**

## Best Practices

### DO ✅
- Follow MVVM architecture
- Handle all errors
- Use Logger for debugging
- Validate user input
- Write clear comments
- Use constants for values
- Dispose resources properly

### DON'T ❌
- Put business logic in UI
- Access storage directly from UI
- Ignore errors
- Use print() instead of Logger
- Create multiple service instances
- Hardcode strings/values
- Skip input validation

## Useful Commands

```bash
# Get dependencies
flutter pub get

# Run app
flutter run

# Run on specific device
flutter run -d <device-id>

# Build release
flutter build apk --release

# Analyze code
flutter analyze

# Format code
dart format lib/

# Clean project
flutter clean

# List devices
flutter devices

# Check Flutter doctor
flutter doctor
```

## Resources

- **README.md** - Full documentation
- **CHANGELOG.md** - Version history
- **IMPLEMENTATION_GUIDE.md** - Architecture details
- **UPGRADE_SUMMARY.md** - What was changed

## Support

For issues or questions:
1. Check the documentation
2. Review the implementation guide
3. Check error logs
4. Review the code comments

## Next Steps

1. ✅ Run the app
2. ✅ Create a reminder
3. ✅ Test notifications
4. ✅ Explore the code
5. ✅ Read the documentation
6. ✅ Start building!

---

**Happy Coding! 🚀**
