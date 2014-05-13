// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * developerPrivate API. This is a private API exposing developing and debugging
 * functionalities for apps and extensions.
 */
library spark.developer_private;

import 'package:chrome/src/files.dart';
import 'package:chrome/src/common.dart';

/**
 * Accessor for the `chrome.developerPrivate` namespace.
 */
final ChromeDeveloperPrivate developerPrivate = new ChromeDeveloperPrivate._();

class ChromeDeveloperPrivate extends ChromeApi {
  static final JsObject _developerPrivate = chrome['developerPrivate'];

  ChromeDeveloperPrivate._();

  bool get available => _developerPrivate != null;

  /**
   * Runs auto update for extensions and apps immediately.
   * [callback]: Called with the boolean result, true if autoUpdate is
   * successful.
   */
  Future<bool> autoUpdate() {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<bool>.oneArg();
    _developerPrivate.callMethod('autoUpdate', [completer.callback]);
    return completer.future;
  }

  /**
   * Returns information of all the extensions and apps installed.
   * [include_disabled]: include disabled items.
   * [include_terminated]: include terminated items.
   * [callback]: Called with items info.
   */
  Future<List<ItemInfo>> getItemsInfo(bool include_disabled, bool include_terminated) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<List<ItemInfo>>.oneArg((e) => listify(e, _createItemInfo));
    _developerPrivate.callMethod('getItemsInfo', [include_disabled, include_terminated, completer.callback]);
    return completer.future;
  }

  /**
   * Opens a permissions dialog for given [itemId].
   */
  Future showPermissionsDialog(String itemId) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('showPermissionsDialog', [itemId, completer.callback]);
    return completer.future;
  }

  /**
   * Opens an inspect window for given [options]
   */
  Future inspect(InspectOptions options) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('inspect', [jsify(options), completer.callback]);
    return completer.future;
  }

  /**
   * Enable / Disable file access for a given [item_id]
   */
  Future allowFileAccess(String item_id, bool allow) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('allowFileAccess', [item_id, allow, completer.callback]);
    return completer.future;
  }

  /**
   * Reloads a given item with [itemId].
   */
  Future reload(String itemId) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('reload', [itemId, completer.callback]);
    return completer.future;
  }

  /**
   * Enable / Disable a given item with id [itemId].
   */
  Future enable(String itemId, bool enable) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('enable', [itemId, enable, completer.callback]);
    return completer.future;
  }

  /**
   * Allow / Disallow item with [item_id] in incognito mode.
   */
  Future allowIncognito(String item_id, bool allow) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('allowIncognito', [item_id, allow, completer.callback]);
    return completer.future;
  }

  /**
   * Load a user selected unpacked item
   */
  Future loadUnpacked() {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter.noArgs();
    _developerPrivate.callMethod('loadUnpacked', [completer.callback]);
    return completer.future;
  }

  /**
   * Loads an extension / app from a given [directory]
   */
  Future<String> loadDirectory(DirectoryEntry directory) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<String>.oneArg();
    _developerPrivate.callMethod('loadDirectory', [jsify(directory), completer.callback]);
    return completer.future;
  }

  /**
   * Open Dialog to browse to an entry.
   * [select_type]: Select a file or a folder.
   * [file_type]: Required file type. For Example pem type is for private key
   * and load type is for an unpacked item.
   * [callback]: called with selected item's path.
   */
  Future<String> choosePath(SelectType select_type, FileType file_type) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<String>.oneArg();
    _developerPrivate.callMethod('choosePath', [jsify(select_type), jsify(file_type), completer.callback]);
    return completer.future;
  }

  /**
   * Pack an item with given [path] and [private_key_path]
   * [callback]: called with the success result string.
   */
  Future<PackDirectoryResponse> packDirectory(String path, String private_key_path, int flags) {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<PackDirectoryResponse>.oneArg(_createPackDirectoryResponse);
    _developerPrivate.callMethod('packDirectory', [path, private_key_path, flags, completer.callback]);
    return completer.future;
  }

  /**
   * Returns true if the profile is managed.
   */
  Future<bool> isProfileManaged() {
    if (_developerPrivate == null) _throwNotAvailable();

    var completer = new ChromeCompleter<bool>.oneArg();
    _developerPrivate.callMethod('isProfileManaged', [completer.callback]);
    return completer.future;
  }

