import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/projection_result.dart';
import '../services/engine/retirement_projection.dart';
import 'plan_controller.dart';

/// Recomputes the full projection from the live plan state, debounced so rapid
/// typing stays smooth while results still feel real-time.
class ProjectionController extends StateNotifier<ProjectionResult?> {
  ProjectionController(this._ref) : super(null) {
    _ref.listen<PlanState>(planControllerProvider, (_, next) => _schedule(next),
        fireImmediately: true);
  }

  final Ref _ref;
  Timer? _timer;

  void _schedule(PlanState s) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), () => _compute(s));
  }

  void _compute(PlanState s) {
    try {
      final inputs = PlanInputs.from(
        profile: s.profile,
        assumptions: s.assumptions,
        accounts: s.accounts,
        incomes: s.incomes,
        expenses: s.expenses,
        liabilities: s.liabilities,
        holdings: s.holdings,
        now: DateTime.now(),
      );
      state = RetirementProjection.project(inputs);
    } catch (_) {
      // Keep the previous result on transient errors.
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final projectionControllerProvider =
    StateNotifierProvider<ProjectionController, ProjectionResult?>(
        (ref) => ProjectionController(ref));
