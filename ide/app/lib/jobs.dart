library drake.jobs;

import 'dart:async';

/**
 * A Job manager. This class can be used to schedule jobs, and provides event
 * notification for job progress.
 *
 * This class is available as a singleton on the workbench.
 */
class JobManager {
  StreamController<JobManagerEvent> _streamController =
      new StreamController<JobManagerEvent>();
  Stream<JobManagerEvent> _stream;

  Job _runningJob;
  List<Job> _waitingJobs = new List<Job>();

  JobManager() {
    _stream = _streamController.stream.asBroadcastStream();
  }

  /**
   * TODO:
   */
  void schedule(Job job) {
    _waitingJobs.add(job);

    if (!isJobRunning) {
      _scheduleNextJob();
    }
  }

  /**
   * TODO:
   */
  bool get isJobRunning => _runningJob != null;

  /**
   * TODO:
   */
  Stream<JobManagerEvent> get onChange => _stream;

  void _scheduleNextJob() {
    if (!_waitingJobs.isEmpty) {
      Timer.run(() => _runNextJob());
    }
  }

  void _runNextJob() {
    _runningJob = _waitingJobs.removeAt(0);

    _ProgressMonitorImpl monitor = new _ProgressMonitorImpl(this, _runningJob);
    _jobStarted(_runningJob);

    Future future = _runningJob.run(monitor).whenComplete(() {
      _jobFinished(_runningJob);
      _runningJob = null;

      _scheduleNextJob();
    });
  }

  _jobStarted(Job job) {
    _streamController.add(new JobManagerEvent(this, job, started: true));
  }

  _monitorWorked(_ProgressMonitorImpl monitor, Job job) {
    _streamController.add(new JobManagerEvent(this, job,
        indeterminate: monitor.indeterminate, progress: monitor.progress));
  }

  _monitorDone(_ProgressMonitorImpl monitor, Job job) {
    _streamController.add(new JobManagerEvent(this, job,
        indeterminate: monitor.indeterminate, progress: monitor.progress));
  }

  _jobFinished(Job job) {
    _streamController.add(new JobManagerEvent(this, job, finished: true));
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
      {this.started, this.finished, this.indeterminate, this.progress: 1.0});

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

  Job(this.name);

  /**
   * Run this job. The job can optionally provide progress through the given
   * progress monitor. When it finishes, it should complete the [Future] that
   * is returned.
   */
  Future<Job> run(ProgressMonitor monitor);

  String toString() => name;
}

/**
 * TODO:
 */
abstract class ProgressMonitor {
  String _title;
  num _maxWork;
  num _work = 0;

  /**
   * TODO:
   */
  void start(String title, [num workAmount = 0]) {
    this._title = title;
    this._maxWork = workAmount;
  }

  /**
   * TODO:
   */
  num get work => _work;

  /**
   * TODO:
   */
  num get maxWork => _maxWork;

  /**
   * TODO:
   */
  bool get indeterminate => maxWork == 0;

  /**
   * TODO:
   */
  double get progress => _work / _maxWork;

  /**
   * TODO:
   */
  void worked(num amount) {
    _work += amount;

    if (_work > maxWork) {
      _work = maxWork;
    }
  }

  /**
   * TODO:
   */
  void done() {
    _work = maxWork;
  }
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