

//
// INK EQUATIONS
//

// Animation constants.
var globalSpeed = 1;
var waveOpacityDecayVelocity = 0.8 / globalSpeed;  // opacity per second.
var waveInitialOpacity = 0.25;
var waveLingerOnTouchUp = 0.2;
var waveMaxRadius = 150; 

// TODOs:
// - rather than max distance to corner, use hypotenuos(sp) (diag)
// - use quadratic for the fall off, move fast at the beginning, 
// - on cancel, immediately fade out, reverse the direction

function waveRadiusFn(touchDownMs, touchUpMs, ww, hh) {
  // Convert from ms to s.
  var touchDown = touchDownMs / 1000;
  var touchUp = touchUpMs / 1000;
  var totalElapsed = touchDown + touchUp;
  var waveRadius = Math.min(Math.max(ww, hh), waveMaxRadius) * 1.1 + 5;
  var dduration = 1.1 - .2 * (waveRadius / waveMaxRadius);
  var tt = (totalElapsed / dduration);
  
  var ssize = waveRadius * (1 - Math.pow(80, -tt));
  return Math.abs(ssize);
}

function waveOpacityFn(td, tu) {
  // Convert from ms to s.
  var touchDown = td / 1000;
  var touchUp = tu / 1000;
  var totalElapsed = touchDown + touchUp;

  if (tu <= 0) {  // before touch up
    return waveInitialOpacity;
  }
  return Math.max(0, waveInitialOpacity - touchUp * waveOpacityDecayVelocity);
}

function waveOuterOpacityFn(td, tu) {
  // Convert from ms to s.
  var touchDown = td / 1000;
  var touchUp = tu / 1000;

  // Linear increase in background opacity, capped at the opacity
  // of the wavefront (waveOpacity).
  var outerOpacity = touchDown * 0.3;
  var waveOpacity = waveOpacityFn(td, tu);
  return Math.max(0, Math.min(outerOpacity, waveOpacity));
  
}

function waveGravityToCenterPercentageFn(td, tu, r) {
  // Convert from ms to s.
  var touchDown = td / 1000;
  var touchUp = tu / 1000;
  var totalElapsed = touchDown + touchUp;

  return Math.min(1.0, touchUp * 6);
}


// Determines whether the wave should be completely removed.
function waveDidFinish(wave, radius) {
  var waveOpacity = waveOpacityFn(wave.tDown, wave.tUp);
  // Does not linger any more.
  // var lingerTimeMs = waveLingerOnTouchUp * 1000;

  // If the wave opacity is 0 and the radius exceeds the bounds
  // of the element, then this is finished.
  if (waveOpacity < 0.01 && radius >= wave.maxRadius) {
    return true;
  }
  return false;
};

//
// DRAWING
//

function animateIcon() {
  var el = document.getElementById('button_toolbar0');
  el.classList.add('animate');
  setTimeout(function(){
    el.classList.remove('animate');
    el.classList.toggle('selected');
  }, 500);
}


function drawRipple(canvas, x, y, radius, innerColor, outerColor, innerColorAlpha, outerColorAlpha) {
  var ctx = canvas.getContext('2d');
  if (outerColor) {
    ctx.fillStyle = outerColor;
    ctx.fillRect(0,0,canvas.width, canvas.height);
  }

  ctx.beginPath();
  ctx.arc(x, y, radius, 0, 2 * Math.PI, false);
  ctx.fillStyle = innerColor;
  ctx.fill();
}

function drawLabel(canvas, label, fontSize, color, alignment) {
  var ctx = canvas.getContext('2d');
  ctx.font= fontSize + 'px Helvetica';

  var metrics = ctx.measureText(label);
  var width = metrics.width;
  var height = metrics.height;
  ctx.fillStyle = color;

  var xPos = (canvas.width/2 - width)/2;

  if (alignment === 'left') { xPos = 16; }

  ctx.fillText(label, xPos, canvas.height/2 - (canvas.height/2 - fontSize +2) / 2);
}

//
// BUTTON SETUP
//

function createWave(elem) {
  var elementStyle = window.getComputedStyle(elem);
  var fgColor = elementStyle.color;

  var wave = {
    waveColor: fgColor,
    maxRadius: 0,
    isMouseDown: false,
    mouseDownStart: 0.0,
    mouseUpStart: 0.0,
    tDown: 0,
    tUp: 0
  };
  return wave;
}

function removeWaveFromScope(scope, wave) {
  if (scope.waves) {
    var pos = scope.waves.indexOf(wave);
    scope.waves.splice(pos, 1);
  }
};


