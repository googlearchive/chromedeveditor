// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/**
 * A library to communicate over the Android ADB protocol.
 */
library spark.adb;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:chrome/chrome_app.dart' as chrome;
import 'package:chrome/chrome_app.dart'
    show ConnectionHandle, Device, InterfaceDescriptor, TransferResultInfo;
import 'package:cipher/cipher.dart';
import 'package:cipher/impl/base.dart' as CipherBase;
import 'package:logging/logging.dart';

import '../preferences.dart';
import '../utils.dart';
import 'android_rsa.dart';
import 'android_rsa_cipher.dart';

Logger _logger = new Logger('spark.adb');

// Most of these are helper classes that don't really need to be exported,
// and might be better off in an internal library.
class AdbUtil {
  // ADB command names
  static final int A_SYNC = 0x434e5953;
  static final int A_CNXN = 0x4e584e43;
  static final int A_OPEN = 0x4e45504f;
  static final int A_OKAY = 0x59414b4f;
  static final int A_CLSE = 0x45534c43;
  static final int A_WRTE = 0x45545257;
  static final int A_AUTH = 0x48545541;

  // ADB protocol version
  static final int A_VERSION = 0x01000000;

  static final int MESSAGE_SIZE_PAYLOAD = 24;
  static final int MAX_PAYLOAD = 4096;
  static final int ADB_VERSION_MINOR = 0; // Used for help/version info.

  // Increment this when we want to force users to start a new ADB server.
  static final int ADB_SERVER_VERSION = 31;

  // USB information
  static final int ADB_CLASS = 0xff;
  static final int ADB_SUBCLASS = 0x42;
  static final int ADB_PROTOCOL = 0x1;

  // Types for AUTH commands
  static final int ADB_AUTH_TOKEN = 1;
  static final int ADB_AUTH_SIGNATURE = 2;
  static final int ADB_AUTH_RSAPUBLICKEY = 3;

  // Some helper functions.
  static int checksum(ByteData data) {
    int result = 0;
    var buffer = new Uint8List.view(data.buffer);
    for (int i = 0; i < buffer.length; i++) {
      int x = buffer[i];
      if (x < 0) {
        x += 256;
      }
      result += x;
    }
    return result;
  }
}

class SystemIdentity {
  // Can be 'host', 'bootloader', 'device'.
  String systemType = 'host';
  String serialno = '';
  String banner = '';
  String toString() => '${systemType}:${serialno}:${banner}';
}

class AdbMessage {
  static final int _COMMAND_OFFSET = 0;
  static final int _ARG0_OFFSET = 4;
  static final int _ARG1_OFFSET = 8;
  static final int _DATA_LENGTH_OFFSET = 12;
  static final int _CHECKSUM_OFFSET = 16;
  static final int _MAGIC_OFFSET = 20;

  ByteData messageBuffer = new ByteData(AdbUtil.MESSAGE_SIZE_PAYLOAD);
  ByteData dataBuffer;

  int _getInt32(offset) =>
      messageBuffer.getInt32(offset, Endianness.LITTLE_ENDIAN);

  void _setInt32(offset, value) =>
      messageBuffer.setInt32(offset, value, Endianness.LITTLE_ENDIAN);

  /*
  struct message {
    unsigned command;       // command identifier constant
    unsigned arg0;          // first argument
    unsigned arg1;          // second argument
    unsigned data_length;   // length of payload (0 is allowed)
    unsigned data_crc32;    // crc32 of data payload
    unsigned magic;         // command ^ 0xffffffff
  };
  */
  int  get command => _getInt32(_COMMAND_OFFSET);
  void set command(int value) => _setInt32(_COMMAND_OFFSET, value);
  int  get arg0 => _getInt32(_ARG0_OFFSET);
  void set arg0(int value) => _setInt32(_ARG0_OFFSET, value);
  int  get arg1 => _getInt32(_ARG1_OFFSET);
  void set arg1(int value) => _setInt32(_ARG1_OFFSET, value);
  int  get dataLength => _getInt32(_DATA_LENGTH_OFFSET);
  void set dataLength(int value) => _setInt32(_DATA_LENGTH_OFFSET, value);
  int  get dataCrc32 => _getInt32(_CHECKSUM_OFFSET);
  void set dataCrc32(int value) => _setInt32(_CHECKSUM_OFFSET, value);
  int  get magic => _getInt32(_MAGIC_OFFSET);
  void set magic(int value) => _setInt32(_MAGIC_OFFSET, value);

