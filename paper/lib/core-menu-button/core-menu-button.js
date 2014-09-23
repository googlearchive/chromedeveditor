
    Polymer('core-menu-button', {

      publish: {

        /**
         * The icon to display.
         * @attribute icon
         * @type string
         */
        icon: 'dots',

        src: '',

        /**
         * The index of the selected menu item.
         * @attribute selected
         * @type number
         */
        selected: '',

        /**
         * Set to true to open the menu.
         * @attribute opened
         * @type boolean
         */
        opened: false,

        /**
         * Set to true to cause the menu popup to be displayed inline rather 
         * than in its own layer.
         * @attribute inlineMenu
         * @type boolean
         */
        inlineMenu: false,

        /**
         * Horizontally align the overlay with the button.
         * @attribute halign
         * @type string
         */
        halign: 'left',

        /**
         * Display the overlay on top or below the button.
         * @attribute valign
         * @type string
         */
        valign: 'top'

      },

      closeAction: function() {
        this.opened = false;
      },

      /**
       * Toggle the opened state of the dropdown.
       * @method toggle
       */
      toggle: function() {
        this.opened = !this.opened;
      },

      /**
       * The selected menu item.
       * @property selection
       * @type Node
       */
      get selection() {
        return this.$.menu.selection;
      }
      
    });
  