
import 'package:chrome/build/build.dart';

/**
 * This build script watches for changes to any .dart files and copies the root
 * packages directory to the app/packages directory. This works around an issue
 * with Chrome apps and symlinks and allows you to use pub with Chrome apps.
 */
void main(List<String> args) {
  copyPackages(new Directory('app'));
}
