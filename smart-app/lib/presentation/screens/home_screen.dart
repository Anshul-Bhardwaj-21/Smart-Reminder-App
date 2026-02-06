import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/reminder_viewmodel.dart';
import '../widgets/reminder_list_item.dart';
import '../widgets/empty_state_widget.dart';
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
              _buildReminderList(viewModel.pendingReminders),
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
}