  AdbMessage(int command, int arg0, int arg1, [String data = null]) {
    if (data != null) {
      // Build a dataBuffer.
      dataBuffer = new ByteData(data.length);
      Uint8List u8data = new Uint8List.fromList(data.codeUnits);
      Uint8List u8DataBufferView = new Uint8List.view(dataBuffer.buffer);
      for (int i = 0; i < u8data.length; i++) {
        u8DataBufferView[i] = u8data[i];
      }
    }

    this.command = command;
    this.arg0 = arg0;
    this.arg1 = arg1;
    this.dataLength = data != null ? data.length : 0;
    this.dataCrc32 = data != null ? AdbUtil.checksum(dataBuffer) : 0;
    this.magic = command ^ 0xffffffff;
  }

  AdbMessage.fromMessageBufferBytes(List<int> bytes) {
    Uint8List u8data = new Uint8List.fromList(bytes);
    Uint8List u8MessageBufferView = new Uint8List.view(messageBuffer.buffer);
    for (int i = 0; i < u8data.length; i++) {
      u8MessageBufferView[i] = u8data[i];
    }
  }

  // Read into dataBuffer.
  // To be used on receiving the data of an incoming message.
  void loadDataBuffer(List<int> data) {
    // Rely on the messageBuffer's information.
    dataBuffer = new ByteData(dataLength);
    Uint8List u8data = new Uint8List.fromList(data);
    Uint8List u8DataBufferView = new Uint8List.view(dataBuffer.buffer);
    for (int i = 0; i < u8data.length; i++) {
      u8DataBufferView[i] = u8data[i];
    }
  }

  // To be used on freshly created messages, that don't have their length or crc
  // fields set yet.
  void setData(ByteData data) {
    dataBuffer = new ByteData(data.lengthInBytes);
    Uint8List u8data = new Uint8List.view(data.buffer);
    Uint8List u8DataBufferView = new Uint8List.view(dataBuffer.buffer);
    for (int i = 0; i < u8data.length; i++) {
      u8DataBufferView[i] = u8data[i];
    }

    dataLength = data.lengthInBytes;
    dataCrc32 = AdbUtil.checksum(data);
  }

  String toString() {
    StringBuffer sb = new StringBuffer()
        ..write('[command = ${command.toRadixString(16)}, ')
        ..write('arg0 = ${arg0.toRadixString(16)}, ')
        ..write('arg1 = ${arg1.toRadixString(16)}, ')
        ..write('dataLength = ${dataLength.toRadixString(16)}, ')
        ..write('dataCrc32 = ${dataCrc32.toRadixString(16)}, ')
        ..write('magic = ${magic.toRadixString(16)}]');

    if (dataBuffer != null) {
      sb.write('[');
      Uint8List u8DataBufferView = new Uint8List.view(dataBuffer.buffer);
      for (int i = 0; i < u8DataBufferView.length; i++) {
        if (i + 1 != u8DataBufferView.length) {
          sb.write('${u8DataBufferView[i].toRadixString(16)}, ');
        } else {
          sb.write('${u8DataBufferView[i].toRadixString(16)}]');
        }
      }
    }

    return sb.toString();
  }
}

class AndroidDevice {
  Device androidDevice;
  InterfaceDescriptor adbInterface;
  chrome.EndpointDescriptor inDescriptor;
  chrome.EndpointDescriptor outDescriptor;
  ConnectionHandle adbConnectionHandle;
  PreferenceStore _prefs;

  String deviceToken = 'DEVICE TOKEN NOT SET';

  AndroidDevice(this._prefs) {
    // The cipher library needs initializing before it can be used.
    // This function is safe to call multiple times.
    CipherBase.initCipher();
  }

