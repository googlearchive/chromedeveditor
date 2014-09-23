

  Polymer({

    /**
     * A simple string label for the tooltip to display. To display a rich
     * HTML tooltip instead, omit `label` and include the `tip` attribute
     * on a child node of `core-tooltip`.
     *
     * @attribute label
     * @type string
     * @default null
     */
    label: null,

    computed: {
      // Indicates whether the tooltip has a set label propety or
      // an element with the `tip` attribute.
      hasTooltipContent: 'label || !!tipElement'
    },

    publish: {
      /**
       * If true, the tooltip displays by default.
       *
       * @attribute show
       * @type boolean
       * @default false
       */
      show: {value: false, reflect: true},

      /**
       * Positions the tooltip to the top, right, bottom, left of its content.
       *
       * @attribute position
       * @type string
       * @default 'bottom'
       */
      position: {value: 'bottom', reflect: true},

      /**
       * If true, the tooltip an arrow pointing towards the content.
       *
       * @attribute noarrow
       * @type boolean
       * @default false
       */
      noarrow: {value: false, reflect: true}
    },

    /**
     * Customizes the attribute used to specify which content
     * is the rich HTML tooltip.
     *
     * @attribute tipAttribute
     * @type string
     * @default 'tip'
     */
    tipAttribute: 'tip',

    attached: function() {
      this.updatedChildren();
    },

    updatedChildren: function () {
      this.tipElement = null;

      for (var i = 0, el; el = this.$.c.getDistributedNodes()[i]; ++i) {
        if (el.hasAttribute && el.hasAttribute('tip')) {
          this.tipElement = el;
          break;
        }
      }

      // Job ensures we're not double calling setPosition() on DOM attach.
      this.job('positionJob', this.setPosition);

      // Monitor children to re-position tooltip when light dom changes.
      this.onMutation(this, this.updatedChildren);
    },

    labelChanged: function(oldVal, newVal) {
      this.job('positionJob', this.setPosition);
    },

    positionChanged: function(oldVal, newVal) {
      this.job('positionJob', this.setPosition);
    },

    setPosition: function() {
      var controlWidth = this.clientWidth;
      var controlHeight = this.clientHeight;
      var toolTipWidth = this.$.tooltip.clientWidth;
      var toolTipHeight = this.$.tooltip.clientHeight;

      switch (this.position) {
        case 'top':
        case 'bottom':
          this.$.tooltip.style.left = (controlWidth - toolTipWidth) / 2 + 'px';
          this.$.tooltip.style.top = null;
          break;
        case 'left':
        case 'right':
          this.$.tooltip.style.left = null;
          this.$.tooltip.style.top = (controlHeight - toolTipHeight) / 2 + 'px';
          break;
      }
    }
  });

