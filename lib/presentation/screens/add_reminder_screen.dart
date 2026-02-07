import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../data/models/reminder_model.dart';
import '../../core/constants/enums.dart';
import '../../core/utils/text_parser.dart';
import '../../core/utils/date_time_utils.dart';
import '../../core/constants/app_constants.dart';
import '../../core/location/geofence_service.dart';
import '../../core/voice/speech_service.dart';
import '../viewmodels/reminder_viewmodel.dart';
import '../widgets/priority_selector_widget.dart';
import '../widgets/recurrence_selector_widget.dart';
import '../widgets/listening_waveform.dart';
import 'map_picker_screen.dart';

/// Screen for adding a new reminder
class AddReminderScreen extends StatefulWidget {
  const AddReminderScreen({super.key});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _smartInputController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customDaysController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  Priority _priority = Priority.medium;
  RecurrenceType _recurrence = RecurrenceType.none;
  int? _customRecurrenceDays;
  ReminderTriggerType _triggerType = ReminderTriggerType.time;
  String? _parsedLocationName;
  ReminderLocation? _selectedLocation;

  bool _isSmartInputMode = true;
  bool _autoApplySmartParse = true;
  bool _smartTitleManuallyEdited = false;
  bool _isSaving = false;

  late final SpeechService _speechService;

  @override
  void initState() {
    super.initState();
    _speechService = SpeechService();
    _speechService.transcript.addListener(_onSpeechTranscriptChanged);
  }

