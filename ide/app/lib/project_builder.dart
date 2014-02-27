class ProjectBuilder {
  DirectoryEntry _destRoot;
  DirectoryEntry _sourceRoot;
  String _sourcePath;
  Future _onceSourceRootReady;
  String _sourceName;
  String _projectName;
  Map _setup;
  String sourceUri;

  ProjectBuilder(this._destRoot, String templateId, this._sourceName,
      this._projectName) {
    String templatesPath = 'resources/templates/$templateId';
    sourceUri = chrome.runtime.getURL(templatesPath);

    _onceSourceRootReady = chrome.runtime.getPackageDirectoryEntry()
        .then((DirectoryEntry root) => root.getDirectory(templatesPath))
        .then((DirectoryEntry root) => _sourceRoot = root);
  }

  Future build() {
    // TODO(ericarnold): Switch all /s to platform specific

    Future setupFuture = HttpRequest.getString("$sourceUri/setup.json")
        .then((String contents) => _setup = JSON.decode(contents));

    return Future.wait([setupFuture, _onceSourceRootReady])
        .then((_){
          return traverseElement(_destRoot, _sourceRoot, sourceUri, _setup);
        });
  }

  Future traverseElement(DirectoryEntry destRoot, DirectoryEntry sourceRoot,
                  String sourceUri, Map element) {
    return handleDirectories(destRoot, sourceRoot, sourceUri, element['directories'])
        .then((_) => handleFiles(destRoot, sourceRoot, sourceUri,
            element['files']))
        .catchError((e) =>
            print("""error: ${e}"""));
  }

  Future handleDirectories(DirectoryEntry destRoot, DirectoryEntry sourceRoot, String sourceUri,
                           Map directories) {
    if (directories != null) {
      return Future.forEach(directories.keys, (String directoryName) {
        DirectoryEntry destDirectoryRoot;
        return _destRoot.createDirectory(directoryName)
            .then((DirectoryEntry entry) {
              destDirectoryRoot = entry;
              return sourceRoot.getDirectory(directoryName);
            }).then((DirectoryEntry sourceDirectoryRoot) {
              return traverseElement(destDirectoryRoot, sourceDirectoryRoot,
                  "$sourceUri/$directoryName", directories[directoryName]);
        });
      });
    }

    return new Future.value();
  }

  Future handleFiles(DirectoryEntry destRoot, DirectoryEntry sourceRoot, String sourceUri, List files) {
    if (files != null) {
      return Future.forEach(files, (fileElement) {
        String source = fileElement['source'];
        String dest = fileElement['dest'];
        dest = dest.replaceAll("\$sourceName", _sourceName)
            ..replaceAll("\$projectName", _projectName);

        String content;
        print("""copying $sourceUri/${source} to $dest""");

        return sourceRoot.getFile(source)
            .then((FileEntry file) {
              return file.copyTo(destRoot, name: dest);
            });

//        return HttpRequest.getString("$sourceUri/$source")
//            .then((String fileContent) {
//              content = fileContent;
//              return destRoot.createFile(dest);
//            }).then((FileEntry newFile) =>
//                chrome.fileSystem.getWritableEntry(newFile))
//            .then((FileEntry entry) =>
        // This throws UnimplementedError
//                entry.createWriter())
//            .then((FileWriter writer) {
//              var blob = new Blob([content], 'text/plain');
//              return writer.write(blob);
//            }).catchError((error){
//              print("""Error: $error""");
//            });
      });
    }
    return new Future.value(null);
  }
}
