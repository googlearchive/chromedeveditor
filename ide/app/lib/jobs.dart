// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.jobs;

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:logging/logging.dart';

final Logger _logger = new Logger('spark.jobs');
final NumberFormat _nf = new NumberFormat.decimalPattern();

/**
 * A Job manager. This class can be used to schedule jobs, and provides event
 * notification for job progress.
 */
class JobManager {
  StreamController<JobManagerEvent> _controller =
      new StreamController.broadcast();

  Job _runningJob;
  List<Job> _waitingJobs = new List<Job>();

  /**
   * Will schedule a [job] after all other queued jobs. If no [Job] is currently
   * waiting, [job] will run.
   */
  Future schedule(Job job) {
    Completer completer = job.completer;
    _waitingJobs.add(job);

    if (!isJobRunning) {
      _scheduleNextJob();
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

  void _scheduleNextJob() {
    if (!_waitingJobs.isEmpty) {
      Job job = _waitingJobs.removeAt(0);
      Timer.run(() => _runNextJob(job));
    }
  }

  void _runNextJob(Job job) {
    _runningJob = job;

    _ProgressMonitorImpl monitor = new _ProgressMonitorImpl(this, _runningJob);
    _jobStarted(_runningJob);

    try {
      _runningJob.run(monitor).catchError((e, st) {
        _logger.severe("${_runningJob} errored", e, st);
      }).whenComplete(() {
        _jobFinished(_runningJob);
        _runningJob.done();
        _runningJob = null;
        _scheduleNextJob();
      });
    } catch (e, st) {
      _logger.severe('Error running job ${_runningJob}', e, st);
      _runningJob = null;
      _scheduleNextJob();
    }
  }

  void _jobStarted(Job job) {
    _controller.add(new JobManagerEvent(this, job, started: true));
  }

  void _monitorWorked(_ProgressMonitorImpl monitor, Job job) {
    _controller.add(new JobManagerEvent(this, job,
        indeterminate: monitor.indeterminate, progress: monitor.progress));
  }

  void _monitorDone(_ProgressMonitorImpl monitor, Job job) {
    _controller.add(new JobManagerEvent(this, job,
        indeterminate: monitor.indeterminate, progress: monitor.progress));
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
  final bool indeterminate;
  final double progress;

  JobManagerEvent(this.manager, this.job,
      {this.started: false, this.finished: false, this.indeterminate: false, this.progress: 1.0});

  String toString() {
    if (started) {
      return '${job.name} started';
    } else if (finished) {
      return '${job.name} finished';
    } else {
      return '${job.name} ${(progress * 100).toStringAsFixed(1)}%';
    }
  }
}

/**
 * A long-running task.
 */
abstract class Job {
  final String name;

  Completer _completer;

  Completer get completer => _completer;

  Future get future => _completer.future;

  Job(this.name, [Completer completer]) {
    if (completer != null) {
      _completer = completer;
    } else {
      _completer = new Completer();
    }
  }

  void done() {
    if (_completer != null && !_completer.isCompleted) {
      _completer.complete();
    }
  }

  /**
   * Run this job. The job can optionally provide progress through the given
   * progress monitor. When it finishes, it should complete the [Future] that
   * is returned.
   */
  Future run(ProgressMonitor monitor);

  String toString() => name;
}

/**
 * A simple [Job]. It finishes when the given [Completer] completes.
 */
class ProgressJob extends Job {

  ProgressJob(String name, Completer completer) : super(name, completer);

  Future run(ProgressMonitor monitor) {
    monitor.start(name);
    return _completer.future;
  }
}

/**
 * Outlines a progress monitor with given [title] (the title of the progress
 * monitor), and [maxWork] (the [work] value determining when progress is
 * complete).  A maxWork of 0 indicates that progress cannot be determined.
 */
abstract class ProgressMonitor {
  String _title;
  num _maxWork;
  num _work = 0;
  bool _cancelled = false;
  Completer _cancelledCompleter;
  StreamController _cancelController = new StreamController.broadcast();

  // The job itself can listen to the cancel event, and do the appropriate
  // action.
  Stream get onCancel => _cancelController.stream;

  /**
   * Starts the [ProgressMonitor] with a [title] and a [maxWork] (determining
   * when work is completed)
   */
  void start(String title, [num maxWork = 0]) {
    this._title = title;
    this._maxWork = maxWork;
  }

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
  double get progress => _work / _maxWork;

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

  void start(String title, [num workAmount = 0]) {
    super.start(title, workAmount);

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
    _monitor.onCancel.listen((_) {
      _cancelled = true;
      performCancel();
    });
  }

  void performCancel();
}

