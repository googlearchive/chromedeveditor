// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.jobs;

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

import 'exception.dart';
import 'enum.dart';

final Logger _logger = new Logger('spark.jobs');
final NumberFormat _nf = new NumberFormat.decimalPattern();

/**
 * A Job manager. This class can be used to schedule jobs, and provides event
 * notification for job progress.
 */
class JobManager {
  final StreamController<JobManagerEvent> _controller =
      new StreamController.broadcast();

  Job _runningJob;
  final List<Job> _waitingJobs = new List<Job>();

  /**
   * Will schedule a [job] after all other queued jobs. If no [Job] is currently
   * waiting, [job] will run.
   */
  Future<SparkJobStatus> schedule(Job job) {
    Completer completer = job.completer;
    _waitingJobs.add(job);

    if (!isJobRunning) {
      _runNextJob();
    }
    return completer.future;
  }

  /**
   * Whether or not a job is currently running.
   */
  bool get isJobRunning => _runningJob != null;

  /**
   * Stream of state change events handled by this [JobManager].
   */
  Stream<JobManagerEvent> get onChange => _controller.stream;

  void _runNextJob() {
    if (_waitingJobs.isEmpty) return;

    _runningJob = _waitingJobs.removeAt(0);

    Timer.run(() {
      _ProgressMonitorImpl monitor = new _ProgressMonitorImpl(this, _runningJob);
      _jobStarted(_runningJob);
      SparkJobStatus jobStatus;

      try {
        _runningJob.run(monitor).then((status) {
          jobStatus = status;
        }).catchError((e, st) {
          _runningJob.completer.completeError(e);
        }).whenComplete(() {
          _jobFinished(_runningJob);
          if (_runningJob != null) _runningJob.done(jobStatus);
          _runningJob = null;
          _runNextJob();
        });
      } catch (e, st) {
        _logger.severe('Error running job ${_runningJob}', e, st);
        _runningJob = null;
        _runNextJob();
      }
    });
  }

  void _jobStarted(Job job) {
    _controller.add(new JobManagerEvent(this, job, started: true));
  }

  void _monitorWorked(_ProgressMonitorImpl monitor, Job job) {
    _controller.add(new JobManagerEvent(this, job, monitor: monitor));
  }

  void _monitorDone(_ProgressMonitorImpl monitor, Job job) {
    _controller.add(new JobManagerEvent(this, job, monitor: monitor));
  }

  void _jobFinished(Job job) {
    _controller.add(new JobManagerEvent(this, job, finished: true));
  }
}

class JobManagerEvent {
  final JobManager manager;
  final Job job;

  final bool started;
  final bool finished;

  bool _indeterminate = false;
  double _progress = 1.0;
  String _progressAsString = '';

  bool get indeterminate => _indeterminate;

  double get progress => _progress;

  JobManagerEvent(this.manager, this.job,
      {this.started: false, this.finished: false, ProgressMonitor monitor}) {
    // One and only one of [started], [finished], [monitor] should be truthy.
    assert([started, finished, monitor != null].where((e) => e).length == 1);

    // NOTE: We need a snapshot of the current [monitor]'s values here, as
    // [monitor] itself will keep changing while the event waits to be handled.
    if (monitor != null) {
      _indeterminate = monitor.indeterminate;
      _progress = monitor.progress;
      _progressAsString = '${monitor.title} ${monitor.progressAsString}';
    } else if (started) {
      _progressAsString = '${job.name}';
    } else if (finished) {
      _progressAsString = '${job.name} finished';
    }
  }

  String toString() => _progressAsString;
}

/**
 * A long-running task.
 */
abstract class Job {
  final String name;

  Completer<SparkJobStatus> _completer;

  Completer get completer => _completer;

  Future<SparkJobStatus> get future => _completer.future;

  Job(this.name, [Completer completer]) {
    if (completer != null) {
      _completer = completer;
    } else {
      _completer = new Completer<SparkJobStatus>();
    }
  }

  void done(SparkJobStatus status) {
    if (_completer != null && !_completer.isCompleted) {
      _completer.complete(status);
    }
  }

