import 'employee_formats.dart';

/// A student on the desk's Student List, from `GET /students`.
///
/// The row is a `Student` record joined to the `User` account behind it, and
/// **the person's details live on the account, not on the student row** — name,
/// email, phone, date of birth, gender and blood group all come off the join.
/// The student row itself carries only the enrolment: which batch, which sport,
/// which coach.
///
/// That split is why [EmployeeStudentDraft] posts flat field names: `PUT
/// /students/{id}` takes the account fields and writes them through to the
/// `User` itself.
class EmployeeStudent {
  const EmployeeStudent({
    required this.id,
    this.userId,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.gender,
    this.bloodGroup,
    this.avatar,
    this.status = 'Active',
    this.dob,
    this.batchId,
    this.batchName = '',
    this.sportName = '',
    this.coachName = '',
    this.enrollmentDate,
    this.createdAt,
  });

  final int id;

  /// The linked account. Null when the join did not come back — the student
  /// row is still usable, so this is not a reason to drop it.
  final int? userId;

  final String name;
  final String email;
  final String phone;

  final String? gender;
  final String? bloodGroup;
  final String? avatar;

  /// `Active` | `Inactive`, off the linked account.
  final String status;

  final DateTime? dob;

  final int? batchId;
  final String batchName;
  final String sportName;
  final String coachName;

  final DateTime? enrollmentDate;
  final DateTime? createdAt;

  String get displayName => name.trim().isEmpty ? 'Student #$id' : name.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  bool get isActive => status.toLowerCase() == 'active';

  /// `Sub-junior · Badminton`, or whatever of the two actually arrived.
  String get batchLabel => [
        if (batchName.isNotEmpty) batchName,
        if (sportName.isNotEmpty) sportName,
      ].join(' · ');

  /// Age in whole years, or null when no usable date of birth arrived.
  ///
  /// Computed rather than trusted: the API sends `dob`, not an age, and an age
  /// stored at enrolment would be wrong by now.
  int? get age {
    final birth = dob;
    if (birth == null) return null;

    final now = DateTime.now();
    var years = now.year - birth.year;
    final hadBirthday = now.month > birth.month ||
        (now.month == birth.month && now.day >= birth.day);
    if (!hadBirthday) years -= 1;

    return years >= 0 && years < 130 ? years : null;
  }

  String get dobLabel => formatDay(dob);

  /// `14 yrs`, or null when the date of birth is missing or unreadable.
  String? get ageLabel {
    final years = age;
    return years == null ? null : '$years yr${years == 1 ? '' : 's'}';
  }

  EmployeeStudent copyWith({
    String? name,
    String? phone,
    String? gender,
    String? bloodGroup,
    DateTime? dob,
  }) {
    return EmployeeStudent(
      id: id,
      userId: userId,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      avatar: avatar,
      status: status,
      dob: dob ?? this.dob,
      batchId: batchId,
      batchName: batchName,
      sportName: sportName,
      coachName: coachName,
      enrollmentDate: enrollmentDate,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'EmployeeStudent($id, $displayName)';
}

/// The edit form behind `PUT /students/{id}`.
///
/// Only these five fields are accepted — the Employee Panel form cannot change
/// an email, a batch or an account's status, and sending one of those would be
/// ignored rather than refused, which is worse. [toJson] omits anything left
/// blank so a partial edit cannot blank a field the user never touched.
class EmployeeStudentDraft {
  const EmployeeStudentDraft({
    this.name,
    this.dob,
    this.gender,
    this.bloodGroup,
    this.phone,
  });

  final String? name;

  /// Sent as `yyyy-MM-dd`, which is what the column is.
  final DateTime? dob;

  final String? gender;
  final String? bloodGroup;
  final String? phone;

  Map<String, dynamic> toJson() {
    final body = <String, dynamic>{};

    void put(String key, String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) body[key] = text;
    }

    put('name', name);
    put('gender', gender);
    put('blood_group', bloodGroup);
    put('phone_number', phone);

    final birth = dob;
    if (birth != null) body['dob'] = formatIsoDate(birth);

    return body;
  }

  bool get isEmpty => toJson().isEmpty;
}

/// The body of `POST /students/{id}/feedback`.
///
/// `title` is optional server-side; `message` is not, so [isValid] gates the
/// submit button rather than letting the API answer 400 for an empty note.
class EmployeeStudentFeedbackDraft {
  const EmployeeStudentFeedbackDraft({this.title, required this.message});

  final String? title;
  final String message;

  bool get isValid => message.trim().isNotEmpty;

  Map<String, dynamic> toJson() {
    final heading = title?.trim();
    return <String, dynamic>{
      if (heading != null && heading.isNotEmpty) 'title': heading,
      'message': message.trim(),
    };
  }
}