  @override
  void dispose() {
    _smartInputController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _customDaysController.dispose();
    _speechService.cancel();
    _speechService.dispose();
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
                final nextSmartMode = !_isSmartInputMode;
                setState(() {
                  _isSmartInputMode = nextSmartMode;
                  if (nextSmartMode) {
                    _autoApplySmartParse = true;
                    _smartTitleManuallyEdited = false;
                    _parseSmartInput();
                  }
                });

                if (!nextSmartMode) {
                  _speechService.stopListening();
                }
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
        ValueListenableBuilder<bool>(
          valueListenable: _speechService.isListening,
          builder: (context, isListening, _) {
            return TextFormField(
              controller: _smartInputController,
              decoration: InputDecoration(
                labelText: 'Say or type…',
                hintText: 'e.g., "Remind me to take medicine every day at 9 AM"',
                prefixIcon: const Icon(Icons.lightbulb_outline),
                suffixIcon: IconButton(
                  icon: Icon(isListening ? Icons.stop_circle : Icons.mic),
                  tooltip: isListening ? 'Stop listening' : 'Voice input',
                  onPressed: _toggleListening,
                ),
              ),
              maxLines: 4,
              maxLength: AppConstants.maxDescriptionLength,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (!_isSmartInputMode) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a reminder';
                }
                if (value.trim().length > AppConstants.maxDescriptionLength) {
                  return 'Input too long';
                }
                return null;
              },
              onChanged: (_) => _parseSmartInput(),
            );
          },
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<bool>(
          valueListenable: _speechService.isListening,
          builder: (context, isListening, _) {
            if (!isListening) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ListeningWaveform(color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Listening…',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<String>(
                  valueListenable: _speechService.transcript,
                  builder: (context, transcript, _) {
                    return Text(
                      transcript.isEmpty ? 'Start speaking' : transcript,
                      style: Theme.of(context).textTheme.bodyMedium,
                    );
                  },
                ),
              ],
            );
          },
        ),
        ValueListenableBuilder<String?>(
          valueListenable: _speechService.errorMessage,
          builder: (context, error, _) {
            if (error == null || error.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                error,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildParsedPreview(),
      ],
    );
  }

  Widget _buildParsedPreview() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Parsed Details',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _autoApplySmartParse = true;
                      _smartTitleManuallyEdited = false;
                      _parseSmartInput();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Re-parse'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title',
                prefixIcon: const Icon(Icons.title),
                suffixIcon: _smartTitleManuallyEdited
                    ? IconButton(
                        tooltip: 'Reset from smart input',
                        icon: const Icon(Icons.link),
                        onPressed: () {
                          setState(() {
                            _smartTitleManuallyEdited = false;
                            _parseSmartInput();
                          });
                        },
                      )
                    : null,
              ),
              maxLength: AppConstants.maxTitleLength,
              textCapitalization: TextCapitalization.sentences,
              validator: (value) {
                if (!_isSmartInputMode) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.trim().length > AppConstants.maxTitleLength) {
                  return 'Title too long';
                }
                return null;
              },
              onChanged: (_) {
                if (!_smartTitleManuallyEdited) {
                  setState(() {
                    _smartTitleManuallyEdited = true;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            if (_triggerType == ReminderTriggerType.time) ...[
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Date'),
                subtitle: Text(DateTimeUtils.formatDate(_selectedDate)),
                onTap: () async {
                  setState(() {
                    _autoApplySmartParse = false;
                  });
                  await _selectDate();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Time'),
                subtitle: Text(_selectedTime.format(context)),
                onTap: () async {
                  setState(() {
                    _autoApplySmartParse = false;
                  });
                  await _selectTime();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<ReminderTriggerType>(
                      segments: const [
                        ButtonSegment(
                          value: ReminderTriggerType.locationEnter,
                          label: Text('Enter'),
                          icon: Icon(Icons.login),
                        ),
                        ButtonSegment(
                          value: ReminderTriggerType.locationExit,
                          label: Text('Exit'),
                          icon: Icon(Icons.logout),
                        ),
                      ],
                      selected: {_triggerType},
                      onSelectionChanged: (selection) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _autoApplySmartParse = false;
                          _triggerType = selection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.place),
                title: const Text('Location'),
                subtitle: Text(
                  _selectedLocation != null
                      ? '${_selectedLocation!.name} • ${_selectedLocation!.radiusMeters.round()} m'
                      : (_parsedLocationName ?? 'Tap to pick on map'),
                ),
                trailing: const Icon(Icons.map),
                onTap: _pickLocationOnMap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              const SizedBox(height: 12),
            ],
            PrioritySelectorWidget(
              selectedPriority: _priority,
              onChanged: (priority) {
                HapticFeedback.selectionClick();
                setState(() {
                  _autoApplySmartParse = false;
                  _priority = priority;
                });
              },
            ),
            if (_triggerType == ReminderTriggerType.time) ...[
              const SizedBox(height: 12),
              RecurrenceSelectorWidget(
                selectedRecurrence: _recurrence,
                onChanged: (recurrence) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _autoApplySmartParse = false;
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
                      _autoApplySmartParse = false;
                      _customRecurrenceDays = int.tryParse(value);
                    });
                  },
                ),
              ],
            ],
          ],
        ),
      ),
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
    if (!_isSmartInputMode) return;

    final input = _smartInputController.text.trim();
    if (input.isEmpty) return;

    final parsed = TextParser.parseReminderText(input);

    setState(() {
      if (!_smartTitleManuallyEdited) {
        _titleController.text = parsed.title;
      }

      if (_autoApplySmartParse) {
        _triggerType = parsed.triggerType;
        _parsedLocationName = parsed.locationName;
        if (!_triggerType.isLocation) {
          _selectedLocation = null;
        }

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
      }
    });
  }

  Future<void> _pickLocationOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialName: _selectedLocation?.name ?? _parsedLocationName ?? 'Location',
          initialLocation: _selectedLocation,
        ),
      ),
    );

    if (result is ReminderLocation && mounted) {
      setState(() {
        _autoApplySmartParse = false;
        _selectedLocation = result;
      });
    }
  }

  void _onSpeechTranscriptChanged() {
    if (!_isSmartInputMode) return;
    if (!_speechService.isListening.value) return;

    final transcript = _speechService.transcript.value.trim();
    if (transcript.isEmpty) return;

    if (_smartInputController.text != transcript) {
      _smartInputController.value = TextEditingValue(
        text: transcript,
        selection: TextSelection.collapsed(offset: transcript.length),
      );
    }

    _parseSmartInput();
  }

  Future<void> _toggleListening() async {
    if (_speechService.isListening.value) {
      HapticFeedback.lightImpact();
      await _speechService.stopListening();
      return;
    }

    HapticFeedback.mediumImpact();
    final started = await _speechService.startListening();
    if (!started && mounted) {
      final message = _speechService.errorMessage.value ?? 'Microphone permission denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
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
        final rawInput = _smartInputController.text.trim();
        if (rawInput.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a reminder')),
            );
          }
          return;
        }

        final parsed = TextParser.parseReminderText(rawInput);
        if (title.isEmpty) {
          title = parsed.title;
        }
        description = null;
      }

      if (description != null && description.isEmpty) {
        description = null;
      }

      final isTimeBased = _triggerType == ReminderTriggerType.time;

      final dateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      if (isTimeBased &&
          _recurrence == RecurrenceType.custom &&
          (_customRecurrenceDays == null || _customRecurrenceDays! <= 0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a valid custom recurrence interval')),
          );
        }
        return;
      }

      if (!isTimeBased && _selectedLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pick a location on the map to continue')),
          );
        }
        return;
      }

      final viewModel = context.read<ReminderViewModel>();

      if (!isTimeBased) {
        final permission = await viewModel.requestGeofencePermissions();
        if (permission != GeofencePermissionStatus.always && mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Location Permission Required'),
              content: const Text(
                'Location reminders need "Always" location access to trigger reliably in the background. '
                'You can still save this reminder, but it may not trigger until permission is granted in system settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save Anyway'),
                ),
              ],
            ),
          );

          if (proceed != true) {
            return;
          }
        }
      }

      DateTime effectiveDateTime = isTimeBased ? dateTime : DateTime.now();
      if (isTimeBased && effectiveDateTime.isBefore(DateTime.now())) {
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

      final effectiveRecurrence = isTimeBased ? _recurrence : RecurrenceType.none;
      final effectiveCustomDays = isTimeBased ? _customRecurrenceDays : null;

      if (!isTimeBased && _selectedLocation != null) {
        final name = _selectedLocation!.name;
        description = _triggerType == ReminderTriggerType.locationExit ? 'When you leave $name' : 'When you arrive near $name';
      }

      final reminder = ReminderModel.create(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        description: description,
        dateTime: effectiveDateTime,
        priority: _priority,
        recurrence: effectiveRecurrence,
        triggerType: _triggerType,
        location: isTimeBased ? null : _selectedLocation,
        customRecurrenceDays: effectiveCustomDays,
      );

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
