import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/reminder_model.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/text_parser.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/constants/app_constants.dart';
import '../viewmodels/reminder_viewmodel.dart';
import '../widgets/priority_selector_widget.dart';
import '../widgets/recurrence_selector_widget.dart';

/// Screen for adding a new reminder
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customDaysController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Priority _priority = Priority.medium;
  RecurrenceType _recurrence = RecurrenceType.none;
  int? _customRecurrenceDays;

  bool _isSmartInputMode = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Reminder'),
        actions: [
          IconButton(
            icon: Icon(_isSmartInputMode ? Icons.edit : Icons.auto_awesome),
            onPressed: () {
              setState(() {
                _isSmartInputMode = !_isSmartInputMode;
              });
            },
            tooltip: _isSmartInputMode ? 'Manual Mode' : 'Smart Mode',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isSmartInputMode) _buildSmartInput() else _buildManualInput(),
            const SizedBox(height: 24),
            if (_isSaving)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _saveReminder,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Save Reminder'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Input',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Type naturally, like: "Remind me to take medicine every day at 9 AM"',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Remind me to...',
            hintText: 'Remind me to...',
            prefixIcon: Icon(Icons.lightbulb_outline),
          ),
          maxLines: 4,
          maxLength: AppConstants.maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a reminder';
            }
            if (value.trim().length > AppConstants.maxTitleLength) {
              return 'Title too long';
            }
            return null;
          },
          onChanged: (_) => _parseSmartInput(),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            prefixIcon: Icon(Icons.title),
          ),
          maxLength: AppConstants.maxTitleLength,
          textCapitalization: TextCapitalization.sentences,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            if (value.trim().length > AppConstants.maxTitleLength) {
              return 'Title too long';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(
            labelText: 'Description (optional)',
            prefixIcon: Icon(Icons.description),
          ),
          maxLines: 3,
          maxLength: AppConstants.maxDescriptionLength,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Date'),
          subtitle: Text(DateTimeUtils.formatDate(_selectedDate)),
          onTap: _selectDate,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.access_time),
          title: const Text('Time'),
          subtitle: Text(_selectedTime.format(context)),
          onTap: _selectTime,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        const SizedBox(height: 16),
        PrioritySelectorWidget(
          selectedPriority: _priority,
          onChanged: (priority) {
            setState(() {
              _priority = priority;
            });
          },
        ),
        const SizedBox(height: 16),
        RecurrenceSelectorWidget(
          selectedRecurrence: _recurrence,
          onChanged: (recurrence) {
            setState(() {
              _recurrence = recurrence;
              if (_recurrence != RecurrenceType.custom) {
                _customRecurrenceDays = null;
                _customDaysController.clear();
              }
            });
          },
        ),
        if (_recurrence == RecurrenceType.custom) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customDaysController,
            decoration: const InputDecoration(
              labelText: 'Every X days',
              hintText: 'e.g., 3',
              prefixIcon: Icon(Icons.repeat),
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (_recurrence != RecurrenceType.custom) return null;
              final parsed = int.tryParse(value ?? '');
              if (parsed == null || parsed <= 0) {
                return 'Enter a valid number of days';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                _customRecurrenceDays = int.tryParse(value);
              });
            },
          ),
        ],
      ],
    );
  }

  void _parseSmartInput() {
    final input = _titleController.text;
    if (input.isEmpty) return;

    final parsed = TextParser.parseReminderText(input);

    setState(() {
      if (parsed.dateTime != null) {
        _selectedDate = parsed.dateTime!;
        _selectedTime = TimeOfDay.fromDateTime(parsed.dateTime!);
      }
      _priority = parsed.priority;
      _recurrence = parsed.recurrence;
      _customRecurrenceDays = parsed.customRecurrenceDays;
      if (_customRecurrenceDays != null) {
        _customDaysController.text = _customRecurrenceDays.toString();
      }
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      String title = _titleController.text.trim();
      String? description = _descriptionController.text.trim();

      if (_isSmartInputMode) {
        final parsed = TextParser.parseReminderText(title);
        title = parsed.title;
        _priority = parsed.priority;
        _recurrence = parsed.recurrence;
        _customRecurrenceDays = parsed.customRecurrenceDays;
        if (parsed.dateTime != null) {
          _selectedDate = parsed.dateTime!;
          _selectedTime = TimeOfDay.fromDateTime(parsed.dateTime!);
        }
        description = null;
      }

      if (description != null && description.isEmpty) {
        description = null;
      }

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (_recurrence == RecurrenceType.custom && (_customRecurrenceDays == null || _customRecurrenceDays! <= 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid custom recurrence interval')),
          );
        }
        return;
      }

      DateTime effectiveDateTime = dateTime;
      if (effectiveDateTime.isBefore(DateTime.now())) {
        if (_recurrence == RecurrenceType.none) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Select a time in the future')),
            );
          }
          return;
        }

        final next = DateTimeUtils.getNextOccurrenceAfter(
          base: effectiveDateTime,
          recurrence: _recurrence,
          customDays: _customRecurrenceDays,
          after: DateTime.now(),
        );

        if (next == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Unable to schedule next occurrence')),
            );
          }
          return;
        }

        effectiveDateTime = next;
      }

      final reminder = ReminderModel.create(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        description: description,
        dateTime: effectiveDateTime,
        priority: _priority,
        recurrence: _recurrence,
        customRecurrenceDays: _customRecurrenceDays,
      );

      final viewModel = context.read<ReminderViewModel>();
      final success = await viewModel.addReminder(reminder);

      if (success && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder created successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create reminder')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
