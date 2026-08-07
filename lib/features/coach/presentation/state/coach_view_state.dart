/// The four states every async section of the coach dashboard can be in.
///
/// Kept as one enum so the shimmer / empty / error / content decision is made
/// the same way on every page.
enum CoachViewState { idle, loading, ready, failed }

extension CoachViewStateX on CoachViewState {
  bool get isLoading => this == CoachViewState.loading;
  bool get isReady => this == CoachViewState.ready;
  bool get isFailed => this == CoachViewState.failed;
  bool get isIdle => this == CoachViewState.idle;
}