  // TODO: add generic type info to the Future
  Future listDevices() {
    // TODO (shepheb): List all Android devices.
    return new Future.value([]);
  }

  // Returns the best device for an ADB connection.
  Future _getPluggedDevice(vendorId, productId) {
    chrome.EnumerateDevicesOptions edo = new chrome.EnumerateDevicesOptions(
          vendorId: vendorId, productId: productId);

    // Get the devices with the given vendor id and product id.
    return chrome.usb.getDevices(edo).then((List<Device> devices) {
      if (devices.length == 0) {
        return new Future.error('no-device');
      }

      // For each such device, look for a specific device with ADB class,
      // subclass and protocol.
      // TODO(shepheb): Handle finding multiple ADB devices.
      Device resultDevice = null;
      return Future.forEach(devices, (Device device) {
        chrome.EnumerateDevicesAndRequestAccessOptions opts =
            new chrome.EnumerateDevicesAndRequestAccessOptions(
                vendorId: device.vendorId, productId: device.productId);
        return chrome.usb.findDevices(opts).then((List<ConnectionHandle> connections) {
          if (connections.length == 0) {
            return new Future.error('no-connection');
          } else {
            // It's a valid device. Use it as the result.
            resultDevice = device;
          }
        });
      }).then((_) {
        return resultDevice;
      });
    });
  }

  // Either resolves on successful open, or rejects with an error message on failure.
  Future open(vendorId, productId) {
    return _getPluggedDevice(vendorId, productId).then((Device device) {
      chrome.EnumerateDevicesAndRequestAccessOptions opts =
          new chrome.EnumerateDevicesAndRequestAccessOptions(
              vendorId: device.vendorId, productId: device.productId);
      return chrome.usb.findDevices(opts).then(
          (List<ConnectionHandle> connections) {
        return Future.forEach(connections, (ConnectionHandle handle) {
          return _checkDevice(handle, device);
        });
      });
    });
  }

  // Returns an Error future when it finds a valid device. This is part of the
  // flow of open() above.
  Future _checkDevice(ConnectionHandle handle, Device device) {
    // List all interfaces on this connection handle.
    return chrome.usb.listInterfaces(handle).then((List<InterfaceDescriptor> interfaces) {
      // For each interface, find the match for ADB class, subclass and
      // protocol.
      interfaces.forEach((interface) {
        // Check to make sure interface class, subclass and protocol
        // match ADB.
        // Avoid opening mass storage endpoints (they're slow).
        if (interface.interfaceClass == AdbUtil.ADB_CLASS &&
            interface.interfaceSubclass == AdbUtil.ADB_SUBCLASS &&
            interface.interfaceProtocol == AdbUtil.ADB_PROTOCOL) {
          adbInterface = interface;
          androidDevice = device;
          this.adbConnectionHandle = handle;
        }

        interface.endpoints.forEach((chrome.EndpointDescriptor desc) {
          // Find the input and output descriptors.
          if (desc.direction == chrome.Direction.IN &&
              interface.interfaceClass == AdbUtil.ADB_CLASS &&
              interface.interfaceSubclass == AdbUtil.ADB_SUBCLASS &&
              interface.interfaceProtocol == AdbUtil.ADB_PROTOCOL) {
            inDescriptor = desc;
          } else if (desc.direction == chrome.Direction.OUT &&
              interface.interfaceClass == AdbUtil.ADB_CLASS &&
              interface.interfaceSubclass == AdbUtil.ADB_SUBCLASS &&
              interface.interfaceProtocol == AdbUtil.ADB_PROTOCOL) {
            outDescriptor = desc;
          }
        });
      });

      // Check if all parts of the device got assigned.
      if (adbInterface != null && androidDevice != null &&
          this.adbConnectionHandle != null && inDescriptor != null &&
          outDescriptor != null) {
        return new Future.value();
      }
      else {
        return new Future.error('invalid-device');
      }
    });
  }