//  /**
//   * Reads and returns the contents of a file related to an extension which
//   * caused an error. The expected argument is a dictionary with the following
//   * entries: - pathSuffix: The path of the file, relative to the extension;
//   * e.g., manifest.json, script.js, or main.html. - extensionId: The ID of the
//   * extension owning the file. - errorMessage: The error message which was
//   * thrown as a result of the error in the file. - manifestKey (required for
//   * "manifest.json" file): The key in the manifest which caused the error
//   * (e.g., "permissions"). - manifestSpecific (optional for "manifest.json"
//   * file): The specific portion of the manifest key which caused the error
//   * (e.g., "foo" in the "permissions" key). - lineNumber (optional for
//   * non-manifest files): The line number which caused the error. The callback
//   * is called with a dictionary with three keys: - highlight: The region of the
//   * code which threw the error, and should be highlighted. - beforeHighlight:
//   * The region before the "highlight" portion. - afterHighlight: The region
//   * after the "highlight" portion. - highlight: The region of the code which
//   * threw the error. If the region which threw the error was not found, the
//   * full contents of the file will be in the "beforeHighlight" section.
//   */
//  Future<dynamic> requestFileSource(var dict) {
//    if (_developerPrivate == null) _throwNotAvailable();
//
//    var completer = new ChromeCompleter.oneArg(_createany);
//    _developerPrivate.callMethod('requestFileSource', [jsify(dict), completer.callback]);
//    return completer.future;
//  }

  /**
   * Open the developer tools to focus on a particular error. The expected
   * argument is a dictionary with the following entries: - renderViewId: The ID
   * of the render view in which the error occurred. - renderProcessId: The ID
   * of the process in which the error occurred. - url (optional): The URL in
   * which the error occurred. - lineNumber (optional): The line to focus the
   * devtools at. - columnNumber (optional): The column to focus the devtools
   * at.
   */
  void openDevTools(var dict) {
    if (_developerPrivate == null) _throwNotAvailable();

    _developerPrivate.callMethod('openDevTools', [jsify(dict)]);
  }

//  Stream<EventData> get onItemStateChanged => _onItemStateChanged.stream;
//
//  final ChromeStreamController<EventData> _onItemStateChanged =
//      new ChromeStreamController<EventData>.oneArg(() => _developerPrivate,
//          'onItemStateChanged', _createEventData);

  void _throwNotAvailable() {
    throw new UnsupportedError("'chrome.developerPrivate' is not available");
  }
}

class ItemType extends ChromeEnum {
  static const ItemType HOSTED_APP = const ItemType._('hosted_app');
  static const ItemType PACKAGED_APP = const ItemType._('packaged_app');
  static const ItemType LEGACY_PACKAGED_APP = const ItemType._('legacy_packaged_app');
  static const ItemType EXTENSION = const ItemType._('extension');
  static const ItemType THEME = const ItemType._('theme');

  static const List<ItemType> VALUES = const[HOSTED_APP, PACKAGED_APP, LEGACY_PACKAGED_APP, EXTENSION, THEME];

  const ItemType._(String str): super(str);
}

class PackStatus extends ChromeEnum {
  static const PackStatus SUCCESS = const PackStatus._('SUCCESS');
  static const PackStatus ERROR = const PackStatus._('ERROR');
  static const PackStatus WARNING = const PackStatus._('WARNING');

  static const List<PackStatus> VALUES = const[SUCCESS, ERROR, WARNING];

  const PackStatus._(String str): super(str);
}

class FileType extends ChromeEnum {
  static const FileType LOAD = const FileType._('LOAD');
  static const FileType PEM = const FileType._('PEM');

  static const List<FileType> VALUES = const[LOAD, PEM];

  const FileType._(String str): super(str);
}

class SelectType extends ChromeEnum {
  static const SelectType FILE = const SelectType._('FILE');
  static const SelectType FOLDER = const SelectType._('FOLDER');

