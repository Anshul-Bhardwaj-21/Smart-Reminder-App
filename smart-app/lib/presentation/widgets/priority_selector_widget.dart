import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';

class PrioritySelectorWidget extends StatelessWidget {
  final Priority selectedPriority;
  final ValueChanged<Priority> onChanged;

  const PrioritySelectorWidget({
    super.key,
    required this.selectedPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Priority', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: Priority.values.map((priority) {
            final isSelected = priority == selectedPriority;
            final color = AppTheme.getPriorityColor(priority);
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(priority.displayName),
                  selected: isSelected,
                  onSelected: (_) => onChanged(priority),
                  selectedColor: color.withOpacity(0.3),
                  side: BorderSide(color: color),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
