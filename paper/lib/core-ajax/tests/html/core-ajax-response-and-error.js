
      Polymer({
        delay: 1,
        response: null,
        testResult: 'pending...',
        passed: false,
        requests: [],
        observe: {
          '$.ajax.activeRequest': 'requestChanged'
        },
        domReady: function() {
          setTimeout(function() {
            if (this.response != null) {
              console.error('HTTP request returned too quick!')
              chai.assert.fail(
                  '', '',  'Indeterminate, initial request returned too quick');
              this.testResult = 'indeterminate';
              return;
            }
            this.delay = 2;
          }.bind(this), 100);
          // This will fail the test if it neither passes nor fails in time.
          this.finalTimeout = setTimeout(function() {
            chai.assert.fail('', '', 'Test timed out.');
          }, 7000);
        },
        responseChanged: function() {
          if (this.response.url != this.$.ajax.url) {
            this.testResult = 'FAIL';
            chai.assert.fail(this.$.ajax.url, this.response.url,
                             'Race condition in response attribute');
            return;
          }
          this.passed = true;
        },
        passedChanged: function() {
          if (this.passed && this.testResult == 'pending...') {
            this.testResult = 'PASS';
            clearTimeout(this.finalTimeout);
            done();
          }
        },
        requestChanged: function(o, n) {
          this.requests.push({
            'statusText': 'pending',
            xhr: n,
            delay: this.delay
          });
        },
        handleResponse: function(resp) {
          var xhr = resp.detail.xhr;
          for (var i = 0; i < this.requests.length; i++) {
            if (this.requests[i].xhr === xhr) {
              this.requests[i].statusText = xhr.statusText;
            }
          }
        },
      });
    