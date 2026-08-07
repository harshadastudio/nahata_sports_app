/// An `{id, name}` pair from one of the coach autocomplete routes.
///
/// The four routes (`students`, `sports`, `batches`, `programs`) all answer the
/// same bare list under `data`, already scoped to the coach's own batches — so
/// a picker built from one of these can never offer someone else's student.
///
/// `programs` and `batches` currently return the *same* rows: the backend maps
/// both onto the coach's Active batches. They are kept apart anyway because the
/// website treats them as separate fields.
class CoachOption {
  const CoachOption({required this.id, required this.name});

  final int id;
  final String name;

  String get displayName => name.trim().isEmpty ? '#$id' : name.trim();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is CoachOption && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'CoachOption($id, $name)';
}
