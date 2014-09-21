
    Polymer('paper-item', {

      publish: {

        /**
         * The label for the item.
         *
         * @attribute label
         * @type string
         * @default ''
         */
        label: '',

        /**
         * (optional) The URL of an image for an icon to use in the button.
         * Should not use `icon` property if you are using this property.
         *
         * @attribute iconSrc
         * @type string
         * @default ''
         */
        iconSrc: '',

        /**
         * (optional) Specifies the icon name or index in the set of icons
         * available in the icon set. If using this property, load the icon
         * set separately where the icon is used. Should not use `src`
         * if you are using this property.
         *
         * @attribute icon
         * @type string
         * @default ''
         */
        icon: ''

      },

      eventDelegates: {
        'down': 'downAction',
        'up': 'upAction'
      },

      downAction: function(e) {
        this.$.ripple.downAction(e);
      },

      upAction: function(e) {
        this.$.ripple.upAction(e);
      }
    });
  