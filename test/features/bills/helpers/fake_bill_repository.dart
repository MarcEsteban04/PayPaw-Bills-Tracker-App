import 'dart:async';

import 'package:paypaw/core/error/app_exception.dart';
import 'package:paypaw/features/bills/domain/entities/bill.dart';
import 'package:paypaw/features/bills/domain/entities/bill_status.dart';
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
  String? restored;
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

    if (_gate case final Completer<void> gate) {
      await gate.future;
    }

    return includeArchived
        ? _bills
        : _bills.where((BillWithStatus b) => !b.bill.isArchived).toList();
  }

  Completer<void>? _gate;

  /// Holds the next fetch open until [releaseFetch].
  ///
  /// The only way to observe what a screen shows *while* it is refreshing. With
  /// an instant fake the loading state exists for less than a frame, so a screen
  /// that wrongly blanks itself mid-refresh passes every test — which is exactly
  /// how the dashboard shipped a skeleton flash on every payment recorded.
  void blockFetch() => _gate = Completer<void>();

  void releaseFetch() {
    _gate?.complete();
    _gate = null;
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

  /// These three write to [_bills] rather than only recording the call.
  ///
  /// A double that says "archived" and then hands the list back unchanged makes
  /// the archive round trip untestable — and the round trip is the whole point of
  /// a soft delete. The status is recomputed the way the view computes it:
  /// archived wins over everything, whatever the date says.

  @override
  Future<Bill> archiveBill(String id) async {
    _throwIfFailing();
    archived = id;

    final Bill bill = _requireStored(id)
        .copyWith(archivedAt: DateTime(2026, 9, 2));
    _replace(bill, BillStatus.archived);

    return bill;
  }

  @override
  Future<Bill> unarchiveBill(String id) async {
    _throwIfFailing();
    restored = id;

    final Bill bill = _requireStored(id).clearing(archived: true);
    _replace(bill, BillStatus.upcoming);

    return bill;
  }

  @override
  Future<void> deleteBill(String id) async {
    _throwIfFailing();
    deleted = id;
    _bills.removeWhere((BillWithStatus b) => b.bill.id == id);
  }

  void _replace(Bill bill, BillStatus status) {
    final int index = _bills.indexWhere(
      (BillWithStatus b) => b.bill.id == bill.id,
    );
    final BillWithStatus previous = _bills[index];

    _bills[index] = BillWithStatus(
      bill: bill,
      status: status,
      paid: previous.paid,
      outstanding: previous.outstanding,
      today: previous.today,
    );
  }

  void _throwIfFailing() {
    if (failure case final AppException exception) {
      throw exception;
    }
  }

  Bill _requireStored(String id) =>
      _bills.firstWhere((BillWithStatus b) => b.bill.id == id).bill;
}