function setUpPaperByClass( classname ) {
  var elems = document.querySelectorAll( classname );
  [].forEach.call( elems, function( el ) {
      setUpPaper(el);
  });
}

function setUpPaper(elem) {
  var pixelDensity = 2;

  var elementStyle = window.getComputedStyle(elem);
  var fgColor = elementStyle.color;
  var bgColor = elementStyle.backgroundColor;
  elem.width = elem.clientWidth;
  elem.setAttribute('width', elem.clientWidth * pixelDensity + "px");
  elem.setAttribute('height', elem.clientHeight * pixelDensity + "px");

  var isButton = elem.classList.contains( 'button' ) || elem.classList.contains( 'button_floating' ) | elem.classList.contains( 'button_menu' );
  var isToolbarButton =  elem.classList.contains( 'button_toolbar' );

  elem.getContext('2d').scale(pixelDensity, pixelDensity)

  var scope = {
    backgroundFill: true,
    element: elem,
    label: 'Button',
    waves: [],
  };


  scope.label = elem.getAttribute('value') || elementStyle.content;
  scope.labelFontSize = elementStyle.fontSize.split("px")[0];

  drawLabel(elem, scope.label, scope.labelFontSize, fgColor, elem.style.textAlign);


  //
  // RENDER FOR EACH FRAME
  //
  var onFrame = function() {
    var shouldRenderNextFrame = false;

    // Clear the canvas
    var ctx = elem.getContext('2d');
    ctx.clearRect(0, 0, elem.width, elem.height);

    var deleteTheseWaves = [];
    // The oldest wave's touch down duration
    var longestTouchDownDuration = 0;
    var longestTouchUpDuration = 0;
    // Save the last known wave color
    var lastWaveColor = null;

    for (var i = 0; i < scope.waves.length; i++) {
      var wave = scope.waves[i];

      if (wave.mouseDownStart > 0) {
        wave.tDown = now() - wave.mouseDownStart;
      }
      if (wave.mouseUpStart > 0) {
        wave.tUp = now() - wave.mouseUpStart;
      }

      // Determine how long the touch has been up or down.
      var tUp = wave.tUp;
      var tDown = wave.tDown;
      longestTouchDownDuration = Math.max(longestTouchDownDuration, tDown);
      longestTouchUpDuration = Math.max(longestTouchUpDuration, tUp);

      // Obtain the instantenous size and alpha of the ripple.
      var radius = waveRadiusFn(tDown, tUp, elem.width, elem.height);
      var waveAlpha =  waveOpacityFn(tDown, tUp);
      var waveColor = cssColorWithAlpha(wave.waveColor, waveAlpha);
      lastWaveColor = wave.waveColor;

      // Position of the ripple.
      var x = wave.startPosition.x;
      var y = wave.startPosition.y;

      // Ripple gravitational pull to the center of the canvas.
      if (wave.endPosition) {
 
        var translateFraction = waveGravityToCenterPercentageFn(tDown, tUp, wave.maxRadius);

        // This translates from the origin to the center of the view  based on the max dimension of  
        var translateFraction = Math.min(1, radius / wave.containerSize * 2 / Math.sqrt(2) );

        x += translateFraction * (wave.endPosition.x - wave.startPosition.x);
        y += translateFraction * (wave.endPosition.y - wave.startPosition.y);
      }

      // If we do a background fill fade too, work out the correct color.
      var bgFillColor = null;
      if (scope.backgroundFill) {
        var bgFillAlpha = waveOuterOpacityFn(tDown, tUp);
        bgFillColor = cssColorWithAlpha(wave.waveColor, bgFillAlpha);
      }

      // Draw the ripple.
      drawRipple(elem, x, y, radius, waveColor, bgFillColor);

      // Determine whether there is any more rendering to be done.
      var shouldRenderWaveAgain = !waveDidFinish(wave, radius);
      shouldRenderNextFrame = shouldRenderNextFrame || shouldRenderWaveAgain;
      if (!shouldRenderWaveAgain) {
        deleteTheseWaves.push(wave);
      }
   }

    if (shouldRenderNextFrame) {
      window.requestAnimationFrame(onFrame);
    }  else {
      // If there is nothing to draw, clear any drawn waves now because
      // we're not going to get another requestAnimationFrame any more.
      var ctx = elem.getContext('2d');
      ctx.clearRect(0, 0, elem.width, elem.height);
    }

    // Draw the label at the very last point so it is on top of everything.
    drawLabel(elem, scope.label, scope.labelFontSize, fgColor, elem.style.textAlign);

    for (var i = 0; i < deleteTheseWaves.length; ++i) {
      var wave = deleteTheseWaves[i];
      removeWaveFromScope(scope, wave);
    }
  };

  //
  // MOUSE DOWN HANDLER
  //

  elem.addEventListener('mousedown', function(e) {
    var wave = createWave(e.target);
    var elem = scope.element;

    wave.isMouseDown = true;
    wave.tDown = 0.0;
    wave.tUp = 0.0;
    wave.mouseUpStart = 0.0;
    wave.mouseDownStart = now();

    var width = e.target.width / 2; // Retina canvas
    var height = e.target.height / 2;
    var touchX = e.clientX - e.target.offsetLeft - e.target.offsetParent.offsetLeft;
    var touchY = e.clientY - e.target.offsetTop - e.target.offsetParent.offsetTop;
    wave.startPosition = {x:touchX, y:touchY};

    if (elem.classList.contains("recenteringTouch")) {
      wave.endPosition = {x: width / 2,  y: height / 2};
      wave.slideDistance = dist(wave.startPosition, wave.endPosition);
    }
    wave.containerSize = Math.max(width, height);
    wave.maxRadius = distanceFromPointToFurthestCorner(wave.startPosition, {w: width, h: height});
    elem.classList.add("activated");
    scope.waves.push(wave);
    window.requestAnimationFrame(onFrame);
    return false;
  });

  //
  // MOUSE UP HANDLER
  //

  elem.addEventListener('mouseup', function(e) {
    elem.classList.remove("activated");

    for (var i = 0; i < scope.waves.length; i++) {
      // Declare the next wave that has mouse down to be mouse'ed up.
      var wave = scope.waves[i];
      if (wave.isMouseDown) {
        wave.isMouseDown = false
        wave.mouseUpStart = now();
        wave.mouseDownStart = 0;
        wave.tUp = 0.0;
        break;
      }
    }
    return false;
  });

  elem.addEventListener('mouseout', function(e) {
  elem.classList.remove("activated");

  for (var i = 0; i < scope.waves.length; i++) {
    // Declare the next wave that has mouse down to be mouse'ed up.
    var wave = scope.waves[i];
    if (wave.isMouseDown) {
      wave.isMouseDown = false
      wave.mouseUpStart = now();
      wave.mouseDownStart = 0;
      wave.tUp = 0.0;
      wave.cancelled = true;
      break;
    }
  }
  return false;
  });

  return scope;
};