  // This either resolves with a TransferResultInfo, or fails with an error
  // message.
  Future<TransferResultInfo> sendBuffer(ByteData buffer) {
    chrome.ArrayBuffer arrayBuffer = new chrome.ArrayBuffer.fromBytes(
        new Uint8List.view(buffer.buffer).toList());

    chrome.GenericTransferInfo transferInfo = new chrome.GenericTransferInfo()
        ..direction = outDescriptor.direction
        ..endpoint = outDescriptor.address
        ..length = arrayBuffer.getBytes().length
        ..data = arrayBuffer;

    return chrome.usb.bulkTransfer(adbConnectionHandle, transferInfo).then(
        (TransferResultInfo result) {
      if (result.resultCode != 0) {
        return new Future.error('Failed to send');
      } else {
        return result;
      }
    });
  }

  // Sends both the message and data portions.
  // The future either resolves with a TransferResultInfo, or fails with an
  // error message.
  Future<TransferResultInfo> sendMessage(AdbMessage message) {
    return sendBuffer(message.messageBuffer).then((TransferResultInfo result) {
      return message.dataLength > 0 ? sendBuffer(message.dataBuffer) : result;
    });
  }

  // Connects to and authenticates with the device.
  Future connect(SystemIdentity systemIdentity) {
    return chrome.usb.claimInterface(adbConnectionHandle,
        adbInterface.interfaceNumber).catchError((e) {
      throw 'Could not open an ADB connection: "${e}".\n Please check whether '
          'the Chrome ADT application is running on the Android device. \n'
          'Additionally, DevTools may not have released the USB connection. To '
          'check this go to chrome://inspect, Devices, uncheck \'Discover USB '
          'devices\', then disconnect and re-connect your phone from USB.';
    }).then((_) {
      AdbMessage adbMessage = new AdbMessage(AdbUtil.A_CNXN, AdbUtil.A_VERSION,
          AdbUtil.MAX_PAYLOAD, systemIdentity.toString());

      // Transfer connect message.
      return sendMessage(adbMessage).then((_) {
        return expectConnectionMessage();
      });
    });
  }

  /**
   * Releases any claimed USB interface.
   */
  Future dispose() {
    return chrome.usb.releaseInterface(adbConnectionHandle,
        adbInterface.interfaceNumber).catchError((e) {
      return null;
    });
  }

  Future<String> getKeys(ByteData seedToken) {
    if (isDart2js()) {
      return _prefs.getValue('adb_nacl_rsa_keys').then((String key) {
        if (key != null) {
          return key;
        }
        return AndroidRSA.randomSeed(new Uint8List.view(seedToken.buffer)).then((_) {
          return AndroidRSA.generateKey().then((String key) {
            return _prefs.setValue('adb_nacl_rsa_keys', key).then((_) {
              return key;
            });
          });
        });
      });
    }
    else {
      return _prefs.getValue('adb_rsa_keys').then((String key) {
        if (key != null) {
          return key;
        }
        AsymmetricKeyPair keys = AndroidRSACipher.generateKey(seedToken);
        key = AndroidRSACipher.serializeRSAKeys(keys);
        return _prefs.setValue('adb_rsa_keys', key).then((_) {
          return key;
        });
      });
    }
  }

