

  mocha.setup({ui: 'tdd', slow: 1000, timeout: 5000, htmlbase: ''});

  htmlSuite('core-ajax', function() {
    htmlTest('tests/core-ajax.html');
  });
  
  htmlSuite('core-collapse', function() {
    htmlTest('tests/core-collapse.html');
  });
  
  htmlSuite('core-localstorage', function() {
    htmlTest('tests/core-localstorage.html');
  });

  htmlSuite('core-selection', function() {
    htmlTest('tests/core-selection.html');
    htmlTest('tests/core-selection-multi.html');
  });

  htmlSuite('core-selector', function() {
    htmlTest('tests/core-selector-basic.html');
    htmlTest('tests/core-selector-activate-event.html');
    htmlTest('tests/core-selector-multi.html');
  });
  
  htmlSuite('core-shared-lib', function() {
    htmlTest('tests/core-shared-lib.html');
  });

  mocha.run();

