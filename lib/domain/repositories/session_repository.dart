import 'package:vbt/domain/entities/rep_metrics.dart';

abstract class SessionRepository {
  Future<void> saveRepMetrics(RepMetrics metrics);
  Future<List<RepMetrics>> getSessionHistory();
}
