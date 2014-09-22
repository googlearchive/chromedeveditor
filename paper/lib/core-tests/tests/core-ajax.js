

    document.addEventListener('polymer-ready', function() {

      var ajax = document.querySelector('core-ajax');

      ajax.addEventListener("core-response", function(event) {

        assert.isTrue(event.detail.response.feed.entry.length > 0);
        done();

      });

    });

  