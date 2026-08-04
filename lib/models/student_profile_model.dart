/// Model for `GET /students/me`.
library;

/// The `User` object embedded in a student record.
class StudentUser {
  const StudentUser({
    this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.avatar,
    this.status,
    this.joinDate,
  });

  final int? id;
  final String? name;
  final String? email;
  final String? phoneNumber;

  /// `yyyy-MM-dd`.
  final String? dob;

  final String? gender;
  final String? bloodGroup;
  final String? avatar;
  final String? status;
  final String? joinDate;

  factory StudentUser.fromJson(Map<String, dynamic> json) => StudentUser(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        email: _asString(json['email']),
        phoneNumber: _asString(json['phone_number'] ?? json['phoneNumber']),
        dob: _asString(json['dob']),
        gender: _asString(json['gender']),
        bloodGroup: _asString(json['blood_group'] ?? json['bloodGroup']),
        avatar: _asString(json['avatar']),
        status: _asString(json['status']),
        joinDate: _asString(json['join_date'] ?? json['joinDate']),
      );
}

/// The signed-in user's student record, with their account details nested.
class StudentProfile {
  const StudentProfile({
    this.id,
    this.userId,
    this.sportComplexId,
    this.parentName,
    this.parentPhone,
    this.parentEmail,
    this.schoolName,
    this.grade,
    this.medicalConditions,
    this.allergies,
    this.previousExperience,
    this.achievements,
    this.enrollmentDate,
    this.status,
    this.createdAt,
    this.updatedAt,
    this.user,
  });

  /// Student record id — not the user id.
  final int? id;

  final int? userId;
  final int? sportComplexId;

  final String? parentName;
  final String? parentPhone;
  final String? parentEmail;
  final String? schoolName;
  final String? grade;
  final String? medicalConditions;
  final String? allergies;
  final String? previousExperience;
  final String? achievements;

  final String? enrollmentDate;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  final StudentUser? user;

  /// Account status when the student record has none of its own.
  String? get effectiveStatus => status ?? user?.status;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    final user = json['User'] ?? json['user'];

    return StudentProfile(
      id: _asInt(json['id']),
      userId: _asInt(json['userId']),
      sportComplexId: _asInt(json['sportComplexId']),
      parentName: _asString(json['parentName']),
      parentPhone: _asString(json['parentPhone']),
      parentEmail: _asString(json['parentEmail']),
      schoolName: _asString(json['schoolName']),
      grade: _asString(json['grade']),
      medicalConditions: _asString(json['medicalConditions']),
      allergies: _asString(json['allergies']),
      previousExperience: _asString(json['previousExperience']),
      achievements: _asString(json['achievements']),
      enrollmentDate: _asString(json['enrollmentDate']),
      status: _asString(json['status']),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
      user: user is Map
          ? StudentUser.fromJson(Map<String, dynamic>.from(user))
          : null,
    );
  }
}

int? _asInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

/// Nulls arrive both as JSON null and as the string "null" from some fields.
String? _asString(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty || text == 'null') ? null : text;
}
