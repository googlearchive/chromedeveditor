This directory contains an example of chrome application that uses native
messaging API that allows to communicate with a native application. The Dart SDK 
is needed to run the host. (http://www.dartlang.org)

In order for this example to work you must first install the native messaging
host from the host directory.

To install the host:

On Windows:
  Add registry key
  HKEY_LOCAL_MACHINE\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.google.chrome.example.dart
  or
  HKEY_CURRENT_USER\SOFTWARE\Google\Chrome\NativeMessagingHosts\com.google.chrome.example.dart
  and set its default value to the full path to
  host\com.google.chrome.example.dart-win.json . 

On Mac and Linux:
  Run install_host.sh script in the host directory:
    host/install_host.sh
  By default the host is installed only for the user who runs the script, but if
  you run it with admin privileges (i.e. 'sudo host/install_host.sh'), then the
  host will be installed for all users. You can later use host/uninstall_host.sh
  to uninstall the host.
