import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'confirm_ride_screen.dart';

class SelectTimeScreen extends StatefulWidget {
  final String selectedLocation;
  final String selectedVehicle;
  final double? pickupLat;
  final double? pickupLng;
  final String? dropoffLocation;
  final double? dropoffLat;
  final double? dropoffLng;

  const SelectTimeScreen({
    super.key,
    required this.selectedLocation,
    required this.selectedVehicle,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLocation,
    this.dropoffLat,
    this.dropoffLng,
  });

  @override
  SelectTimeScreenState createState() => SelectTimeScreenState();
}

class SelectTimeScreenState extends State<SelectTimeScreen> {
  // 'now' books immediately; 'later' lets the user schedule a future ride.
  String _mode = 'now';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate != null) {
      setState(() {
        _mode = 'later';
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (pickedTime != null) {
      setState(() {
        _mode = 'later';
        _selectedTime = pickedTime;
      });
    }
  }

  void _selectNow() {
    setState(() {
      _mode = 'now';
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  DateTime get _combinedDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  void _confirmTime() {
    final rideDateTime = _mode == 'now' ? DateTime.now() : _combinedDateTime;

    if (_mode == 'later' && rideDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a time in the future.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConfirmRideScreen(
          vehicleName: widget.selectedVehicle,
          location: widget.selectedLocation,
          rideTime: rideDateTime,
          pickupLat: widget.pickupLat,
          pickupLng: widget.pickupLng,
          dropoffLocation: widget.dropoffLocation,
          dropoffLat: widget.dropoffLat,
          dropoffLng: widget.dropoffLng,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNow = _mode == 'now';
    return Scaffold(
      appBar: AppBar(title: const Text('Select Time')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pickup', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 4),
            Text(widget.selectedLocation, style: AppTextStyles.headlineMedium),
            if (widget.dropoffLocation != null) ...[
              const SizedBox(height: 12),
              const Text('Drop-off', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Text(widget.dropoffLocation!, style: AppTextStyles.headlineMedium),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ModeCard(
                    label: 'Ride Now',
                    icon: Icons.flash_on,
                    selected: isNow,
                    onTap: _selectNow,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeCard(
                    label: 'Schedule for Later',
                    icon: Icons.event,
                    selected: !isNow,
                    onTap: () => setState(() => _mode = 'later'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!isNow) ...[
              AppButton(
                label: 'Date: ${DateFormat('EEE, MMM d').format(_selectedDate)}',
                icon: Icons.calendar_today,
                variant: AppButtonVariant.outlined,
                isLarge: false,
                onPressed: () => _pickDate(context),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Time: ${_selectedTime.format(context)}',
                icon: Icons.access_time,
                variant: AppButtonVariant.outlined,
                isLarge: false,
                onPressed: () => _pickTime(context),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Your ride will be scheduled for ${DateFormat('EEE, MMM d • h:mm a').format(_combinedDateTime)}.',
                  style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const Spacer(),
            AppButton(
              label: isNow ? 'Confirm — Ride Now' : 'Confirm Schedule',
              icon: Icons.check,
              onPressed: _confirmTime,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.surfaceVariant, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.textHint),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
