
if (navigator.webkitStartDart) {
  navigator.webkitStartDart();
} else {
  var script = document.createElement('script');
  // Point the script to the compiled CSP compatible output for Spark.
  script.src = 'spark.dart.precompiled.js';
  document.body.appendChild(script);
}
