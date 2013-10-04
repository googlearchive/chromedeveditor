
library spark.server_test;

import 'package:chrome_gen/chrome_app.dart' as chrome_gen;
import 'package:unittest/unittest.dart';

import '../lib/server.dart';

main() {
  group('TcpServer', () {
    test('connect disconnect', () {
      return TcpServer.createSocketServer().then((TcpServer server) {
        expect(server, isNotNull);
        server.disconnect();
      });
    });
    test('bind to any port', () {
      return TcpServer.createSocketServer().then((TcpServer server) {
        return server.getInfo().then((chrome_gen.SocketInfo info) {
          print("bound to port ${info.localPort}");
          print("localAddress = ${info.localAddress}");
          expect(info.localAddress, isNotNull);
          expect(info.localPort, greaterThan(0));
          server.disconnect();
        });
      });
    });
    test('bind to a specific port', () {
      return TcpServer.createSocketServer(37123).then((TcpServer server) {
        return server.getInfo().then((chrome_gen.SocketInfo info) {
          expect(info.localAddress, isNotNull);
          expect(info.localPort, 37123);
          server.disconnect();
        });
      });
    });
  });


}