  /**
   * Run this job. The job can optionally provide progress through the given
   * progress monitor. When it finishes, it should complete the [Future] that
   * is returned.
   */
  Future<SparkJobStatus> run(ProgressMonitor monitor);

  String toString() => name;
}

/**
 * A simple [Job]. It finishes when the given [Completer] completes.
 */
class ProgressJob extends Job {

  ProgressJob(String name, Completer completer) : super(name, completer);

  Future<SparkJobStatus> run(ProgressMonitor monitor) {
    monitor.start(name);
    return _completer.future;
  }
}

class ProgressFormat extends Enum<String> {
  const ProgressFormat._(String value) : super(value);
  String get enumName => 'ProgressKind';

  static const NONE = const ProgressFormat._('NONE');
  static const DOUBLE = const ProgressFormat._('DOUBLE');
  static const PERCENTAGE = const ProgressFormat._('PERCENTAGE');
  static const N_OUT_OF_M = const ProgressFormat._('N_OUT_OF_M');
}

/**
 * Outlines a progress monitor with given [title] (the title of the progress
 * monitor), and [maxWork] (the [work] value determining when progress is
 * complete).  A maxWork of 0 indicates that progress cannot be determined.
 */
class ProgressMonitor {
  String _title;
  num _maxWork;
  num _work = 0;
  bool _cancelled = false;
  Completer _cancelledCompleter;
  StreamController _cancelController = new StreamController.broadcast();
  ProgressFormat _format;

  // The job itself can listen to the cancel event, and do the appropriate
  // action.
  Stream get onCancel => _cancelController.stream;

  /**
   * Starts the [ProgressMonitor] with a [title] and a [maxWork] (determining
   * when work is completed)
   */
  void start(
      String title,
      {num maxWork: 0,
       ProgressFormat format: ProgressFormat.NONE}) {
    _title = title;
    _maxWork = maxWork;
    _format = format;
  }

  String get title => _title;

  /**
   * The current value of work complete.
   */
  num get work => _work;

  /**
   * The final value of work once progress is complete.
   */
  num get maxWork => _maxWork;

  /**
   * Returns `true` if progress cannot be determined ([maxWork] == 0).
   */
  bool get indeterminate => maxWork == 0;

  /**
   * The total progress of work complete (a double from 0 to 1).
   */
  double get progress =>
      (_maxWork != null && _maxWork != 0) ? (_work / _maxWork) : 0.0;

  String get progressAsString {
    switch (_format) {
      case ProgressFormat.NONE:
        return '';
      case ProgressFormat.DOUBLE:
        return progress.toString();
      case ProgressFormat.PERCENTAGE:
        return '${(progress * 100).toStringAsFixed(0)}%';
      case ProgressFormat.N_OUT_OF_M:
        return '$_work of $_maxWork';
    }
    return '';
  }

  /**
   * Add [amount] more work to the previously specified value.
   */
  void addWork(num amount) {
    _maxWork += amount;
  }

  /**
   * Adds [amount] to [work] completed (but no greater than maxWork).
   */
  void worked(num amount) {
    _work += amount;

    if (_work > maxWork) {
      _work = maxWork;
    }
  }

  /**
   * Sets the work as completely done (work == maxWork).
   */
  void done() {
    _work = maxWork;
  }

  bool get cancelled => _cancelled;

  set cancelled(bool val) {
    _cancelled = val;

    _cancelController.add(true);

    if (_cancelledCompleter != null) {
      _cancelledCompleter.completeError(new UserCancelledException());
      _cancelledCompleter = null;
    }
  }

  /**
   * Return a Future that completes with the given value of [f]. If the user
   * cancels this ProgressMonitor, this Future will instead throw a
   * [UserCancelledException].
   */
  Future runCancellableFuture(Future f) {
    _cancelledCompleter = new Completer();

    f.then((result) {
      if (_cancelledCompleter != null) {
        _cancelledCompleter.complete(result);
        _cancelledCompleter = null;
      }
    }).catchError((e) {
      if (_cancelledCompleter != null) {
        _cancelledCompleter.completeError(e);
        _cancelledCompleter = null;
      }
    });

    return _cancelledCompleter.future;
  }
}

