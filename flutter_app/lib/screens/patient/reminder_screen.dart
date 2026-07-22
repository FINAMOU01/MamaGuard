import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../../core/constants.dart';
import '../../widgets/patient_bottom_nav.dart';

final FlutterLocalNotificationsPlugin _notifPlugin = FlutterLocalNotificationsPlugin();

class ReminderScreen extends StatefulWidget {
  final String phone;
  const ReminderScreen({super.key, required this.phone});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  DateTime _selectedDate = DateTime.now().add(const Duration(hours: 1));
  TimeOfDay _selectedTime = TimeOfDay(
    hour: DateTime.now().add(const Duration(hours: 1)).hour,
    minute: DateTime.now().add(const Duration(hours: 1)).minute,
  );
  bool _isSaving = false;
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    tz_data.initializeTimeZones();
    initializeDateFormatting('fr_FR');
    _initNotifs();
    _loadReminders();
  }

  Future<void> _initNotifs() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true);
    await _notifPlugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));
  }

  Future<void> _loadReminders() async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/reminders'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _reminders = List<Map<String, dynamic>>.from(data['reminders'] ?? []);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Choisir la date du rappel',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppConstants.softPink),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      helpText: 'Choisir l\'heure du rappel',
      cancelText: 'Annuler',
      confirmText: 'Confirmer',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: AppConstants.softPink),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _scheduleReminder() async {
    setState(() => _isSaving = true);

    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    );

    if (dt.isBefore(DateTime.now())) {
      _showError('La date/heure doit être dans le futur');
      setState(() => _isSaving = false);
      return;
    }

    final remindAt = dt.toIso8601String();
    final title = 'MamaGuard - Consultation médicale';
    final body = 'Vous avez une consultation dans 30 minutes. Préparez vos questions.';

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/patient/reminder/create'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': widget.phone, 'remind_at': remindAt, 'title': title}),
      );
      if (response.statusCode == 200) {
        await _scheduleLocalNotif(dt, title, body);
        _loadReminders();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Rappel programmé avec succès'),
            backgroundColor: AppConstants.normalColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      } else {
        _showError('Erreur lors de la création du rappel');
      }
    } catch (_) {
      _showError('Erreur de connexion');
    }
    setState(() => _isSaving = false);
  }

  Future<void> _scheduleLocalNotif(DateTime dt, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'mamaguard_reminders',
      'Rappels MamaGuard',
      channelDescription: 'Notifications de rappel de consultation',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final scheduledAt = dt.subtract(const Duration(minutes: 30));
    if (scheduledAt.isAfter(DateTime.now())) {
      final tzDt = tz.TZDateTime.from(scheduledAt, tz.local);
      await _notifPlugin.zonedSchedule(
        dt.millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        tzDt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppConstants.criticalColor,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildNewCard(),
                    const SizedBox(height: 20),
                    _buildListSection(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: PatientBottomNav(currentIndex: 0, phone: widget.phone),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          const SizedBox(height: 8),
          const Text('Rappel de consultation', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text('Programmez un rappel pour votre consultation', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }

  Widget _buildNewCard() {
    final dateFmt = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(_selectedDate);
    final timeFmt = _selectedTime.format(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppConstants.softPink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.notifications_active_rounded, color: AppConstants.softPink, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Nouveau rappel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildPicker(Icons.calendar_month_rounded, dateFmt, _pickDate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildPicker(Icons.access_time_rounded, timeFmt, _pickTime),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Vous recevrez une notification 30 minutes avant',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800])),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _scheduleReminder,
              icon: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.alarm_add_rounded, size: 22),
              label: Text(_isSaving ? 'Programmation...' : 'Programmer le rappel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.softPink,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppConstants.softPink.withValues(alpha: 0.6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppConstants.softPink),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF2D2D2D)), overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildListSection() {
    if (_reminders.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rappels programmés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF2D2D2D))),
        const SizedBox(height: 12),
        ..._reminders.map((r) => _buildReminderItem(r)),
      ],
    );
  }

  Widget _buildReminderItem(Map<String, dynamic> r) {
    final remindAt = r['remind_at'] ?? '';
    String display = remindAt;
    try {
      final dt = DateTime.parse(remindAt);
      display = DateFormat('EEEE d MMM HH:mm', 'fr_FR').format(dt);
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppConstants.softPink.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.notifications_rounded, color: AppConstants.softPink, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(display, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D2D2D))),
                const SizedBox(height: 2),
                Text('Notification 30 min avant', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}