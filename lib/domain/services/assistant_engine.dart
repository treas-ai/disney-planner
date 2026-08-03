import '../entities/assistant_context.dart';
import '../entities/assistant_response.dart';

abstract interface class AssistantEngine {
  Future<AssistantResponse> respond({
    required String question,
    required AssistantContext context,
  });
}
