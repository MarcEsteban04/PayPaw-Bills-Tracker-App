import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/recurring/domain/entities/new_recurring_bill.dart';
import 'package:paypaw/features/recurring/domain/entities/recurring_bill.dart';
import 'package:paypaw/features/recurring/domain/repositories/recurring_bill_repository.dart';

/// An in-memory [RecurringBillRepository] that also stands in for the generator.
///
/// [generateDueBills] materialises nothing — generation lives in SQL, and this
/// double exists to answer "was it asked for, and how often". That is what the
/// client is actually responsible for: the call, its idempotence at the call site,
/// and not letting a failure take the screen down with it.
class FakeRecurringBillRepository implements RecurringBillRepository {
  FakeRecurringBillRepository({
    List<RecurringBill> templates = const <RecurringBill>[],
  }) : _templates = List<RecurringBill>.of(templates);

  final List<RecurringBill> _templates;

  NewRecurringBill? created;
  RecurringBill? updated;
  String? deleted;

  int generateCalls = 0;

  /// How many bills the next generate reports creating.
  int generateResult = 0;

  /// Set to make the next write fail.
  AppException? failure;

  /// Set to make generation fail, independently of the write.
  AppException? generateFailure;

  @override
  Future<List<RecurringBill>> fetchRecurringBills({
    bool includeInactive = true,
  }) async => includeInactive
      ? _templates
      : _templates.where((RecurringBill t) => t.isActive).toList();

  @override
  Future<RecurringBill?> fetchRecurringBill(String id) async =>
      _templates.where((RecurringBill t) => t.id == id).firstOrNull;

  @override
  Future<RecurringBill> createRecurringBill(NewRecurringBill draft) async {
    _throwIfFailing();
    created = draft;

    final RecurringBill stored = RecurringBill(
      id: 'rec-new',
      userId: 'user-1',
      kind: draft.kind,
      name: draft.name.trim(),
      payee: draft.payee,
      categoryId: draft.categoryId,
      amount: draft.amount,
      recurrence: draft.recurrence,
      nextDueOn: draft.nextDueOn!,
      isActive: draft.isActive,
      createdAt: DateTime(2026, 8, 25),
      updatedAt: DateTime(2026, 8, 25),
    );
    _templates.add(stored);

    return stored;
  }

  @override
  Future<RecurringBill> updateRecurringBill(RecurringBill bill) async {
    _throwIfFailing();
    updated = bill;

    return bill;
  }

  @override
  Future<void> deleteRecurringBill(String id) async {
    _throwIfFailing();
    deleted = id;
    _templates.removeWhere((RecurringBill t) => t.id == id);
  }

  @override
  Future<int> generateDueBills() async {
    generateCalls++;

    if (generateFailure case final AppException exception) {
      throw exception;
    }

    return generateResult;
  }

  void _throwIfFailing() {
    if (failure case final AppException exception) {
      throw exception;
    }
  }
}
