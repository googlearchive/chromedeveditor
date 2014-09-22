
    document.addEventListener('polymer-ready', function() {
      var s = document.querySelector('#localstorage');
      var m = 'hello wold';
      window.localStorage.setItem(s.name, m);
      s.load();
      assert.equal(s.value, m);
      s.value = 'goodbye';
      assert.equal(window.localStorage.getItem(s.name), m);
      done();
    });
  