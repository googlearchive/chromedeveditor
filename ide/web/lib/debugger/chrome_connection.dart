// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to introspect the tabs available for a Chrome instance.
 */
library spark.chrome_connection;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

// --remote-debugging-port=9222

// http://localhost:1234/json

class ChromeConnection {
  final String url;

  ChromeConnection(String host, [int port = 9222]) :
      url = 'http://${host}:${port}/json';

  Future<List<ChromeTab>> getTabs() {
    return HttpRequest.getString(url).then((String str) {
      List list = JSON.decode(str);
      return list.map((m) => new ChromeTab.fromMap(m));
    });
  }
}

class ChromeTab {
  final Map _map;

  ChromeTab.fromMap(this._map);

  String get description => _map['description'];
  String get devtoolsFrontendUrl => _map['devtoolsFrontendUrl'];
  String get faviconUrl => _map['faviconUrl'];

  /// Ex. `E1999E8A-EE27-0450-9900-5BFF4C69CA83`.
  String get id => _map['id'];

  String get title => _map['title'];

  /// Ex. `background_page`, `page`.
  String get type => _map['type'];

  String get url => _map['url'];

  /// Ex. `ws://localhost:1234/devtools/page/4F98236D-4EB0-7C6C-5DD1-AF9B6BE4BC71`.
  String get webSocketDebuggerUrl => _map['webSocketDebuggerUrl'];

  bool get hasIcon => _map.containsKey('faviconUrl');
  bool get isChromeExtension => url.startsWith('chrome-extension://');
  bool get isBackgroundPage => type == 'background_page';

  String toString() => url;
}

/*[{
   "description": "",
   "devtoolsFrontendUrl": "/devtools/devtools.html?ws=localhost:1234/devtools/page/E1999E8A-EE27-0450-9900-5BFF4C69CA83",
   "faviconUrl": "chrome://extension-icon/bepbmhgboaologfdajaanbcjmnhjmhfn/24/1",
   "id": "E1999E8A-EE27-0450-9900-5BFF4C69CA83",
   "title": "Google Voice Search",
   "type": "background_page",
   "url": "chrome-extension://bepbmhgboaologfdajaanbcjmnhjmhfn/background.html",
   "webSocketDebuggerUrl": "ws://localhost:1234/devtools/page/E1999E8A-EE27-0450-9900-5BFF4C69CA83"
}, {
   "description": "",
   "devtoolsFrontendUrl": "/devtools/devtools.html?ws=localhost:1234/devtools/page/4A6CAC37-8FE0-7974-0C60-1C62D4082040",
   "id": "4A6CAC37-8FE0-7974-0C60-1C62D4082040",
   "title": "List of Chromium Command Line Switches",
   "type": "page",
   "url": "http://peter.sh/experiments/chromium-command-line-switches/",
   "webSocketDebuggerUrl": "ws://localhost:1234/devtools/page/4A6CAC37-8FE0-7974-0C60-1C62D4082040"
}, {
   "description": "",
   "devtoolsFrontendUrl": "/devtools/devtools.html?ws=localhost:1234/devtools/page/4F98236D-4EB0-7C6C-5DD1-AF9B6BE4BC71",
   "faviconUrl": "https://mail.google.com/mail/u/0/images/2/unreadcountfavicon/20+.png",
   "id": "4F98236D-4EB0-7C6C-5DD1-AF9B6BE4BC71",
   "title": "Inbox (26) - foo@gmail.com - Gmail",
   "type": "page",
   "url": "https://mail.google.com/mail/u/0/?pli=1#inbox",
   "webSocketDebuggerUrl": "ws://localhost:1234/devtools/page/4F98236D-4EB0-7C6C-5DD1-AF9B6BE4BC71"
}]*/
