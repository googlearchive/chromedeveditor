# Chrome Dev Editor Release Notes

## M15 (0.15.x, September 2, 2014)
### New features:
- more dark themes (and the ability for the user to change the editor theme)
- new project template: "JavaScript Chrome App (using Polymer paper elements)"
- new context menu item on project/folder/file(s) to fix certain CSP violations (enables the above)
- as-you-type validation of manifest.json files (for Chrome apps)
- Git merge for conflict-free cases 
- non-fast-forward Git push
- non-fast-forward Git pull

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
