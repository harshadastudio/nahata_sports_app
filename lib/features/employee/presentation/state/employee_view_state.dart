/// The four states every async section of the employee dashboard can be in.
///
/// Kept as one enum so the shimmer / empty / error / content decision is made
/// the same way on every page.
enum EmployeeViewState { idle, loading, ready, failed }

extension EmployeeViewStateX on EmployeeViewState {
  bool get isLoading => this == EmployeeViewState.loading;
  bool get isReady => this == EmployeeViewState.ready;
  bool get isFailed => this == EmployeeViewState.failed;
  bool get isIdle => this == EmployeeViewState.idle;
}
