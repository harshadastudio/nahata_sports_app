/// Student progress / performance assessments.
///
/// Routes: `GET | POST /coach/dashboard/performance/progress` and
/// `PUT | DELETE /coach/dashboard/performance/progress/{id}`.
///
/// Every route re-checks that the student is enrolled in one of the coach's
/// own batches and answers 403 otherwise, so a coach can never read or write
/// another coach's assessments.
library;

/// The four levels the backend accepts. Sent capitalised exactly as spelled
/// here — anything else is rejected with a 400.
enum CoachSkillLevel {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced'),
  expert('Expert');

  const CoachSkillLevel(this.slug);

  final String slug;

  String get label => slug;

  static CoachSkillLevel? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final level in CoachSkillLevel.values) {
      if (level.slug.toLowerCase() == text) return level;
    }
    return null;
  }
}

/// One dated assessment.
///
/// Each call to the create route adds a **new** record rather than replacing
/// the last one — that history is what [improvement] is computed from.
class CoachProgress {
  const CoachProgress({
    required this.id,
    this.studentId = 0,
    this.sportId = 0,
    this.studentName = '',
    this.sportName,
    this.batchName,
    this.currentScore = 0,
    this.skillLevelRaw,
    this.previousScore,
    this.improvementRaw,
    this.lastUpdated,
    this.notes,
  });

  /// The **performance record** id — what the edit and delete routes take.
  /// Not the student id.
  final int id;

  final int studentId;
  final int sportId;
  final String studentName;
  final String? sportName;

  /// The student's batch. Sent as `program` by the API.
  final String? batchName;

  /// `fitnessScore`, 0–100.
  final num currentScore;

  final String? skillLevelRaw;

  /// The score on the previous assessment for the same student **and sport**.
  /// `null` on a first assessment.
  final num? previousScore;

  /// Pre-formatted by the API as `"+5"`, `"-3"` or `"0"`. Kept as sent so the
  /// app and the website show the same figure, and read numerically through
  /// [improvement].
  final String? improvementRaw;

  /// The assessment date, not when the row was written.
  final DateTime? lastUpdated;

  /// The coach's own notes.
  final String? notes;

  CoachSkillLevel? get skillLevel => CoachSkillLevel.tryParse(skillLevelRaw);

  /// Falls back to the raw string so an unmapped level is still shown.
  String get skillLabel => skillLevel?.label ?? (skillLevelRaw ?? '').trim();

  String get displayName =>
      studentName.trim().isEmpty ? 'Unknown' : studentName.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  String get scoreLabel => '${currentScore.round()}%';

  /// The change since the previous assessment. `0` both when there was no
  /// change and when this is the first assessment — [isFirstAssessment] tells
  /// those apart.
  num get improvement =>
      num.tryParse((improvementRaw ?? '').replaceAll('+', '').trim()) ?? 0;

  bool get isFirstAssessment => previousScore == null;

  bool get improved => improvement > 0;
  bool get declined => improvement < 0;

  /// `"+5"` / `"-3"`, or null when there is nothing to compare against.
  String? get improvementLabel {
    if (isFirstAssessment) return null;
    final value = improvement;
    if (value == 0) return '0';
    return value > 0 ? '+$value' : '$value';
  }

  /// `"Badminton · Evening Batch"`, skipping whichever part is missing.
  String get contextLabel => [
        if ((sportName ?? '').trim().isNotEmpty) sportName!.trim(),
        if ((batchName ?? '').trim().isNotEmpty &&
            (batchName ?? '').trim().toUpperCase() != 'N/A')
          batchName!.trim(),
      ].join(' · ');

  @override
  String toString() => 'CoachProgress($id, $studentName, $scoreLabel)';
}

/// A new or edited assessment.
///
/// On create, `studentId`, `sportId` and `fitnessScore` are all required. On
/// edit every field is optional — only what is set is sent, so an edit that
/// touches the score alone cannot blank the notes.
class CoachProgressDraft {
  const CoachProgressDraft({
    this.studentId,
    this.sportId,
    this.fitnessScore,
    this.skillLevel,
    this.notes,
    this.improvementAreas,
    this.assessmentDate,
  });

  final int? studentId;
  final int? sportId;

  /// 0–100. The backend rejects anything outside that range with a 400.
  final num? fitnessScore;

  final CoachSkillLevel? skillLevel;
  final String? notes;
  final String? improvementAreas;
  final DateTime? assessmentDate;

  /// The create body. `assessmentDate` defaults to today server-side when
  /// omitted.
  Map<String, dynamic> toCreateJson() => {
        'studentId': studentId,
        'sportId': sportId,
        'fitnessScore': fitnessScore,
        if (skillLevel != null) 'skillLevel': skillLevel!.slug,
        if ((notes ?? '').trim().isNotEmpty) 'coachNotes': notes!.trim(),
        if ((improvementAreas ?? '').trim().isNotEmpty)
          'improvementAreas': improvementAreas!.trim(),
        if (assessmentDate != null)
          'assessmentDate': _dateOnly(assessmentDate!),
      };

  /// The edit body — only the fields actually set.
  ///
  /// Notes and improvement areas are sent whenever they are non-null, empty
  /// string included, because clearing them is a legitimate edit and the
  /// backend maps `''` to `null`.
  Map<String, dynamic> toUpdateJson() => {
        if (fitnessScore != null) 'fitnessScore': fitnessScore,
        if (skillLevel != null) 'skillLevel': skillLevel!.slug,
        if (notes != null) 'coachNotes': notes!.trim(),
        if (improvementAreas != null)
          'improvementAreas': improvementAreas!.trim(),
        if (assessmentDate != null)
          'assessmentDate': _dateOnly(assessmentDate!),
        if (sportId != null) 'sportId': sportId,
      };

  /// `yyyy-MM-dd` in local civil time — see `coachDateKey`, same reasoning.
  static String _dateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  String toString() =>
      'CoachProgressDraft(student: $studentId, score: $fitnessScore)';
}
