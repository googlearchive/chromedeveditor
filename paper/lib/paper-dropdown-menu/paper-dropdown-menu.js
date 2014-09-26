

  Polymer({

    publish: {

      /**
       * True if the menu is open.
       *
       * @attribute opened
       * @type boolean
       * @default false
       */
      opened: false,

      /**
       * A label for the control. The label is displayed if no item is selected.
       *
       * @attribute label
       * @type string
       * @default 'Select an item'
       */
      label: 'Select an item',

      /**
       * The currently selected element. By default this is the index of the item element.
       * If you want a specific attribute value of the element to be used instead of the
       * index, set `valueattr` to that attribute name.
       *
       * @attribute selected
       * @type Object
       * @default null
       */
      selected: null,

      /**
       * Specifies the attribute to be used for "selected" attribute.
       *
       * @attribute valueattr
       * @type string
       * @default 'name'
       */
      valueattr: 'name',

      /**
       * Specifies the CSS class to be used to add to the selected element.
       * 
       * @attribute selectedClass
       * @type string
       * @default 'core-selected'
       */
      selectedClass: 'core-selected',

      /**
       * Specifies the property to be used to set on the selected element
       * to indicate its active state.
       *
       * @attribute selectedProperty
       * @type string
       * @default ''
       */
      selectedProperty: '',

      /**
       * Specifies the attribute to set on the selected element to indicate
       * its active state.
       *
       * @attribute selectedAttribute
       * @type string
       * @default 'active'
       */
      selectedAttribute: 'selected',

      /**
       * The currently selected element.
       *
       * @attribute selectedItem
       * @type Object
       * @default null
       */
      selectedItem: null,

      /**
       * Horizontally align the overlay with the control.
       * @attribute halign
       * @type "left"|"right"
       * @default "left"
       */
      halign: 'left',

      /**
       * Vertically align the dropdown menu with the control.
       * @attribute valign
       * @type "top"|"bottom"
       * @default "bottom"
       */
      valign: 'top'

    },

    toggle: function() {
      this.opened = !this.opened;
    },

    activateAction: function() {
      this.opened = false;
    }

  });

