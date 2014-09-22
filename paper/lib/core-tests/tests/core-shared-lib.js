

    var count = 0;
    addEventListener("core-shared-lib-load", function(event) {
      if (++count ===  2) {
        done();
      } else {
        assert.isTrue(count < 2);
        // request the api again
        setTimeout(function() {
          document.querySelector('#t').model = {};
        }, 100);
      }
    });

  