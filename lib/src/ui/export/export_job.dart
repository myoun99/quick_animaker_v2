import 'package:flutter/foundation.dart';

import '../../models/export_spec.dart';

/// A queued export: the SPEC snapshot plus the output location. The job
/// renders against the project state AT RUN TIME (잡 클릭=복원 편집 —
/// the spec is the restorable part; the picture is whatever the film says
/// when the job runs). Session-only — the queue does not survive an app
/// restart.
enum ExportJobStatus {
  queued,
  running,
  succeeded,
  failed,
  cancelled;

  bool get isFinished => switch (this) {
    ExportJobStatus.queued || ExportJobStatus.running => false,
    _ => true,
  };
}

class ExportJob {
  const ExportJob({
    required this.id,
    required this.spec,
    required this.outputDirectory,
    required this.fileName,
    required this.createdAt,
    this.status = ExportJobStatus.queued,
    this.completed = 0,
    this.total = 0,
    this.message,
  });

  final int id;
  final ExportTabSpec spec;

  /// The destination directory (위치 선행 — chosen before the job exists).
  final String outputDirectory;

  /// The single-file name for video/image jobs; null when the job writes a
  /// file set under [outputDirectory] (sequences, cels, sheets).
  final String? fileName;

  final DateTime createdAt;
  final ExportJobStatus status;
  final int completed;
  final int total;

  /// Failure/summary text for the finished states.
  final String? message;

  ExportTab get tab => spec.tab;

  static const Object _unset = Object();

  ExportJob copyWith({
    ExportTabSpec? spec,
    String? outputDirectory,
    Object? fileName = _unset,
    ExportJobStatus? status,
    int? completed,
    int? total,
    Object? message = _unset,
  }) => ExportJob(
    id: id,
    spec: spec ?? this.spec,
    outputDirectory: outputDirectory ?? this.outputDirectory,
    fileName: identical(fileName, _unset)
        ? this.fileName
        : fileName as String?,
    createdAt: createdAt,
    status: status ?? this.status,
    completed: completed ?? this.completed,
    total: total ?? this.total,
    message: identical(message, _unset) ? this.message : message as String?,
  );
}

/// The render queue (세션 내 비영속): jobs in enqueue order, one runner at
/// a time. Pure state — the executor (EX7) drives it; the queue column
/// renders it.
class ExportQueueModel extends ChangeNotifier {
  final List<ExportJob> _jobs = [];
  int _nextId = 1;

  List<ExportJob> get jobs => List.unmodifiable(_jobs);

  bool get isEmpty => _jobs.isEmpty;

  bool get hasRunning =>
      _jobs.any((job) => job.status == ExportJobStatus.running);

  ExportJob? get nextQueued {
    for (final job in _jobs) {
      if (job.status == ExportJobStatus.queued) {
        return job;
      }
    }
    return null;
  }

  ExportJob enqueue({
    required ExportTabSpec spec,
    required String outputDirectory,
    String? fileName,
    DateTime Function() now = DateTime.now,
  }) {
    final job = ExportJob(
      id: _nextId,
      spec: spec,
      outputDirectory: outputDirectory,
      fileName: fileName,
      createdAt: now(),
    );
    _nextId += 1;
    _jobs.add(job);
    notifyListeners();
    return job;
  }

  ExportJob? jobById(int id) {
    for (final job in _jobs) {
      if (job.id == id) {
        return job;
      }
    }
    return null;
  }

  /// Applies [update] to the job; a missing id is a no-op (the job may
  /// have been removed while its runner was reporting).
  void update(int id, ExportJob Function(ExportJob job) update) {
    for (var i = 0; i < _jobs.length; i += 1) {
      if (_jobs[i].id == id) {
        _jobs[i] = update(_jobs[i]);
        notifyListeners();
        return;
      }
    }
  }

  /// Removes the job; a RUNNING job stays (cancel it first — the runner
  /// owns its lifecycle).
  bool remove(int id) {
    for (var i = 0; i < _jobs.length; i += 1) {
      if (_jobs[i].id == id) {
        if (_jobs[i].status == ExportJobStatus.running) {
          return false;
        }
        _jobs.removeAt(i);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void clearFinished() {
    final before = _jobs.length;
    _jobs.removeWhere((job) => job.status.isFinished);
    if (_jobs.length != before) {
      notifyListeners();
    }
  }
}
