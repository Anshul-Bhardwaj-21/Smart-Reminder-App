# Smart Reminder App v1.0

A production-ready Flutter reminder application with clean architecture, reliable notifications, and offline-first design.

## Features

### Core Functionality
- ✅ Create, edit, and delete reminders
- ✅ Date & time scheduling with date/time pickers
- ✅ Recurring reminders (Daily, Weekly, Monthly, Custom)
- ✅ Priority levels (Low, Medium, High)
- ✅ Snooze functionality (10 minutes default)
- ✅ Completion tracking with status management
- ✅ Smart text input with deterministic parsing

### Smart Text Input
Parse natural language input without fake AI:
- "Remind me to take medicine every day at 9 AM"
- "Meeting tomorrow at 2 PM"
- "Urgent: Submit report on 12/25 at 5 PM"

Extracts:
- Title (cleaned from keywords)
- Date (today, tomorrow, MM/DD/YYYY)
- Time (HH:MM AM/PM, morning, afternoon, evening)
- Recurrence (daily, weekly, monthly)
- Priority (urgent, important, high/low priority)

### Notifications
- ✅ Reliable local notifications using flutter_local_notifications
- ✅ Works when app is closed
- ✅ Survives device reboot (auto-reschedule on app start)
- ✅ Proper notification channels (Android)
- ✅ Permission handling (Android 13+, iOS)
- ✅ Priority-based notification importance

### Data Persistence
- ✅ Offline-first with SharedPreferences
- ✅ No data loss on app restart
- ✅ Migration-safe JSON serialization
- ✅ Proper error handling and logging

### UI/UX
- ✅ Material 3 design
- ✅ Dark/Light theme toggle
- ✅ Calendar view with relative dates (Today, Tomorrow)
- ✅ Empty states with helpful messages
- ✅ Smooth navigation and animations
- ✅ Accessibility-friendly layouts
- ✅ Pull-to-refresh
- ✅ Tab-based organization (Pending, Completed, All)

## Architecture

### Clean MVVM Architecture
```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart      # App-wide constants
│   │   └── enums.dart              # Priority, Recurrence, Status enums
│   ├── utils/
│   │   ├── logger.dart             # Logging utility
│   │   ├── date_time_utils.dart    # Date/time formatting
│   │   └── text_parser.dart        # Natural language parsing
│   ├── services/
│   │   └── notification_service.dart # Notification management
│   └── theme/
│       └── app_theme.dart          # Theme configuration
├── data/
│   ├── models/
│   │   └── reminder_model.dart     # Reminder data model
│   ├── repositories/
│   │   └── reminder_repository.dart # Data access layer
│   └── local/
│       └── local_storage.dart      # SharedPreferences wrapper
├── presentation/
│   ├── screens/
│   │   ├── home_screen.dart        # Main screen
│   │   ├── add_reminder_screen.dart # Create reminder
│   │   ├── reminder_detail_screen.dart # View/edit reminder
│   │   └── settings_screen.dart    # App settings
│   ├── widgets/
│   │   ├── reminder_list_item.dart # Reminder card
│   │   ├── empty_state_widget.dart # Empty state
│   │   ├── priority_selector_widget.dart
│   │   └── recurrence_selector_widget.dart
│   └── viewmodels/
│       ├── reminder_viewmodel.dart # Reminder business logic
│       └── theme_viewmodel.dart    # Theme management
├── main.dart                       # Entry point
└── main_app.dart                   # App widget with DI
```

### State Management
- **Provider** for reactive state management
- ViewModels handle business logic
- Clear separation of concerns
- No UI logic in business layer

### Design Principles
- Offline-first architecture
- Null-safe Dart
- Immutable models
- Repository pattern for data access
- Dependency injection
- Error handling everywhere
- Comprehensive logging

## Technical Stack

### Dependencies
- `provider: ^6.1.1` - State management
- `shared_preferences: ^2.2.2` - Local storage
- `flutter_local_notifications: ^17.0.0` - Notifications
- `timezone: ^0.9.2` - Timezone support
- `flutter_native_timezone: ^2.0.0` - Device timezone
- `intl: ^0.19.0` - Date/time formatting

### Removed Dependencies
Cleaned up unused/problematic dependencies:
- ❌ Firebase (not needed for v1.0)
- ❌ Google Maps (out of scope)
- ❌ TensorFlow/ML Kit (fake AI removed)
- ❌ HTTP (no backend in v1.0)
- ❌ Location services (future feature)

## Getting Started

### Prerequisites
- Flutter 3.0+
- Dart 3.0+
- Android SDK (for Android)
- Xcode (for iOS)

### Installation
```bash
# Get dependencies
flutter pub get

# Run the app
flutter run

# Build release
flutter build apk  # Android
flutter build ios  # iOS
```

### First Run
1. App requests notification permissions
2. Grant permissions for reliable notifications
3. Create your first reminder
4. Notifications will work even when app is closed

## Testing Notifications

### Android
- Notifications work in background
- Survives app kill
- Survives device reboot (reschedules on app start)
- Uses exact alarms for reliability

### iOS
- Notifications work in background
- Proper permission handling
- Badge and sound support

## Quality Assurance

### Error Handling
- Try-catch blocks everywhere
- User-friendly error messages
- Comprehensive logging
- Graceful degradation

### Edge Cases Handled
- Past dates (won't schedule notification)
- Invalid input (validation)
- Storage failures (error messages)
- Permission denial (graceful handling)
- App restart (reschedule notifications)
- Device reboot (reschedule on next app start)

### Code Quality
- Null-safe code
- No dead code
- No unused dependencies
- Consistent naming conventions
- Documented complex logic
- Reusable widgets
- Separation of concerns

## Future Enhancements (Post v1.0)
- Location-based reminders
- Categories/tags
- Search functionality
- Export/import reminders
- Cloud sync
- Widgets
- Wear OS support
- Voice input

## Known Limitations
- No backend (offline only)
- No user authentication
- No cloud sync
- Single device only
- English language only (for smart parsing)

## License
This is a production-ready v1.0 application built with clean architecture principles.

## Contributing
This is a stable v1.0 release. Future contributions should maintain:
- Clean architecture
- Comprehensive error handling
- No fake features
- Production-ready code quality
