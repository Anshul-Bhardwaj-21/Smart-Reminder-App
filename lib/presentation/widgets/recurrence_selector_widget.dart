import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';

class RecurrenceSelectorWidget extends StatelessWidget {
  final RecurrenceType selectedRecurrence;
  final ValueChanged<RecurrenceType> onChanged;

  const RecurrenceSelectorWidget({
    super.key,
    required this.selectedRecurrence,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Repeat', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        DropdownButtonFormField<RecurrenceType>(
          value: selectedRecurrence,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.repeat),
          ),
          items: RecurrenceType.values.map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type.displayName),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ],
    );
  }
}
