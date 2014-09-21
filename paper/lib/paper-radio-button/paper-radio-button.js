

  Polymer('paper-radio-button', {
    
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
    
    publish: {
      /**
       * Gets or sets the state, `true` is checked and `false` is unchecked.
       *
       * @attribute checked
       * @type boolean
       * @default false
       */
      checked: {value: false, reflect: true},
      
      /**
       * The label for the radio button.
       *
       * @attribute label
       * @type string
       * @default ''
       */
      label: '',
      
      /**
       * Normally the user cannot uncheck the radio button by tapping once
       * checked.  Setting this property to `true` makes the radio button
       * toggleable from checked to unchecked.
       *
       * @attribute toggles
       * @type boolean
       * @default false
       */
      toggles: false,
      
      /**
       * If true, the user cannot interact with this element.
       *
       * @attribute disabled
       * @type boolean
       * @default false
       */
      disabled: {value: false, reflect: true}
    },
    
    eventDelegates: {
      tap: 'tap'
    },
    
    tap: function() {
      var old = this.checked;
      this.toggle();
      if (this.checked !== old) {
        this.fire('change');
      }
    },
    
    toggle: function() {
      this.checked = !this.toggles || !this.checked;
    },
    
    checkedChanged: function() {
      this.$.onRadio.classList.toggle('fill', this.checked);
      this.setAttribute('aria-checked', this.checked ? 'true': 'false');
      this.fire('core-change');
    },
    
    labelChanged: function() {
      this.setAttribute('aria-label', this.label);
    }
    
  });
  
