## FAQ

### How do I get started?
Check out our [Getting Started](GettingStarted.md) guide.

What platforms does Chrome Dev Editor run on?
Since CDE is a Chrome App, it runs on Windows, Mac, Linux and ChromeOS. Yes, you can now build apps on a Chromebook!

### What features does Chrome Dev Editor support?
* Chrome Apps
    * Run Chrome App 
    * Starter template for JavaScript Chrome App
    * Deploy to Mobile (Android)
    * Publish to Chrome Web Store
* Web Apps
    * Run Web App using an inbuilt web server
    * Starter template for JavaScript as well as Dart Web App
    * Support for adding Polymer UI elements
* Language support
    * Dart
        * Errors and Warnings - syntactic and semantic
        * Package management using Pub
        * Jump to Declaration
        * Outline view for viewing class variables and functions
    * Javascript
        * Syntax highlighting and auto-completion based on String matching
* Git workflows
    * Git Clone
    * Git Commit
    * Git Push
    * Git Branch
    * Git Checkout
    * Git Revert
* Editor features
    * Search file or folder names
    * Search within a file
    * Files and folders view
    * Tabs
* Polymer support
    * Creating a custom Polymer element
    * Using an existing Polymer element
    * Installing Polymer and dependencies using Bower 
* Templates supported
    * Web Apps
        * Dart Web App
        * JavaScript Web App
        * JavaScript Web App using Polymer
* Chrome Apps
    * JavaScript Chrome App
* Polymer Elements
    * JavaScript Polymer Custom Element
    * Dart Polymer Custom Element

### What’s the Chrome Dev Editor built on?
CDE is built from ground up on the Chrome platform. CDE’s a Chrome App written in Dart. It uses Polymer for many of its UI elements. CDE uses [Ace](http://ace.c9.io/#nav=about) as its code editor, which is a full fledged code-editor with syntax-highlighting for over 100 languages.

As a Chrome App, CDE gets access to several native capabilities such as raw filesystem access for writing folders on disk and USB access to communicate with mobile devices. You install CDE once and it gets synced across all your computers where you’re signed in to Chrome.

You can check out our [source code](https://github.com/dart-lang/spark) to learn more about how we used Chrome Apps, Dart and Polymer to build CDE.

### What are some upcoming features?
* Template for JavaScript Polymer Chrome Apps
    * https://github.com/dart-lang/spark/issues/2630
* Template for Chrome Extensions
    * https://github.com/dart-lang/spark/issues/1935
* Mobile deployment for Web Apps
    * https://github.com/dart-lang/spark/issues/2631
* More complete Git support (Git Pull, Merge, Diff)
    * Pull
    * Merge
    * Diff
    * Private repos
* Tell us what you want!
    * File an issue here: https://github.com/dart-lang/spark/issues/new 

### Why do I get `InvalidModificationError` when running pub get?
Being built on the Chrome platform, there are some filesystem restrictions which are not in place for the standard Dart Editor. One of those restrictions is the use of symlinks. Historically, symlinks were created by pub to manage the packages folders.

If you have run `pub get` from the command line, or are trying to open a project previously started in the Dart Editor, the filesystem may contain symlinks for the packages directories and will cause an error when loaded into the Chrome Dev Editor. To resolve this, remove any **package** folders or symlinks from all folders in your project. If you continue to receive the error, please open [a new issue](https://github.com/dart-lang/chromedeveditor/issues/new).
