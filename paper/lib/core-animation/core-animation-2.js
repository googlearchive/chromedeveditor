
    Polymer({
      publish: {
        /**
         * An offset from 0 to 1.
         *
         * @property offset
         * @type Number
         */
        offset: {value: null, reflect: true}
      },
      get properties() {
        var props = {};
        var children = this.querySelectorAll('core-animation-prop');
        Array.prototype.forEach.call(children, function(c) {
          props[c.name] = c.value;
        });
        if (this.offset !== null) {
          props.offset = this.offset;
        }
        return props;
      }
    });
  