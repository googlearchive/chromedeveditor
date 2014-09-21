
  
    Polymer('paper-icon-button', {

      publish: {

        /**
         * If true, the ripple expands to a square to fill the containing box.
         *
         * @attribute fill
         * @type boolean
         * @default false
         */
        fill: {value: false, reflect: true}

      },

      ready: function() {
        this.$.ripple.classList.add('recenteringTouch');
        this.fillChanged();
      },

      fillChanged: function() {
        this.$.ripple.classList.toggle('circle', !this.fill);
      },

      iconChanged: function(oldIcon) {
        if (!this.label) {
          this.setAttribute('aria-label', this.icon);
        }
      }

    });
    
  