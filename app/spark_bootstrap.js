
if (navigator.webkitStartDart) {
  navigator.webkitStartDart();
} else {
  var script = document.createElement('script');
  script.src = 'spark.dart.js';
  document.body.appendChild(script);
}
