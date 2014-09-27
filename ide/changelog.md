# Chrome Dev Editor Release Notes

## M16 (0.16.x, October 1, 2014)
### New features
- added the 'Live Deploy' mode when pushing to mobile: see your changes reflected on the device in real time!
- added real-time validation for Chrome apps' manifests
- enabled running Bower commands on project's subdirectories that contain bower.json
- enabled 'Refactor for CSP' context menu for any folder(s) with HTMLs -- not only package directories

### Other changes
- adjusted the goto line component to be more in-line with material design
- faster handling of large files (> 500 K); in particular, saving is faster
- enabled syntax highlighting for *.html.pre_csp files (backups of original *.html's created by 'Refactor for CSP')
- made possible editing of files in packages via package-files-are-editable developer flag
- UI tweaks:

    - upgraded to Roboto 2 font
    - moved the 'Toggle Outline' button to the toolbar
    - changed status/progress indicator
    - display a warning dialog when the user attempts to drag-and-drop a file into a folder where a file with the same name already exists
    - hide "Properties..." context menu item when multiple resources are selected
    - added some missing tooltips to UI elements

### Bug fixes
- fixed: warning markers obscured error markers in the same line in the editor

## M15 (0.15.x, September 2, 2014)
### New features:
- more dark themes (and the ability for the user to change the editor theme)
- new project template: "JavaScript Chrome App (using Polymer paper elements)"
- new context menu item on project/folder/file(s) to fix certain CSP violations (enables the above)
- as-you-type validation of manifest.json files (for Chrome apps)

### Other changes:
- fixed an issue with cloning an empty Git repository
- fixed several issues with 'Pub Get' and 'Pub Update'
- USB deployment speed improvements
- fixed a Bower issue where just the top-level files of a package would be downloaded (subdirectories were skipped)

## M14 (0.14.2, August 5, 2014)
### New features:
- the Polymer template now uses [Paper elements](http://www.polymer-project.org/docs/elements/material.html)
- added a new Dart Chrome App project type
- added a search in files feature
- improved the performance of the files view
- improved the performance of our Bower support

### And other changes:
- the main folder for projects can now be changed
- the outline view is now resizable
- the status message become translucent when the mouse hovers over it
- bug fixes to the Dart support, for both Dart analysis and compiling to JavaScript
- improved some error messages for pub and webstore publish
- fixed some history navigation issues