  static const List<SelectType> VALUES = const[FILE, FOLDER];

  const SelectType._(String str): super(str);
}

class EventType extends ChromeEnum {
  static const EventType INSTALLED = const EventType._('INSTALLED');
  static const EventType UNINSTALLED = const EventType._('UNINSTALLED');
  static const EventType LOADED = const EventType._('LOADED');
  static const EventType UNLOADED = const EventType._('UNLOADED');
  static const EventType VIEW_REGISTERED = const EventType._('VIEW_REGISTERED');
  static const EventType VIEW_UNREGISTERED = const EventType._('VIEW_UNREGISTERED');
  static const EventType ERROR_ADDED = const EventType._('ERROR_ADDED');

  static const List<EventType> VALUES = const[INSTALLED, UNINSTALLED, LOADED, UNLOADED, VIEW_REGISTERED, VIEW_UNREGISTERED, ERROR_ADDED];

  const EventType._(String str): super(str);
}

class ItemInspectView extends ChromeObject {
  ItemInspectView({String path, int render_process_id, int render_view_id, bool incognito, bool generatedBackgroundPage}) {
    if (path != null) this.path = path;
    if (render_process_id != null) this.render_process_id = render_process_id;
    if (render_view_id != null) this.render_view_id = render_view_id;
    if (incognito != null) this.incognito = incognito;
    if (generatedBackgroundPage != null) this.generatedBackgroundPage = generatedBackgroundPage;
  }
  ItemInspectView.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get path => jsProxy['path'];
  set path(String value) => jsProxy['path'] = value;

  int get render_process_id => jsProxy['render_process_id'];
  set render_process_id(int value) => jsProxy['render_process_id'] = value;

  int get render_view_id => jsProxy['render_view_id'];
  set render_view_id(int value) => jsProxy['render_view_id'] = value;

  bool get incognito => jsProxy['incognito'];
  set incognito(bool value) => jsProxy['incognito'] = value;

  bool get generatedBackgroundPage => jsProxy['generatedBackgroundPage'];
  set generatedBackgroundPage(bool value) => jsProxy['generatedBackgroundPage'] = value;
}

class InstallWarning extends ChromeObject {
  InstallWarning({String message}) {
    if (message != null) this.message = message;
  }
  InstallWarning.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get message => jsProxy['message'];
  set message(String value) => jsProxy['message'] = value;
}

class ItemInfo extends ChromeObject {
  ItemInfo({String id, String name, String version, String description, bool may_disable, bool enabled, String disabled_reason, bool isApp, ItemType type, bool allow_activity, bool allow_file_access, bool wants_file_access, bool incognito_enabled, bool is_unpacked, bool allow_reload, bool terminated, bool allow_incognito, String icon_url, String path, String options_url, String app_launch_url, String homepage_url, String update_url, List<InstallWarning> install_warnings, List manifest_errors, List runtime_errors, bool offline_enabled, List<ItemInspectView> views}) {
    if (id != null) this.id = id;
    if (name != null) this.name = name;
    if (version != null) this.version = version;
    if (description != null) this.description = description;
    if (may_disable != null) this.may_disable = may_disable;
    if (enabled != null) this.enabled = enabled;
    if (disabled_reason != null) this.disabled_reason = disabled_reason;
    if (isApp != null) this.isApp = isApp;
    if (type != null) this.type = type;
    if (allow_activity != null) this.allow_activity = allow_activity;
    if (allow_file_access != null) this.allow_file_access = allow_file_access;
    if (wants_file_access != null) this.wants_file_access = wants_file_access;
    if (incognito_enabled != null) this.incognito_enabled = incognito_enabled;
    if (is_unpacked != null) this.is_unpacked = is_unpacked;
    if (allow_reload != null) this.allow_reload = allow_reload;
    if (terminated != null) this.terminated = terminated;
    if (allow_incognito != null) this.allow_incognito = allow_incognito;
    if (icon_url != null) this.icon_url = icon_url;
    if (path != null) this.path = path;
    if (options_url != null) this.options_url = options_url;
    if (app_launch_url != null) this.app_launch_url = app_launch_url;
    if (homepage_url != null) this.homepage_url = homepage_url;
    if (update_url != null) this.update_url = update_url;
    if (install_warnings != null) this.install_warnings = install_warnings;
//    if (manifest_errors != null) this.manifest_errors = manifest_errors;
//    if (runtime_errors != null) this.runtime_errors = runtime_errors;
    if (offline_enabled != null) this.offline_enabled = offline_enabled;
    if (views != null) this.views = views;
  }
  ItemInfo.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get id => jsProxy['id'];
  set id(String value) => jsProxy['id'] = value;

