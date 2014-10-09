mocha.setup({ui: 'tdd', htmlbase: ''});

htmlSuite('paper-ripple', function() {
  htmlTest('html/paper-ripple-position.html');
});