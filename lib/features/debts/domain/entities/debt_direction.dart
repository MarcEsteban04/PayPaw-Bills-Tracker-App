/// Which way the money goes.
///
/// ## One table, one enum, not two of everything
///
/// `0008_debts.sql` stores both directions in `public.debts` with a `direction`
/// column, and the comment there gives the reason: the fields are identical and
/// every query is the same shape, so two tables would mean writing every debt
/// feature twice — and the day they drift is the day recording a repayment works
/// for money you owe and not for money owed to you.
///
/// The same argument applies up here. `Debt` carries this rather than there
/// being a `DebtIOwe` and a `DebtOwedToMe`, and the screens branch on it where
/// the *wording* differs — which is the only place it actually does.
///
/// Matches the `direction` check constraint in that migration.
enum DebtDirection {
  /// Money the user has borrowed and has to give back.
  iOwe('i_owe'),

  /// Money the user has lent and expects back.
  owedToMe('owed_to_me');

  const DebtDirection(this.wireValue);

  /// The string stored in the column. Never change one of these: the values are
  /// in the check constraint and in every row already written.
  final String wireValue;

  /// Reads a stored value.
  ///
  /// Returns null for anything unrecognised rather than guessing. Unlike a
  /// recurring bill's `kind` — which defaults to `bill` because a template the
  /// app cannot classify is still a template that has to appear somewhere —
  /// a debt whose direction is unknown is worse than absent: showing "you owe
  /// ₱5,000" to somebody who is *owed* ₱5,000 is a two-way error on the one
  /// fact the feature exists to record.
  static DebtDirection? parse(String? value) {
    for (final DebtDirection direction in values) {
      if (direction.wireValue == value) {
        return direction;
      }
    }

    return null;
  }

  /// Whether this is money leaving eventually.
  bool get isOutgoing => this == DebtDirection.iOwe;

  /// The other one. For a form that lets the direction be switched.
  DebtDirection get opposite =>
      this == DebtDirection.iOwe ? DebtDirection.owedToMe : DebtDirection.iOwe;
}
