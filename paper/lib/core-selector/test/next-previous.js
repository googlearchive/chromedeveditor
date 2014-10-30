

    var s = document.querySelector('#selector');

    function assertAndSelect(method, expectedIndex, wrap) {
      return function(done) {
        assert.equal(s.selected, expectedIndex);
        s[method](wrap);
        asyncPlatformFlush(done);
      }
    }

    suite('next/previous', function() {

      test('selectNext(true) wraps', function(done) {
        assert.equal(s.selected, 0);

        async.series([
          assertAndSelect('selectNext', 0, true),
          assertAndSelect('selectNext', 1, true),
          assertAndSelect('selectNext', 2, true),
          function(done) {
            assert.equal(s.selected, 0);
            done();
          }
        ], done);
      });

      test('selectPrevious(true) wraps', function(done) {
        assert.equal(s.selected, 0);

        async.series([
          assertAndSelect('selectPrevious', 0, true),
          assertAndSelect('selectPrevious', 2, true),
          assertAndSelect('selectPrevious', 1, true),
          function(done) {
            assert.equal(s.selected, 0);
            done();
          }
        ], done);
      });

      test('selectNext() does not wrap', function(done) {
        assert.equal(s.selected, 0);

        async.series([
          assertAndSelect('selectNext', 0),
          assertAndSelect('selectNext', 1),
          assertAndSelect('selectNext', 2),
          assertAndSelect('selectNext', 2),
          assertAndSelect('selectNext', 2),
          function(done) {
            s.selected = 0;
            asyncPlatformFlush(done);
          }
        ], done);
      });

      test('selectPrevious() does not wrap', function(done) {
        assert.equal(s.selected, 0);
        s.selected = 2;

        async.series([
          asyncPlatformFlush,
          assertAndSelect('selectPrevious', 2),
          assertAndSelect('selectPrevious', 1),
          assertAndSelect('selectPrevious', 0),
          assertAndSelect('selectPrevious', 0),
          assertAndSelect('selectPrevious', 0),
        ], done);
      });

    });

  