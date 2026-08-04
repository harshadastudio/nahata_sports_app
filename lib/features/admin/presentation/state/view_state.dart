/// The four states every async section of the dashboard can be in.
///
/// Kept as one enum so the shimmer / empty / error / content decision is made
/// the same way on every page.
enum ViewState { idle, loading, ready, failed }

extension ViewStateX on ViewState {
  bool get isLoading => this == ViewState.loading;
  bool get isReady => this == ViewState.ready;
  bool get isFailed => this == ViewState.failed;
  bool get isIdle => this == ViewState.idle;
}
