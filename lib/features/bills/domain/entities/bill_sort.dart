/// How a filtered bill list is ordered.
///
/// [dueSoonest] is the default and the only one the urgency groups survive: the
/// groups *are* a due-date order, so sorting by amount inside "Overdue" then
/// "Upcoming" would not put the largest bill first — it would put the largest
/// overdue bill first, which is a different question from the one the user asked.
/// The list goes flat for every other option. See `bills_screen.dart`.
enum BillSort {
  dueSoonest('Due soonest'),
  dueLatest('Due latest'),
  amountHighest('Largest first'),
  amountLowest('Smallest first'),
  nameAtoZ('Name A–Z');

  const BillSort(this.label);

  final String label;

  /// Whether this is the order the screen was designed around.
  bool get isDefault => this == BillSort.dueSoonest;
}
