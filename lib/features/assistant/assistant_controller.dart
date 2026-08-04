import 'package:flutter/foundation.dart';

import '../../app/dependency/service_locator.dart';
import '../../app/state/app_state.dart';
import '../../domain/entities/assistant_context.dart';
import '../../domain/entities/assistant_response.dart';
import '../../domain/entities/live_operation_snapshot.dart';
import '../../domain/services/assistant_engine.dart';
import '../../domain/services/rule_based_assistant_engine.dart';

class AssistantController extends ChangeNotifier {
  AssistantController(
    this._appState, {
    this._engine = const RuleBasedAssistantEngine(),
  });

  final AppState _appState;
  final AssistantEngine _engine;

  bool isLoading = false;
  String? errorMessage;
  AssistantResponse? response;
  LiveOperationSnapshot? liveOperation;

  Future<void> loadLiveOperation() async {
    try {
      final parkId =
          _appState.daySchedule?.parkId ?? _appState.tripSettings.parkId;
      liveOperation = await ServiceLocator.fetchLiveOperationSnapshot(
        parkId: parkId,
      );
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('ライブ運営情報の読み込みに失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || isLoading) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final parkId =
          _appState.daySchedule?.parkId ?? _appState.tripSettings.parkId;
      liveOperation ??= await ServiceLocator.fetchLiveOperationSnapshot(
        parkId: parkId,
      );
      final eventImpacts = await ServiceLocator.eventImpactRepository
          .loadEventImpacts(parkId: parkId);

      response = await _engine.respond(
        question: trimmed,
        context: AssistantContext(
          now: DateTime.now(),
          schedule: _appState.daySchedule,
          facilities: _appState.selectedFacilitiesForPark(parkId),
          eventImpacts: eventImpacts,
          liveOperation: liveOperation,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('AIコンシェルジュの回答生成に失敗しました: $error');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = '回答を作成できませんでした。もう一度お試しください。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
