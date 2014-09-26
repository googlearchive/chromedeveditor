
    Polymer('paper-menu-button', {

      publish: {

        /**
         * If true, this menu is currently visible.
         *
         * @attribute opened
         * @type boolean
         * @default false
         */
        opened: false,

        /**
         * The horizontal alignment of the menu relative to the button.
         *
         * @attribute halign
         * @type 'left' | 'right'
         * @default 'left'
         */
        halign: 'left',

        /**
         * The vertical alignment of the menu relative to the button.
         *
         * @attribute valign
         * @type 'bottom' | 'top'
         * @default 'top'
         */
        valign: 'top',

        /**
         * Set to true to disable the transition.
         *
         * @attribute noTransition
         * @type boolean
         * @default false
         */
        noTransition: false

      },

      computed: {
        transition: '"paper-menu-button-transition-" + valign + "-" + halign'
      },

      /**
       * The URL of an image for the icon. Should not use `icon` property
       * if you are using this property.
       *
       * @attribute src
       * @type string
       * @default ''
       */
      src: '',

      /**
       * Specifies the icon name or index in the set of icons available in
       * the icon set.  Should not use `src` property if you are using this
       * property.
       *
       * @attribute icon
       * @type string
       * @default ''
       */
      icon: '',

      tapAction: function() {
        if (this.disabled) {
          return;
        }

        this.super();
        this.toggle();
        if (this.opened && !this.noTransition) {
          this.$.shadow.z = 0;
        }
      },

      transitionEndAction: function() {
        this.$.shadow.z = 1;
      },

      /**
       * Toggle the opened state of the menu.
       *
       * @method toggle
       */
      toggle: function() {
        this.opened = !this.opened;
      }

    });
  