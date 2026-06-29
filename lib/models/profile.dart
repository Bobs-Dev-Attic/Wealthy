import 'enums.dart';

/// The user's personal planning profile.
class Profile {
  final String userId;
  final String? name;
  final DateTime? birthDate;
  final int retirementAge;
  final int lifeExpectancy;
  final FilingStatus filingStatus;
  final String? state;
  final bool hasPassword;

  const Profile({
    required this.userId,
    this.name,
    this.birthDate,
    this.retirementAge = 65,
    this.lifeExpectancy = 95,
    this.filingStatus = FilingStatus.single,
    this.state,
    this.hasPassword = false,
  });

  /// Current age derived from birth date (defaults to retirementAge − 1 if unknown).
  int currentAge(DateTime now) {
    if (birthDate == null) return retirementAge - 1;
    var age = now.year - birthDate!.year;
    final hadBirthday = (now.month > birthDate!.month) ||
        (now.month == birthDate!.month && now.day >= birthDate!.day);
    if (!hadBirthday) age -= 1;
    return age;
  }

  Profile copyWith({
    String? name,
    DateTime? birthDate,
    int? retirementAge,
    int? lifeExpectancy,
    FilingStatus? filingStatus,
    String? state,
    bool? hasPassword,
  }) =>
      Profile(
        userId: userId,
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        retirementAge: retirementAge ?? this.retirementAge,
        lifeExpectancy: lifeExpectancy ?? this.lifeExpectancy,
        filingStatus: filingStatus ?? this.filingStatus,
        state: state ?? this.state,
        hasPassword: hasPassword ?? this.hasPassword,
      );

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        userId: j['user_id'] as String,
        name: j['name'] as String?,
        birthDate: j['birth_date'] != null ? DateTime.parse(j['birth_date'] as String) : null,
        retirementAge: (j['retirement_age'] as num?)?.toInt() ?? 65,
        lifeExpectancy: (j['life_expectancy'] as num?)?.toInt() ?? 95,
        filingStatus: FilingStatusX.fromDb((j['filing_status'] ?? 'single') as String),
        state: j['state'] as String?,
        hasPassword: (j['has_password'] as bool?) ?? false,
      );

  Map<String, dynamic> toUpdate() => {
        'name': name,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'retirement_age': retirementAge,
        'life_expectancy': lifeExpectancy,
        'filing_status': filingStatus.db,
        'state': state,
        'updated_at': DateTime.now().toIso8601String(),
      };
}