  String get name => jsProxy['name'];
  set name(String value) => jsProxy['name'] = value;

  String get version => jsProxy['version'];
  set version(String value) => jsProxy['version'] = value;

  String get description => jsProxy['description'];
  set description(String value) => jsProxy['description'] = value;

  bool get may_disable => jsProxy['may_disable'];
  set may_disable(bool value) => jsProxy['may_disable'] = value;

  bool get enabled => jsProxy['enabled'];
  set enabled(bool value) => jsProxy['enabled'] = value;

  String get disabled_reason => jsProxy['disabled_reason'];
  set disabled_reason(String value) => jsProxy['disabled_reason'] = value;

  bool get isApp => jsProxy['isApp'];
  set isApp(bool value) => jsProxy['isApp'] = value;

  ItemType get type => _createItemType(jsProxy['type']);
  set type(ItemType value) => jsProxy['type'] = jsify(value);

  bool get allow_activity => jsProxy['allow_activity'];
  set allow_activity(bool value) => jsProxy['allow_activity'] = value;

  bool get allow_file_access => jsProxy['allow_file_access'];
  set allow_file_access(bool value) => jsProxy['allow_file_access'] = value;

  bool get wants_file_access => jsProxy['wants_file_access'];
  set wants_file_access(bool value) => jsProxy['wants_file_access'] = value;

  bool get incognito_enabled => jsProxy['incognito_enabled'];
  set incognito_enabled(bool value) => jsProxy['incognito_enabled'] = value;

  bool get is_unpacked => jsProxy['is_unpacked'];
  set is_unpacked(bool value) => jsProxy['is_unpacked'] = value;

  bool get allow_reload => jsProxy['allow_reload'];
  set allow_reload(bool value) => jsProxy['allow_reload'] = value;

  bool get terminated => jsProxy['terminated'];
  set terminated(bool value) => jsProxy['terminated'] = value;

  bool get allow_incognito => jsProxy['allow_incognito'];
  set allow_incognito(bool value) => jsProxy['allow_incognito'] = value;

  String get icon_url => jsProxy['icon_url'];
  set icon_url(String value) => jsProxy['icon_url'] = value;

  String get path => jsProxy['path'];
  set path(String value) => jsProxy['path'] = value;

  String get options_url => jsProxy['options_url'];
  set options_url(String value) => jsProxy['options_url'] = value;

  String get app_launch_url => jsProxy['app_launch_url'];
  set app_launch_url(String value) => jsProxy['app_launch_url'] = value;

  String get homepage_url => jsProxy['homepage_url'];
  set homepage_url(String value) => jsProxy['homepage_url'] = value;

  String get update_url => jsProxy['update_url'];
  set update_url(String value) => jsProxy['update_url'] = value;

  List<InstallWarning> get install_warnings => listify(jsProxy['install_warnings'], _createInstallWarning);
  set install_warnings(List<InstallWarning> value) => jsProxy['install_warnings'] = jsify(value);

//  List<dynamic> get manifest_errors => listify(jsProxy['manifest_errors'], _createany);
//  set manifest_errors(List value) => jsProxy['manifest_errors'] = jsify(value);

//  List get runtime_errors => listify(jsProxy['runtime_errors'], _createany);
//  set runtime_errors(List value) => jsProxy['runtime_errors'] = jsify(value);

  bool get offline_enabled => jsProxy['offline_enabled'];
  set offline_enabled(bool value) => jsProxy['offline_enabled'] = value;

