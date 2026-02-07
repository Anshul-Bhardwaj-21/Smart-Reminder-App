import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/reminder_model.dart';

class MapPickerScreen extends StatefulWidget {
  final String initialName;
  final ReminderLocation? initialLocation;

  const MapPickerScreen({
    super.key,
    required this.initialName,
    this.initialLocation,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late final MapController _mapController;
  late final TextEditingController _nameController;

  late LatLng _center;
  late double _radiusMeters;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final initialLocation = widget.initialLocation;
    _nameController = TextEditingController(text: initialLocation?.name ?? widget.initialName);
    _radiusMeters = initialLocation?.radiusMeters ?? 150;

    _center = initialLocation != null
        ? LatLng(initialLocation.latitude, initialLocation.longitude)
        : const LatLng(39.8283, -98.5795); // Center of contiguous US
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 4,
                    onPositionChanged: (position, _) {
                      final center = position.center;
                      if (center == null) return;
                      setState(() {
                        _center = center;
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.smart',
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Center(
                    child: Icon(
                      Icons.place,
                      size: 44,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Move the map and pick the pin location',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Location name',
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Radius: ${_radiusMeters.round()} m',
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _radiusMeters.clamp(50.0, 1000.0).toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '${_radiusMeters.round()} m',
                    onChanged: (value) {
                      setState(() {
                        _radiusMeters = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _confirmLocation,
                      icon: const Icon(Icons.check),
                      label: const Text('Use This Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLocation() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a location name')),
      );
      return;
    }

    final result = ReminderLocation(
      name: name,
      latitude: _center.latitude,
      longitude: _center.longitude,
      radiusMeters: _radiusMeters,
    );

    Navigator.pop(context, result);
  }
}
