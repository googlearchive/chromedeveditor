# chrome_net

TCP client and server libraries for Dart based Chrome Apps.

`tcp.dart` contains abstractions over `chrome.sockets` to aid in working with
TCP client sockets and server sockets (`TcpClient` and `TcpServer`).

`server.dart` adds a small, prescriptive server (`PicoServer`) that can be
configured with different handlers for HTTP requests.
