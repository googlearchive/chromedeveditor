// Copyright (c) 2014, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library spark.harness_push;

import 'dart:async';

import 'package:archive/archive.dart' as archive;
import 'package:chrome/chrome_app.dart' as chrome;

import '../spark_model.dart';
import 'jobs.dart';
import 'workspace.dart';

class HarnessPush {
  /**
   * Packages (a subdirectory of) the current project, and sends it via HTTP to
   * a remote host.
   *
   * It expects the target host, and a [ProgressMonitor] for 10 units of work.
   * All files under the project will be added to a (slightly broken, see
   * below) CRX file, and sent via HTTP POST to the target host, using the /push
   * protocol described [here](https://github.com/MobileChromeApps/harness-push).
   *
   *     HarnessPush.push('192.168.1.121', monitor);
   *
   * Returns a Future for the push operation.
   *
   * Important Note: The CRX file that gets created and pushed is not correctly
   * signed and does not include the application's key. Since the target of a
   * push is intended to be a tool like the
   * [Chrome ADT](https://github.com/MobileChromeApps/harness) on Android,
   * and that tool doesn't care about the CRX metadata, this is not a problem.
   */
  static Future push(Container appContainer, String target,
                     ProgressMonitor monitor) {
    if (appContainer == null) {
      return new Future.error(new ArgumentError('Could not find app to push'));
    }

    archive.Archive arch = new archive.Archive();
    return _recursiveArchive(arch, appContainer).then((_) {
      monitor.worked(3);
      List<int> httpRequest = [];
      // Build the HTTP request headers.
      String boundary = "--------------------------------a921a8f557cf";
      String header = "POST /push?name=${appContainer.name}&type=crx HTTP/1.1\r\n"
          + "User-Agent: Spark IDE\r\n"
          + "Host: ${target}:2424\r\n"
          + "Content-Type: multipart/form-data; boundary=$boundary\r\n";
      List<int> body = [];
      String bodyTop = "$boundary\r\n"
          + "Content-Disposition: form-data; name=\"file\"; "
          + "filename=\"SparkPush.crx\"\r\n"
          + "Content-Type: application/octet-stream\r\n\r\n";
      body.addAll(bodyTop.codeUnits);

      // Add the CRX headers before the zip content.
      // This is the string "Cr24" then three little-endian 32-bit numbers:
      // - The version (2).
      // - The public key length (0).
      // - The signature length (0).
      // Since the App Harness/Chrome ADT on the other end doesn't check
      // the signature or key, we don't bother sending them.
      body.addAll([67, 114, 50, 52, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]);

      // Now follows the actual zip data.
      body.addAll(new archive.ZipEncoder().encode(arch));
      monitor.worked(4);

      // Add the trailing boundary.
      body.addAll([13, 10]); // \r\n
      body.addAll(boundary.codeUnits);
      // Two trailing hyphens to indicate the final boundary.
      body.addAll([45, 45, 13, 10]); // --\r\n

      httpRequest.addAll(header.codeUnits);
      httpRequest.addAll("Content-length: ${body.length}\r\n\r\n".codeUnits);
      httpRequest.addAll(body);

      monitor.worked(1);
      chrome.ArrayBuffer payload = new chrome.ArrayBuffer.fromBytes(
          httpRequest);
      // Now create a chrome.socket and send it.
      int socketId;
      return chrome.socket.create(chrome.SocketType.TCP).then((createInfo) {
        if (chrome.runtime.lastError != null) {
          throw 'Error creating socket';
        }
        socketId = createInfo.socketId;
        return chrome.socket.connect(socketId, target, 2424);
      }).then((_) {
        if (chrome.runtime.lastError != null) {
          throw 'Connection error: ${chrome.runtime.lastError.toString()}';
        }
        return chrome.socket.write(socketId, payload);
      }).then((chrome.SocketWriteInfo writeInfo) {
        if (chrome.runtime.lastError != null) {
          throw 'Failed to write to socket.';
        }
        print('Successfully pushed! (${writeInfo.bytesWritten} bytes)');
        monitor.worked(2);
      }).catchError((e) {
        SparkModel.instance.showErrorMessage('Push failure', e);
      }).whenComplete(() {
        if (socketId != null) {
          chrome.socket.disconnect(socketId);
          chrome.socket.destroy(socketId);
        }
        SparkModel.instance.showSuccessMessage('Push successful');
      });
    });
  }

  static _recursiveArchive(archive.Archive arch, Container parent,
      [String prefix = '']) {
    List<Future> futures = [];

    for (Resource child in parent.getChildren()) {
      if (child is File) {
        futures.add(child.getBytes().then((buf) {
          List<int> data = buf.getBytes();
          arch.addFile(new archive.File('${prefix}${child.name}', data.length,
              data));
        }));
      } else if (child is Folder) {
        futures.add(_recursiveArchive(arch, child, '${prefix}${child.name}/'));
      }
    }

    return Future.wait(futures);
  }
}