  // Waits to receive either an ATUH or CNXN message. Handles AUTH as needed.
  // Resolves when the handshake is done.
  Future expectConnectionMessage() {
    bool sentSignature = false;
    bool sentPubKey = false;
    String key;
    Future handleConnectionMessage() {
      return receive().then((AdbMessage msg) {
        if (msg.command == AdbUtil.A_AUTH) {
          // We have been given a token.
          // If we haven't tried the keys yet, try them.
          if (!sentSignature) {
            // Fetch the keys, supplying the random token from the device as the
            // seed for the random number generator.
            //
            // TODO(dvh): It sounds like a bad idea to use the data sent by
            // the device as seed for the random number generator.
            return getKeys(msg.dataBuffer).then((String key_) {
              key = key_;
              if (isDart2js()) {
                return AndroidRSA.sign(key, new Uint8List.view(msg.dataBuffer.buffer))
                    .then((Uint8List signature) {
                  AdbMessage response = new AdbMessage(AdbUtil.A_AUTH,
                      AdbUtil.ADB_AUTH_SIGNATURE, 0);
                  response.setData(new ByteData.view(signature.buffer));
                  sentSignature = true;
                  return sendMessage(response).then((_) {
                      return handleConnectionMessage();
                  });
                });
              } else {
                AsymmetricKeyPair keys = AndroidRSACipher.deserializeRSAKeys(key);
                ByteData signature = AndroidRSACipher.sign(keys, msg.dataBuffer);
                AdbMessage response = new AdbMessage(AdbUtil.A_AUTH,
                    AdbUtil.ADB_AUTH_SIGNATURE, 0);
                response.setData(signature);
                sentSignature = true;
                return sendMessage(response).then((_) {
                  return handleConnectionMessage();
                });
              }
            });
          } else if (!sentPubKey) {
            if (isDart2js()) {
              return AndroidRSA.getPublicKey(key).then((String publicKey) {
                AdbMessage response = new AdbMessage(AdbUtil.A_AUTH,
                    AdbUtil.ADB_AUTH_RSAPUBLICKEY, 0,
                    "${publicKey} spark@chrome\x00");
                sentPubKey = true;
                return sendMessage(response).then((_) {
                  return handleConnectionMessage();
                });
              });
            } else {
              AsymmetricKeyPair keys = AndroidRSACipher.deserializeRSAKeys(key);
              String b64data = AndroidRSACipher.getPublicKey(keys);
              AdbMessage response = new AdbMessage(AdbUtil.A_AUTH,
                  AdbUtil.ADB_AUTH_RSAPUBLICKEY, 0,
                  "${b64data} spark@chrome\x00");
              sentPubKey = true;
              return sendMessage(response).then((_) {
                return handleConnectionMessage();
              });
            }
          } else {
            // We've tried signing, and tried sending our pubkey, and are
            // still not authenticated? Something went wrong.
            return new Future.error(
                'Got AUTH TOKEN command even after RSAPUBKEY response.');
          }
        } else if (msg.command == AdbUtil.A_CNXN) {
          // If we receive a CNXN in response, then we're authenticated!
          // There's nothing to handle in this message, so we just return.
          return null;
        } else {
          // Unexpected message type. Do nothing, and keep calling myself.
          return handleConnectionMessage();
        }
      });
    } // End of handleConnectionMessage.

    // handleConnectionMessage will repeatedly call itself, eventually
    // returning when it is successfully authenticated.
    return handleConnectionMessage();
  }

  // Either resolves with an AdbMessage (including data portion, if applicable),
  // or rejects with a TransferResultInfo giving the bad resultCode.
  Future<AdbMessage> receive() {
    AdbMessage readAdbMessage;
    chrome.GenericTransferInfo readTransferInfo =
        new chrome.GenericTransferInfo()
            ..direction = inDescriptor.direction
            ..endpoint = inDescriptor.address
            ..length = AdbUtil.MESSAGE_SIZE_PAYLOAD;

    return chrome.usb.bulkTransfer(adbConnectionHandle, readTransferInfo).then(
        (TransferResultInfo readResult) {
      // Read back a MessageBuffer for AUTH response.
      if (readResult.resultCode != 0) {
        return new Future.error(readResult);
      }

      readAdbMessage = new AdbMessage.fromMessageBufferBytes(
          readResult.data.getBytes());

      if (readAdbMessage.dataLength > 0) {
        chrome.GenericTransferInfo readDataInfo =
            new chrome.GenericTransferInfo()
                ..direction = inDescriptor.direction
                ..endpoint = inDescriptor.address
                ..length = readAdbMessage.dataLength;

        return chrome.usb.bulkTransfer(adbConnectionHandle, readDataInfo).then(
            (TransferResultInfo readDataResult) {
          if (readDataResult.resultCode != 0) {
            return new Future.error(readDataResult);
          }
          // TODO(shepheb): This is slow, copying through List<int>.
          // It would be much better to have a way to convert more directly.
          readAdbMessage.loadDataBuffer(readDataResult.data.getBytes());
          return readAdbMessage;
        });
      } else {
        return readAdbMessage;
      }
    });
  }

