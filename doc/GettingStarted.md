## Getting started with Chrome Dev Editor

### Installation

* Install [Chrome Dev Editor](https://chrome.google.com/webstore/detail/spark/pnoffddplpippgcfjdhbmhkofpnaalpg) on Chrome
* Open Chrome Dev Editor from the Chrome App Launcher or [chrome://apps](chrome://apps)

### Git workflow

* Click on the Menu icon and select **Git Clone...**
* Provide the **Repository URL** (eg: https://github.com/srsaroop/todomvc)
* Click **CLONE**
* The project will cloned into the Files view on the left
* Right-click the project on the Files view and you can see more Git options
    * Create branch…
    * Switch branch…
    * Commit changes…
    * Push to origin…
* When you make change to files in the project, blue markers will appear on the Files view to indicate files that are modified.
* To commit and push changes:
    * Right-click the project and select **Commit changes…**
    * Enter your name, email and commit message and click **COMMIT**
    * Right-click the project and select **Push to origin...**

### Chrome App workflow (including Mobile)

* Create a new project from the JavaScript Chrome App template or clone from an existing Git repository (eg: https://github.com/srsaroop/todomvc)
* Click the Run icon to run the Chrome App
* Chrome App for Mobile workflow: Chrome Apps can now run on Android devices using a [toolchain](https://github.com/MobileChromeApps/mobile-chrome-apps) based on Apache Cordova. 
    * On your Android device: 
        * Enable off-store installs: **Settings > Security > Device Administration > Unknown sources > allow installation of apps from sources other than the Play Store** 
        * Enable developer options: **Settings > About phone > Build number > Tap 7 times** Enable USB debugging: **Settings > Developer options > DEBUGGING > USB debugging**
        * Install the latest Chrome App Developer tool for Mobile (App Dev Tool) on your Android device
            * On your Android device,  open https://bit.ly/cradt
            * On your Android device, click on the green button to download the latest version of **ChromeAppDeveloperTool-debug.apk**
            * Click OK on the popup dialog to download the APK
            * Once the download is complete, click on the notification for the download
            * Click Install and open the **App Dev Tool**
    * Connect your Android device to your computer with a USB cable
    * Click **Deploy to Mobile…** and deploy via USB
    * Click **OK** on the authorization dialog on your Android device
    * Your Chrome App should launch on the **App Dev Tool**
    * Double two-finger tap to go back to the main **App Dev Tool** menu
    * Use [chrome://inspect](chrome://inspect) to remote debug your Chrome App
        * Once you open the Devtools inspector (with **Discover USB Devices** checked), it will claim the phone's USB interface and will not release it. CDE will not be able to re-deploy the application. This is an issue we're looking into. As a work-around for now, uncheck **Discover USB Devices** in DevTools and close the [chrome://inspect](chrome://inspect) page. This will force Devtools to give up the USB interface and CDE will be able to deploy to the phone again.
* To publish your Chrome App to the Chrome Web Store, click on the Menu icon and select **Publish to Chrome Web Store...**

### Dart workflow

* Create a new project from the Dart Web App template or clone from an existing Git repository 
* **Pub workflow**. The CDE has built-in support for Pub, Dart’s package manager. We automatically run Pub when your project is first created or imported. After that, pub is only run when the user explicitly invokes `pub get` or `pub update`. This can be done via the context menu on the Dart project or the `pubspec.yaml` file.
* **Dart analysis**. Dart analysis runs automatically as you edit your code! Syntax and semantic errors are called out in the editing area and in the files view. In addition, the CDE can optional display an outline of your Dart file’s contents. This helps to quickly understand the contents of a file and navigate within it.
* **Running a Web App**. To run your web app, just hit the Run button on the toolbar or right click on a file in the files view and select ‘Run’. This will open a new tab in the system browser with the contents of your web app, served up from the CDE. You can keep this tab open and refresh it as you make changes in the CDE and see those reflected in your application.
* **Running on Dartium vs Chrome**. When serving a Dart app up to regular Chrome, the CDE’s built in web server will compile your Dart files to JavaScript on the fly. This is great for seeing your application run and allows you to use any browser to develop. For larger applications however, it can lead to delays as the CDE compiles new versions on your application. An alternative workflow is to run your application in Dartium, a special version of Chromium with the Dart VM included. No compilation will be required to view your app; your development cycle will be much shorter (and your app will run faster too!). You can download Dartium from http://www.dartlang.org/tools/download.html. In order to use it to develop, simply hit ‘Run’ and copy the URL for your application from Chrome to Dartium.

### Polymer workflow
* Creating a new custom JavaScript Polymer element
    * Create a new project from the JavaScript Polymer custom template
    * CDE automatically does the following:
        * Installs Polymer and its dependencies via Bower. You should be able to see the installed folders in bower_components.
        * Creates HTML and CSS for the custom HTML element named `<name>-polymer`
        * Creates `demo.html`, which uses the `<name>-polymer element`
        * Creates a top-level `index.html`, which wraps around `demo.html`
    * Click the Run icon to run the app.
* Using an existing core Polymer element
    * Create a new project from the JavaScript Web App using Polymer
    * CDE automatically does the following:
        * Installs Polymer and its dependencies using Bower. You should be able to see the installed folders in bower_components.
        * Installs core Polymer elements in `bower_components`.
        * `index.html` that uses a sample element: `core-header-panel`
    * Click the Run icon to run the app.
