/**
 * A tiny embedded http server. This is used when launching web apps from Spark.
 */
library spark.server;

import 'dart:async';

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;

const _LOCAL_HOST = '127.0.0.1';

/**
 * TODO:
 */
class PicoServer {
  TcpServer _server;

  /**
   * Create an instance of an http server, bound to the given port. If [port] is
   * `0`, this will bind to any available port.
   */
  static Future<PicoServer> createServer([int port = 0]) {
    return TcpServer.createSocketServer(port).then((TcpServer server) {
      return new PicoServer._(server);
    });
  }

  PicoServer._(this._server) {
    // TODO: use onAccept

  }

  Future<chrome_gen.SocketInfo> getInfo() => _server.getInfo();

  void dispose() {
    _server.disconnect();
  }
}

class SocketException implements Exception {
  final String message;

  const SocketException([this.message = ""]);

  String toString() => "SocketException: $message";
}

class TcpServer {
  int _socketId;
  StreamController<TcpClient> _controller;

  static Future<TcpServer> createSocketServer([int port = 0]) {
    return chrome_gen.socket.create(chrome_gen.SocketType.TCP).then((chrome_gen.CreateInfo info) {
      int socketId = info.socketId;

      return chrome_gen.socket.listen(socketId, _LOCAL_HOST, port, 5).then((int result) {
        if (result < 0) {
          chrome_gen.socket.destroy(socketId);
          throw new SocketException('unable to listen on port ${port}: ${result}');
        } else {
          return new TcpServer._(socketId);
        }
      });
    });
  }

  TcpServer._(this._socketId) {
    _controller = new StreamController(onListen: _accept);
  }

  Stream<TcpClient> get onAccept => _controller.stream;

  Future<chrome_gen.SocketInfo> getInfo() => chrome_gen.socket.getInfo(_socketId);

  void disconnect() {
    chrome_gen.socket.destroy(_socketId);
  }

  void _accept() {
    chrome_gen.socket.accept(_socketId).then((chrome_gen.AcceptInfo info) {
      if (info.resultCode == 0) {
        _controller.add(new TcpClient._fromSocketId(info.socketId));
        _accept();
      } else {
        _controller.addError(info.resultCode);
        _controller.close();
      }
    });
  }
}

class TcpClient {
  String host;
  int port;

  Timer _intervalHandle;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  chrome_gen.SocketType _socketType;
  chrome_gen.CreateInfo _createInfo;
  int get socketId => _createInfo.socketId;

  TcpClient(this.host, this.port);

  TcpClient._fromSocketId(
      int socketId,
      { OnAcceptedCallback connected: null,
        OnReadTcpSocket this.onRead: null,
        OnReceived this.receive: null}) {

    _createInfo = new chrome_gen.CreateInfo(socketId);
    state.then((chrome_gen.SocketInfo socketInfo) {
      port = socketInfo.peerPort;
      host = socketInfo.peerAddress;

      _isConnected = true;
      _setupDataPoll();

      if (connected != null) {
        connected(this, socketInfo);
      }
    });
  }

  Future<chrome_gen.SocketInfo> get state => chrome_gen.socket.getInfo(socketId);

  Future<bool> connect() {
    var completer = new Completer();
    _socketType = chrome_gen.SocketType.TCP;
    chrome_gen.socket.create(_socketType).then((chrome_gen.CreateInfo createInfo) {
      _createInfo = createInfo;
      chrome_gen.socket.connect(_createInfo.socketId, host, port).then((int result) {
        if (result < 0) {
          completer.complete(false);
        } else {
          _isConnected = true;
          //_setupDataPoll();
          completer.complete(_isConnected);
        }
      });
    });
    return completer.future;
  }

  void disconnect() {
    if (_createInfo != null) {
      chrome_gen.socket.disconnect(_createInfo.socketId);
    }

    if (_intervalHandle != null) {
      _intervalHandle.cancel();
    }

    _isConnected = false;
  }

  Future<chrome_gen.SocketWriteInfo> send(String message) {
    return chrome_gen.socket.write(
        _createInfo.socketId, new chrome_gen.ArrayBuffer.fromString(message));
  }

//  void _setupDataPoll() {
//    _intervalHandle =
//        new Timer.periodic(const Duration(milliseconds: 500), _read);
//  }

//  OnReceived receive; // passed a String
//  OnReadTcpSocket onRead; // passed a SocketReadInfo
//
//  void _read(Timer timer) {
//    _logger.fine("enter: read()");
//    Socket.read(_createInfo.socketId).then((SocketReadInfo readInfo) {
//      if (readInfo == null) {
//        return;
//      }
//
//      _logger.fine("then: read()");
//      if (onRead != null) {
//        onRead(readInfo);
//      }
//
//      if (receive != null) {
//        // Convert back to string and invoke receive
//        // Might want to add this kind of method
//        // onto SocketReadInfo
//        /*
//        var blob =
//            new html.Blob([new html.Uint8Array.fromBuffer(readInfo.data)]);
//        var fileReader = new html.FileReader();
//        fileReader.on.load.add((html.Event event) {
//          _logger.fine("fileReader.result = ${fileReader.result}");
//          receive(fileReader.result);
//        });
//        fileReader.readAsText(blob);
//        */
//        _logger.fine(readInfo.data.toString());
//        var str = new String.fromCharCodes(
//            new typed_data.Uint8List.view(readInfo.data));
//        //_logger.fine("receive(str) = ${str}");
//        receive(str, this);
//      }
//    });
//  }

}
