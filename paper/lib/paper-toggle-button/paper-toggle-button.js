

  Polymer('paper-toggle-button', {
    
    /**
     * Fired when the checked state changes due to user interaction.
     *
     * @event change
     */
     
    /**
     * Fired when the checked state changes.
     *
     * @event core-change
     */

    /**
     * Gets or sets the state, `true` is checked and `false` is unchecked.
     *
     * @attribute checked
     * @type boolean
     * @default false
     */
    checked: false,

    trackStart: function(e) {
      this._w = this.$.toggleBar.offsetLeft + this.$.toggleBar.offsetWidth;
      e.preventTap();
    },

    trackx: function(e) {
      this._x = Math.min(this._w, 
          Math.max(0, this.checked ? this._w + e.dx : e.dx));
      this.$.toggleRadio.classList.add('dragging');
      var s =  this.$.toggleRadio.style;
      s.webkitTransform = s.transform = 'translate3d(' + this._x + 'px,0,0)';
    },

    trackEnd: function() {
      var s =  this.$.toggleRadio.style;
      s.transform = s.webkitTransform = '';
      this.$.toggleRadio.classList.remove('dragging');
      var old = this.checked;
      this.checked = Math.abs(this._x) > this._w / 2;
      if (this.checked !== old) {
        this.fire('change');
      }
    },
    
    checkedChanged: function() {
      this.setAttribute('aria-pressed', Boolean(this.checked));
      this.fire('core-change');
    },
    
    changeAction: function(e) {
      e.stopPropagation();
      this.fire('change');
    },
    
    stopPropagation: function(e) {
      e.stopPropagation();
    }

  });