  // Returns the ID of the remote end.
  // This is only relevant for the OKAY after an OPEN, but harmless to return
  // always.
  Future<int> awaitOkay() {
    return receive().then((msg) {
      if (msg.command == AdbUtil.A_OKAY) {
        return msg.arg0;
      } else {
        return new Future.error('Expected an OKAY but got: ${msg.toString()}.\n' +
            'Please check that you are running Chrome ADT on your mobile device.');
      }
    });
  }

  // Expects the complete HTTP request as a List<int>, and the port as an int.
  // Sends a single HTTP request, reads a single response. Returns the complete
  // response, headers and all. In case of an error, rejects the Future with an
  // error message.
  // Technically this will work for sending any TCP request/response pair.
  Future<List<int>> sendHttpRequest(List<int> httpRequest, int port) {
    int localID = 4; // Arbitrary choice.
    int remoteID;
    Queue<ByteData> responseChunks;

    // Send the open message.
    AdbMessage message = new AdbMessage(AdbUtil.A_OPEN, localID, 0, 'tcp:$port\x00');
    return sendMessage(message).catchError((e) {
      // If we caught an error here, we probably got a CLSE instead.
      // This means the remote end isn't listening to our port.
      _logger.severe('Error sending adb message', e);
      return new Future.error('Connection on port $port refused.\n' +
          'Please check whether Chrome ADT is running on your mobile device.');
    }).then((_) { return awaitOkay(); }).then((remoteID_) {
      remoteID = remoteID_;

      // Prepare and send the parts of the message.
      int chunkCount = (httpRequest.length / AdbUtil.MAX_PAYLOAD).ceil();
      Iterable<ByteData> chunks = new Iterable.generate(chunkCount, (i) {
        int start = i * AdbUtil.MAX_PAYLOAD;
        int end = (i+1) * AdbUtil.MAX_PAYLOAD;
        end = end > httpRequest.length ? httpRequest.length : end;

        ByteData chunk = new ByteData(end-start);
        for (int j = start; j < end; j++) {
          chunk.setUint8(j-start, httpRequest[j]);
        }
        return chunk;
      });

      return Future.forEach(chunks, (packet) {
        // Prepare the message.
        AdbMessage msg = new AdbMessage(AdbUtil.A_WRTE, localID, remoteID);
        msg.setData(packet);
        return sendMessage(msg).then((_) {
          return awaitOkay();
        }).timeout(new Duration(seconds: 10), onTimeout: () {
          return new Future.error(
              'Push timed out: Single message took more than 10 seconds.');
        });
      });
    }).then((_) {
      // We've finished sending the request, now we await the response.
      // Since we don't know when the response is all done, we simply await
      // a 500ms pause after the last message.
      // TODO(shepheb): Maybe make this HTTP-specific and understand the
      // response and its Content-length?
      responseChunks = new Queue<ByteData>();

      Future readChunk() {
        return receive().timeout(new Duration(milliseconds: 800)).then((msg) {
          if (msg.command == AdbUtil.A_WRTE) {
            responseChunks.add(msg.dataBuffer);
            return sendMessage(new AdbMessage(AdbUtil.A_OKAY, localID,
                remoteID)).then((_) { return readChunk(); });
          } else {
            return new Future.error('Unexpected message from device.');
          }
        }).catchError((e) {
          if (e is TimeoutException) {
            return null;
          } else {
            return new Future.error(e);
          }
        });
      };

      return readChunk();
    }).then((_) {
      // Send a CLSE and expect a CLSE back.
      return sendMessage(new AdbMessage(AdbUtil.A_CLSE, 0, remoteID));
    }).then((_) {
      // Turn responseChunks into a List<int> and return it.
      List<int> ret = [];
      for (ByteData chunk in responseChunks) {
        for (int i = 0; i < chunk.lengthInBytes; i++) {
          ret.add(chunk.getUint8(i));
        }
      }
      return ret;
    });
  }

  void handleMessage() {
    // TODO(shepheb): Handle the incoming messages.
  }
}
