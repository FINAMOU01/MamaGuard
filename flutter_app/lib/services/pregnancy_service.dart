class PregnancyInfo {
  final int week;
  final int trimester;
  final DateTime? dueDate;
  final String message;
  final bool isValid;

  PregnancyInfo({
    required this.week,
    required this.trimester,
    this.dueDate,
    required this.message,
    this.isValid = true,
  });
}

class PregnancyData {
  final String id;
  final String status;
  final String pregnancyMethod;
  final String lmpDate;
  final int manualWeek;
  final String referenceDate;
  final String dueDate;
  final String actualBirthDate;
  final String doctorName;
  final String doctorPhone;
  final bool isActive;
  final String createdAt;
  final PregnancyInfo? info;

  PregnancyData({
    required this.id,
    required this.status,
    required this.pregnancyMethod,
    required this.lmpDate,
    required this.manualWeek,
    required this.referenceDate,
    required this.dueDate,
    required this.actualBirthDate,
    required this.doctorName,
    required this.doctorPhone,
    required this.isActive,
    required this.createdAt,
    this.info,
  });

  bool get isCompleted => status == 'completed';

  factory PregnancyData.fromJson(Map<String, dynamic> json) {
    return PregnancyData(
      id: json['id'] ?? '',
      status: json['status'] ?? 'active',
      pregnancyMethod: json['pregnancy_method'] ?? '',
      lmpDate: json['lmp_date'] ?? '',
      manualWeek: (json['manual_week'] ?? 0) is int
          ? json['manual_week'] ?? 0
          : int.tryParse(json['manual_week'].toString()) ?? 0,
      referenceDate: json['reference_date'] ?? '',
      dueDate: json['due_date'] ?? '',
      actualBirthDate: json['actual_birth_date'] ?? '',
      doctorName: json['doctor_name'] ?? '',
      doctorPhone: json['doctor_phone'] ?? '',
      isActive: json['is_active'] ?? false,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PregnancyService {
  static const int _pregnancyWeeks = 40;
  static const int _daysInPregnancy = 280;

  static PregnancyInfo calculate({
    DateTime? lmpDate,
    int? manualWeek,
    DateTime? referenceDate,
    String? method,
  }) {
    if (method == null || method.isEmpty) {
      return PregnancyInfo(week: 0, trimester: 0, message: '', isValid: false);
    }

    final now = DateTime.now();
    int currentWeek;
    DateTime? edd;

    if (method == 'lmp' && lmpDate != null) {
      edd = DateTime(lmpDate.year, lmpDate.month + 9, lmpDate.day);
      if (edd.month > 12) {
        edd = DateTime(edd.year + 1, edd.month - 12, edd.day);
      }
      final diff = now.difference(lmpDate).inDays;
      currentWeek = (diff / 7).floor();
    } else if (method == 'manual' && manualWeek != null && referenceDate != null) {
      edd = referenceDate.add(Duration(days: (_pregnancyWeeks - manualWeek) * 7));
      final diff = now.difference(referenceDate).inDays;
      currentWeek = manualWeek + (diff / 7).floor();
    } else {
      return PregnancyInfo(week: 0, trimester: 0, message: '', isValid: false);
    }

    if (currentWeek < 0) currentWeek = 0;
    if (currentWeek > 45) currentWeek = 45;

    int trimester;
    String message;

    if (currentWeek <= 0) {
      trimester = 0;
      message = 'Votre grossesse va bientôt commencer.';
    } else if (currentWeek <= 13) {
      trimester = 1;
      message = 'Félicitations pour le début de cette belle aventure. Prenez soin de vous et de votre bébé.';
    } else if (currentWeek <= 27) {
      trimester = 2;
      message = 'Votre grossesse progresse merveilleusement. Continuez votre suivi régulier.';
    } else if (currentWeek <= 40) {
      trimester = 3;
      message = 'Vous approchez de la naissance. MamaGuard reste à vos côtés pour vous accompagner jusqu\'au grand jour.';
    } else {
      trimester = 3;
      message = 'Vous êtes arrivée au terme prévu de votre grossesse. Nous vous recommandons de rester en contact avec votre professionnel de santé.';
    }

    return PregnancyInfo(
      week: currentWeek,
      trimester: trimester,
      dueDate: edd,
      message: message,
      isValid: true,
    );
  }

  static String formatDate(DateTime? date) {
    if (date == null) return '';
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formatDateStr(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return formatDate(date);
    } catch (_) {
      return dateStr;
    }
  }
}
