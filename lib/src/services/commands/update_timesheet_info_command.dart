import '../../models/timesheet_info.dart';
import '../command.dart';
import '../project_repository.dart';

class UpdateTimesheetInfoCommand implements Command {
  UpdateTimesheetInfoCommand({required this.repository, required this.info});

  final ProjectRepository repository;
  final TimesheetInfo info;

  TimesheetInfo? _previousInfo;
  bool _hasExecuted = false;

  @override
  String get description => 'Update timesheet info';

  @override
  void execute() {
    _previousInfo ??= repository.requireProject().timesheetInfo;
    repository.updateTimesheetInfo(info);
    _hasExecuted = true;
  }

  @override
  void undo() {
    final previousInfo = _previousInfo;
    if (!_hasExecuted || previousInfo == null) {
      throw StateError('Command has not been executed.');
    }
    repository.updateTimesheetInfo(previousInfo);
  }
}