class UserCancelledException implements Exception {

}

class _ProgressMonitorImpl extends ProgressMonitor {
  JobManager manager;
  Job job;

  _ProgressMonitorImpl(this.manager, this.job);

  void start(
      String title,
      {num maxWork: 0,
       ProgressFormat format: ProgressFormat.NONE}) {
    super.start(title, maxWork: maxWork, format: format);

    manager._monitorWorked(this, job);
  }

  void worked(num amount) {
    super.worked(amount);

    manager._monitorWorked(this, job);
  }

  void done() {
    super.done();

    manager._monitorDone(this, job);
  }
}

/**
 * Listenes to the cancel task event and notifies the running job.
 * The implementing job must implemnt the onCancel to take proper
 * action on being cancelled.
 */
abstract class TaskCancel {
  bool _cancelled = false;
  get cancelled => _cancelled;

  ProgressMonitor _monitor;

  TaskCancel(this._monitor) {
    if (_monitor != null) {
      _monitor.onCancel.listen((_) {
        _cancelled = true;
        performCancel();
      });
    }
  }

  void performCancel();
}

/**
 * Represent the status of spark job. If the job finishes successfully [success]
 * is true. In case the job fails, the [success] is set false. Optionally, the
 * underlining exception is saved in [exception].
 *
 * TODO(grv): Probably status should be returned by the job manager and contains
 * the job state (waiting, running, done).
 */
class SparkJobStatus {
  String _message;
  String code = SparkStatusCodes.SPARK_JOB_STATUS_UNKNOWN;

  /// Indicates whether the job was successful or failed.
  bool success = true;

  /// The underlining exception object in case the job failed.
  SparkException exception;

  String get message => _message;

  set message(String msg) => _message = msg;

  SparkJobStatus({this.code, String message}) {
    if (message == null) {
      try {
        _message = getStatusMessageFromCode(this.code);
      } catch (e) {
        // Do Nothing.
      }
    } else {
      _message = message;
    }
  }

  static String getStatusMessageFromCode(String code) {
    switch (code) {
      case SparkStatusCodes.SPARK_JOB_BUILD_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_BUILD_SUCCESS_MSG;

      case SparkStatusCodes.SPARK_JOB_IMPORT_FOLDER_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_IMPORT_FOLDER_SUCCESS_MSG;

      case SparkStatusCodes.SPARK_JOB_GIT_PULL_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_PULL_SUCCESS_MSG;
      case SparkStatusCodes.SPARK_JOB_GIT_COMMIT_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_COMMIT_SUCCESS_MSG;
      case SparkStatusCodes.SPARK_JOB_GIT_ADD_SUCCESS:
        return SparkStatusMessages.SPARK_JOB_GIT_ADD_SUCCESS_MSG;
    }

    throw "Message for code : ${code} not found.";
  }
}

class SparkStatusCodes {
  static const String SPARK_JOB_STATUS_OK = "spark.job.status_ok";
  static const String SPARK_JOB_STATUS_UNKNOWN = "spark.job.status_unknown";

  static const String SPARK_JOB_IMPORT_FOLDER_SUCCESS = "spark.job.import.folder_success";

  static const String SPARK_JOB_BUILD_SUCCESS = 'spark.job.build_success';

  static const String SPARK_JOB_GIT_PULL_SUCCESS = "spark.job.git.pull_success";
  static const String SPARK_JOB_GIT_COMMIT_SUCCESS = "spark.job.git.commit_success";
  static const String SPARK_JOB_GIT_ADD_SUCCESS = "spark.job.git.add_success";
}

class SparkStatusMessages {
  static const String SPARK_JOB_BUILD_SUCCESS_MSG = 'Build successful.';

  static const String SPARK_JOB_IMPORT_FOLDER_SUCCESS_MSG = "Import successful.";

  static const String SPARK_JOB_GIT_PULL_SUCCESS_MSG = "Pull successful.";
  static const String SPARK_JOB_GIT_COMMIT_SUCCESS_MSG = "Changes committed.";
  static const String SPARK_JOB_GIT_ADD_SUCCESS_MSG = "Added successfully.";
}