  List<ItemInspectView> get views => listify(jsProxy['views'], _createItemInspectView);
  set views(List<ItemInspectView> value) => jsProxy['views'] = jsify(value);
}

class InspectOptions extends ChromeObject {
  InspectOptions({String extension_id, String render_process_id, String render_view_id, bool incognito}) {
    if (extension_id != null) this.extension_id = extension_id;
    if (render_process_id != null) this.render_process_id = render_process_id;
    if (render_view_id != null) this.render_view_id = render_view_id;
    if (incognito != null) this.incognito = incognito;
  }
  InspectOptions.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get extension_id => jsProxy['extension_id'];
  set extension_id(String value) => jsProxy['extension_id'] = value;

  String get render_process_id => jsProxy['render_process_id'];
  set render_process_id(String value) => jsProxy['render_process_id'] = value;

  String get render_view_id => jsProxy['render_view_id'];
  set render_view_id(String value) => jsProxy['render_view_id'] = value;

  bool get incognito => jsProxy['incognito'];
  set incognito(bool value) => jsProxy['incognito'] = value;
}

class PackDirectoryResponse extends ChromeObject {
  PackDirectoryResponse({String message, String item_path, String pem_path, int override_flags, PackStatus status}) {
    if (message != null) this.message = message;
    if (item_path != null) this.item_path = item_path;
    if (pem_path != null) this.pem_path = pem_path;
    if (override_flags != null) this.override_flags = override_flags;
    if (status != null) this.status = status;
  }
  PackDirectoryResponse.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get message => jsProxy['message'];
  set message(String value) => jsProxy['message'] = value;

  String get item_path => jsProxy['item_path'];
  set item_path(String value) => jsProxy['item_path'] = value;

  String get pem_path => jsProxy['pem_path'];
  set pem_path(String value) => jsProxy['pem_path'] = value;

  int get override_flags => jsProxy['override_flags'];
  set override_flags(int value) => jsProxy['override_flags'] = value;

  PackStatus get status => _createPackStatus(jsProxy['status']);
  set status(PackStatus value) => jsProxy['status'] = jsify(value);
}

class ProjectInfo extends ChromeObject {
  ProjectInfo({String name}) {
    if (name != null) this.name = name;
  }
  ProjectInfo.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  String get name => jsProxy['name'];
  set name(String value) => jsProxy['name'] = value;
}

class EventData extends ChromeObject {
  EventData({EventType event_type, String item_id}) {
    if (event_type != null) this.event_type = event_type;
    if (item_id != null) this.item_id = item_id;
  }
  EventData.fromProxy(JsObject jsProxy): super.fromProxy(jsProxy);

  EventType get event_type => _createEventType(jsProxy['event_type']);
  set event_type(EventType value) => jsProxy['event_type'] = jsify(value);

  String get item_id => jsProxy['item_id'];
  set item_id(String value) => jsProxy['item_id'] = value;
}

ItemInfo _createItemInfo(JsObject jsProxy) => jsProxy == null ? null : new ItemInfo.fromProxy(jsProxy);
PackDirectoryResponse _createPackDirectoryResponse(JsObject jsProxy) => jsProxy == null ? null : new PackDirectoryResponse.fromProxy(jsProxy);
//any _createany(JsObject jsProxy) => jsProxy == null ? null : new any.fromProxy(jsProxy);
EventData _createEventData(JsObject jsProxy) => jsProxy == null ? null : new EventData.fromProxy(jsProxy);
ItemType _createItemType(String value) => ItemType.VALUES.singleWhere((ChromeEnum e) => e.value == value);
InstallWarning _createInstallWarning(JsObject jsProxy) => jsProxy == null ? null : new InstallWarning.fromProxy(jsProxy);
ItemInspectView _createItemInspectView(JsObject jsProxy) => jsProxy == null ? null : new ItemInspectView.fromProxy(jsProxy);
PackStatus _createPackStatus(String value) => PackStatus.VALUES.singleWhere((ChromeEnum e) => e.value == value);
EventType _createEventType(String value) => EventType.VALUES.singleWhere((ChromeEnum e) => e.value == value);
