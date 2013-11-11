// Copyright (c) 2013, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to use Google Analytics with Chrome Apps. This is a wrapper around
 * the
 * [chrome-platform-analytics](https://github.com/GoogleChrome/chrome-platform-analytics).
 * JavaScript library.
 *
 * Example use:
 *
 *     Tracker tracker;
 *
 *     getService('MyFooApp').then((service) {
 *       tracker = service.getTracker('UA-xxx-1');
 *       tracker.sendAppView('/main');
 *     });
 */
library spark.analytics;

import 'dart:async';
import 'dart:js';

final JsObject _analytics = context['analytics'];

Map<String, GoogleAnalytics> _serviceMap = {};

/**
 * Returns whether the Google Analytics service is available.
 */
bool get available => _analytics != null;

/**
 * Returns a service instance for the named Chrome Platform App. Generally
 * you'll only ever want to call this with a single name that identifies the
 * host Chrome Platform App/Extension or extension using the library. This name
 * is used to scope hits to your app on Google Analytics.
 */
Future<GoogleAnalytics> getService(String appName) {
  if (_serviceMap[appName] != null) {
    return new Future.value(_serviceMap[appName]);
  }

  GoogleAnalytics service = new GoogleAnalytics._(
      _analytics.callMethod('getService', [appName]), appName);
  _serviceMap[appName] = service;
  return service._init();
}

/**
 * Resets the global runtime state for the purposes of testing.
 */
void resetForTesting() {
  _analytics.callMethod('resetForTesting');
}

/**
 * Service object providing access to [Tracker] and [Config] objects. An
 * instance of this can be obtained using [getService].
 */
class GoogleAnalytics extends _ProxyHolder {
  final String appName;

  Config _config;
  Map<String, Tracker> _trackers = {};

  GoogleAnalytics._(JsObject _proxy, this.appName): super(_proxy);

  /**
   * Provides read/write access to the runtime configuration information used by
   * the Google Analytics service classes.
   */
  Config getConfig() => _config;

  /**
   * Creates a new [Tracker] instance. [trackingId] is your Google Analytics
   * tracking id. This id should be for an "app" style property.
   */
  Tracker getTracker(String trackingId) {
    if (_trackers[trackingId] == null) {
      var result = _proxy.callMethod('getTracker', [trackingId]);
      _trackers[trackingId] = new Tracker._(result, this, trackingId);
    }

    return _trackers[trackingId];
  }

  String toString() => 'GoogleAnalytics ${appName}';

  Future<GoogleAnalytics> _init() {
    if (_config != null) return new Future.value(this);

    Completer completer = new Completer();
    var callback = (result) {
      _config = new Config._(result, this);
      completer.complete(this);
    };
    _proxy.callMethod('getConfig').callMethod('addCallback', [callback]);
    return completer.future;
  }
}

/**
 * Provides support for reading and manipulating the configuration of the
 * library. Obtain a instance using the [Service.getConfig].
 */
class Config extends _ProxyHolder {
  final GoogleAnalytics service;

  Config._(JsObject _proxy, this.service): super(_proxy);

  /**
   * Returns true if tracking is enabled.
   */
  bool isTrackingPermitted() => _proxy.callMethod('isTrackingPermitted');

  /**
   * Sets the user sample rate. This can be used if you need to reduce the
   * number of users reporting analytics information to Google Analytics. Most
   * clients will not need to set this.
   */
  void setSampleRate(int sampleRate) {
    _proxy.callMethod('setSampleRate', [sampleRate]);
  }

  /**
   * As a user of this library you must permit users to opt-out of tracking.
   * This method provides support for persistently enabling or disabling
   * tracking for the current user on the current device.
   *
   * When your code calls `setTrackingPermitted(false)` this library will
   * dynamically disable tracking. This means you are free to instrument your
   * application with analytics tracking code, then enable/disable the sending
   * of tracking information with this method. You do NOT need to guard calls to
   * tracking in your code.
   *
   * For further information on how to support opt-out in your application see
   * [Respecting-User-Privacy](https://github.com/GoogleChrome/chrome-platform-analytics/wiki/Respecting-User-Privacy).
   */
  void setTrackingPermitted(bool permitted) {
    _proxy.callMethod('setTrackingPermitted', [permitted]);
  }
}

/**
 * Provides support for sending hits to Google Analytics using convenient named
 * methods like [sendAppView] and [sendEvent] or the general purpose [send]
 * method.
 *
 * Clients can set session values using [set]. These values, once set, are
 * included in all subsequent hits.
 *
 * For analytics hittypes that are not supported by a named method clients can
 * call send with param/value Object describing the hit. Obtain a instance using
 * the [GoogleAnalytics.getTracker].
 */
class Tracker extends _ProxyHolder {
  final GoogleAnalytics service;
  final String trackingId;

  Tracker._(JsObject _proxy, this.service, this.trackingId): super(_proxy);

  /**
   * Sends an AppView hit to Google Analytics. [description] is a unique
   * description of the "screen" (or "place, or "view") within your application.
   * This is should more specific than your app name, but generally not include
   * any runtime data. In most cases all "screens" should be known at the time
   * the app is built. Examples: "MainScreen" or "SettingsView".
   */
  void sendAppView(String description, {bool newSession: false}) {
    if (newSession) {
      send('appView', {'description': description, 'sessionControl': 'new'});
    } else {
      _proxy.callMethod('sendAppView', [description]);
    }
  }

  /**
   * Sends an Event hit to Google Analytics. [category] specifies the event
   * category. [action] specifies the event action, [label] specifies the event
   * label, and [value] specifies the event value. Values must be non-negative.
   */
  void sendEvent(String category, String action, [String label, String value]) {
    _proxy.callMethod('sendEvent', [category, action, label, value]);
  }

  /**
   * Sends an Exception hit to Google Analytics. [description] is the exception
   * description (up to 100 chars), and [fatal] indicates whether the exception
   * was fatal.
   *
   * *Warning:* Do not send the exception message to Google Analytics as it
   * may contain personally identifiable information.
   */
  void sendException([String description, bool fatal]) {
    _proxy.callMethod('sendException', [description, fatal]);
  }

  /**
   * Sends a Social hit to Google Analytics. [network] specifies the social
   * network, for example Facebook or Google Plus.
   */
  void sendSocial(String network, String action, String target) {
    _proxy.callMethod('sendSocial', [network, action, target]);
  }

  /**
   * Sends timing data. [category] specifies the event category. [value] is the
   * number of milliseconds in elapsed time to report to Google Analytics. (e.g.
   * 20). [timingVar] is a string to identify the variable being recorded. (e.g.
   * JavaScript Load). [label] is a string that can be used to add flexibility
   * in visualizing user timings in the reports. (e.g. Google CDN).
   */
  void sendTiming(String category, int value, [String timingVar, String label]) {
    Map m = {'timingCategory': category, 'timingValue': value};

    if (timingVar != null) m['timingVar'] = timingVar;
    if (label != null) m['timingLabel'] = label;

    send('timing', m);
  }

  /**
   * Sets an individual value on the Tracker, replacing any previously set
   * values with the same param. The value is persistent for the life of the
   * Tracker instance, or until replaced with another call to set.
   */
  void set(String param, dynamic value) {
    _proxy.callMethod('set', [param, value]);
  }

  /**
   * Sends a hit to Google Analytics. Caller is responsible for ensuring the
   * validity of the information sent with that hit. Values can be provided
   * either using [set] or using [extraParams].
   *
   * Whenever possible use a named method like [sendAppView] or [sendEvent].
   *
   * Some valid values for [hitType] are `transaction`, `item`, and `timing`.
   */
  void send(String hitType, [Map<String, dynamic> extraParams]) {
    // TODO: JsObject.jsify should accept nulls
    if (extraParams == null) {
      _proxy.callMethod('send', [hitType]);
    } else {
      _proxy.callMethod('send', [hitType, new JsObject.jsify(extraParams)]);
    }
  }

  String toString() => 'Tracker ${trackingId}';
}

abstract class _ProxyHolder {
  JsObject _proxy;

  _ProxyHolder(this._proxy);
}
