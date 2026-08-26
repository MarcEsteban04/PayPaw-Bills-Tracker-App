/// How to order the subscription list.
///
/// Two orders, because the screen answers two questions and they want opposite
/// arrangements. "When does the next one hit" is a calendar question and wants
/// [nextCharge]; "what should I cancel" is a money question and wants
/// [cost] — which is the whole of what the roadmap calls *most expensive
/// subscriptions*.
///
/// A ranked "costliest" section above the list would have been the other way to
/// show that, and it would have printed the same three rows twice.
enum SubscriptionSort {
  /// Soonest charge first. The default, and what the repository already returns.
  nextCharge('Next charge'),

  /// Dearest first, by monthly equivalent rather than by the figure on the row.
  ///
  /// A ₱1,200 yearly plan costs less per month than a ₱149 monthly one, and
  /// sorting on the raw amount would put it first and be wrong.
  cost('Cost');

  const SubscriptionSort(this.label);

  /// What the control calls this order.
  final String label;

  bool get isDefault => this == SubscriptionSort.nextCharge;
}
