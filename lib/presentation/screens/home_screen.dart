import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/enums.dart';
import '../viewmodels/reminder_viewmodel.dart';
import '../widgets/reminder_list_item.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/today_header.dart';
import '../widgets/suggestion_card.dart';
import 'add_reminder_screen.dart';
import 'reminder_detail_screen.dart';
import 'settings_screen.dart';
import '../../data/models/reminder_model.dart';

/// Main home screen showing list of reminders
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Reminder'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.schedule)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
            Tab(text: 'All', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: Consumer<ReminderViewModel>(
        builder: (context, viewModel, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(viewModel.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => viewModel.loadReminders(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(viewModel),
              _buildReminderList(viewModel.completedReminders),
              _buildReminderList(viewModel.reminders),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddReminderScreen()),
          );

          if (result == true) {
            // Reminder added, provider will refresh
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReminderList(List<ReminderModel> reminders) {
    if (reminders.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.event_note,
        message: 'No reminders yet',
        subtitle: 'Tap + to create your first reminder',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ReminderViewModel>().loadReminders();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reminders.length,
        itemBuilder: (context, index) {
          final reminder = reminders[index];
          return ReminderListItem(
            reminder: reminder,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReminderDetailScreen(reminder: reminder),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingTab(ReminderViewModel viewModel) {
    final reminders = viewModel.pendingReminders;
    final nextReminder = _findNextUpcomingReminder(reminders);
    final suggestions = viewModel.suggestions.take(2).toList(growable: false);

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<ReminderViewModel>().loadReminders();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          TodayHeader(nextReminder: nextReminder),
          const SizedBox(height: 16),
          if (suggestions.isNotEmpty) ...[
            ...suggestions.map(
              (suggestion) => SuggestionCard(
                suggestion: suggestion,
                onPrimaryAction: () async {
                  await viewModel.applySuggestion(suggestion);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Suggestion applied')),
                  );
                },
                onDismiss: () => viewModel.dismissSuggestion(suggestion.id),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (reminders.isEmpty)
            const SizedBox(
              height: 360,
              child: EmptyStateWidget(
                icon: Icons.event_note,
                message: 'No reminders yet',
                subtitle: 'Tap + to create your first reminder',
              ),
            )
          else
            ...reminders.map(
              (reminder) => ReminderListItem(
                reminder: reminder,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReminderDetailScreen(reminder: reminder),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  ReminderModel? _findNextUpcomingReminder(List<ReminderModel> reminders) {
    final now = DateTime.now();

    ReminderModel? next;
    DateTime? nextTime;

    for (final reminder in reminders) {
      if (reminder.triggerType != ReminderTriggerType.time) continue;

      final effectiveTime = reminder.snoozedUntil ?? reminder.dateTime;
      if (!effectiveTime.isAfter(now)) continue;

      if (nextTime == null || effectiveTime.isBefore(nextTime)) {
        next = reminder;
        nextTime = effectiveTime;
      }
    }

    return next;
  }
}