// Shortcuts.
var pow = Math.pow;
var now = function() { return new Date().getTime(); };

// Quad beizer where t is between 0 and 1.
function quadBezier(t, p0, p1, p2, p3) {
  return pow(1 - t, 3) * p0 +
         3 * pow(1 - t, 2) * t * p1 +
         (1 - t) * pow(t, 2) * p2 +
         pow(t, 3) * p3;
}

function easeIn(t) {
  return quadBezier(t, 0.4, 0.0, 1, 1);
}

function cssColorWithAlpha(cssColor, alpha) {
    var parts = cssColor.match(/^rgb\((\d+),\s*(\d+),\s*(\d+)\)$/);
    if (typeof alpha == 'undefined') {
        alpha = 1;
    }
    if (!parts) {
      return 'rgba(255, 255, 255, ' + alpha + ')';
    }
    return 'rgba(' + parts[1] + ', ' + parts[2] + ', ' + parts[3] + ', ' + alpha + ')';
}

function dist(p1, p2) {
  return Math.sqrt(Math.pow(p1.x - p2.x, 2) + Math.pow(p1.y - p2.y, 2));
}

function distanceFromPointToFurthestCorner(point, size) {
  var tl_d = dist(point, {x: 0, y: 0});
  var tr_d = dist(point, {x: size.w, y: 0});
  var bl_d = dist(point, {x: 0, y: size.h});
  var br_d = dist(point, {x: size.w, y: size.h});
  return Math.max(Math.max(tl_d, tr_d), Math.max(bl_d, br_d));
}


function toggleDialog() {
  var el = document.getElementById('dialog');
  el.classList.toggle("visible");
}

function toggleMenu() {
  var el = document.getElementById('menu');
  el.classList.toggle("visible");
}


// Initialize

function init() {
    setUpPaperByClass( '.paper' );
}

window.addEventListener('DOMContentLoaded', init, false);
