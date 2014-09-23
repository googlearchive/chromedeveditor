

  Polymer('core-splitter', {

    /**
     * Possible values are `left`, `right`, `up` and `down`.
     *
     * @attribute direction
     * @type string
     * @default 'left'
     */
    direction: 'left',

    /**
     * Minimum width to which the splitter target can be sized, e.g. 
     * `minSize="100px"`
     *
     * @attribute minSize
     * @type string
     * @default ''
     */
    minSize: '',

    /**
     * Locks the split bar so it can't be dragged.
     *
     * @attribute locked
     * @type boolean
     * @default false
     */
    locked: false,

    /**
     * By default the parent and siblings of the splitter are set to overflow hidden. This helps
     * avoid elements bleeding outside the splitter regions. Set this property to true to allow
     * these elements to overflow.
     *
     * @attribute allowOverflow
     * @type boolean
     * @default false
     */
    allowOverflow: false,

    ready: function() {
      this.directionChanged();
    },

    domReady: function() {
      if (!this.allowOverflow) {
        this.parentNode.style.overflow = this.nextElementSibling.style.overflow =
            this.previousElementSibling.style.overflow = 'hidden';
      }
    },

    directionChanged: function() {
      this.isNext = this.direction === 'right' || this.direction === 'down';
      this.horizontal = this.direction === 'up' || this.direction === 'down';
      this.update();
    },

    update: function() {
      this.target = this.isNext ? this.nextElementSibling : this.previousElementSibling;
      this.dimension = this.horizontal ? 'height' : 'width';
      this.classList.toggle('horizontal', this.horizontal);
    },

    targetChanged: function(old) {
      if (old) {
        old.style[old.__splitterMinSize] = '';
      }
      var min = this.target.__splitterMinSize = this.horizontal ? 'minHeight' : 'minWidth';
      this.target.style[min] = this.minSize;
    },

    trackStart: function() {
      this.update();
      this.size = parseInt(getComputedStyle(this.target)[this.dimension]);
    },

    track: function(e) {
      if (this.locked) {
        return;
      }
      var d = e[this.horizontal ? 'dy' : 'dx'];
      this.target.style[this.dimension] =
          this.size + (this.isNext ? -d : d) + 'px';
    },

    preventSelection: function(e) {
      e.preventDefault();
    }
  });

