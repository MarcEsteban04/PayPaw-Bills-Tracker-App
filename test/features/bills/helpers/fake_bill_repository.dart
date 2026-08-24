import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_with_status.dart';
import 'package:paypaw/features/bills/domain/entities/new_bill.dart';
import 'package:paypaw/features/bills/domain/repositories/bill_repository.dart';

/// An in-memory [BillRepository] that records what it was asked to do.
///
/// Shared, because the form, the edit screen and the list all need one and each
/// only cares about a slice of the contract. Every method is implemented rather
/// than thrown from, so a screen that calls one the test did not expect gets a
/// sensible answer instead of an `UnimplementedError` that reads as a crash.
class FakeBillRepository implements BillRepository {
  FakeBillRepository({List<BillWithStatus> bills = const <BillWithStatus>[]})
    : _bills = List<BillWithStatus>.of(bills);

  final List<BillWithStatus> _bills;

  NewBill? created;
  Bill? updated;
  String? archived;
  String? deleted;

  int createCalls = 0;
  int updateCalls = 0;
  int fetchCalls = 0;

  /// Set to make the next write fail.
  AppException? failure;

  @override
  Future<List<BillWithStatus>> fetchBills({
    bool includeArchived = false,
  }) async {
    fetchCalls++;

    return includeArchived
        ? _bills
        : _bills.where((BillWithStatus b) => !b.bill.isArchived).toList();
  }

  @override
  Future<BillWithStatus?> fetchBill(String id) async =>
      _bills.where((BillWithStatus b) => b.bill.id == id).firstOrNull;

  @override
  Future<Bill> createBill(NewBill draft) async {
    createCalls++;
    _throwIfFailing();
    created = draft;

    return Bill(
      id: 'bill-new',
      userId: 'user-1',
      name: draft.name,
      payee: draft.payee,
      amount: draft.amount,
      dueOn: draft.dueOn,
      categoryId: draft.categoryId,
      notes: draft.notes,
      createdAt: DateTime(2026, 8, 24),
      updatedAt: DateTime(2026, 8, 24),
    );
  }

  @override
  Future<Bill> updateBill(Bill bill) async {
    updateCalls++;
    _throwIfFailing();
    updated = bill;

    return bill;
  }

  @override
  Future<Bill> archiveBill(String id) async {
    archived = id;

    return _requireStored(id).copyWith(archivedAt: DateTime(2026, 9, 2));
  }

  @override
  Future<Bill> unarchiveBill(String id) async =>
      _requireStored(id).clearing(archived: true);

  @override
  Future<void> deleteBill(String id) async => deleted = id;

  void _throwIfFailing() {
    if (failure case final AppException exception) {
      throw exception;
    }
  }

  Bill _requireStored(String id) =>
      _bills.firstWhere((BillWithStatus b) => b.bill.id == id).bill;
}
