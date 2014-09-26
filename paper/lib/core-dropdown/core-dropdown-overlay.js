
    Polymer({

      publish: {

        /**
         * The `relatedTarget` is an element used to position the overlay. It should have
         * the same offsetParent as the target.
         *
         * @attribute relatedTarget
         * @type Node
         */
        relatedTarget: null,

        /**
         * The horizontal alignment of the overlay relative to the `relatedTarget`.
         * `left` means the left edges are aligned together and `right` means the right
         * edges are aligned together.
         *
         * @attribute halign
         * @type 'left' | 'right'
         * @default 'auto'
         */
        halign: 'left',

        /**
         * The vertical alignment of the overlay relative to the `relatedTarget`. `top`
         * means the top edges are aligned together and `bottom` means the bottom edges
         * are aligned together.
         *
         * @attribute valign
         * @type 'top' | 'bottom'
         * @default 'top'
         */
        valign: 'top'

      },

      measure: function() {
        var target = this.target;
        // remember position, because core-overlay may have set the property
        var pos = target.style.position;

        // get the size of the target as if it's positioned in the top left
        // corner of the screen
        target.style.position = 'fixed';
        target.style.left = '0px';
        target.style.top = '0px';

        var rect = target.getBoundingClientRect();

        target.style.position = pos;
        target.style.left = null;
        target.style.top = null;

        return rect;
      },

      resetTargetDimensions: function() {
        var dims = this.dimensions;
        var style = this.target.style;
        if (dims.position.h_by === this.localName) {
          style[dims.position.h] = null;
        }
        if (dims.position.v_by === this.localName) {
          style[dims.position.v] = null;
        }
        this.super();
      },

      positionTarget: function() {
        if (!this.relatedTarget) {
          this.super();
          return;
        }

        var target = this.target;
        var related = this.relatedTarget;

        // explicitly set width/height, because we don't want it constrained
        // to the offsetParent
        var rect = this.measure();
        target.style.width = rect.width + 'px';
        target.style.height = rect.height + 'px';

        var t_op = target.offsetParent;
        var r_op = related.offsetParent;
        if (window.ShadowDOMPolyfill) {
          t_op = wrap(t_op);
          r_op = wrap(r_op);
        }

        if (t_op !== r_op && t_op !== related) {
          console.warn('core-dropdown-overlay: dropdown\'s offsetParent must be the relatedTarget or the relatedTarget\'s offsetParent!');
        }

        // Don't use CSS to handle halign/valign so we can use
        // dimensions.position to detect custom positioning

        var dims = this.dimensions;
        var margin = dims.margin;
        var inside = t_op === related;

        if (!dims.position.h) {
          if (this.halign === 'right') {
            target.style.right = ((inside ? 0 : t_op.offsetWidth - related.offsetLeft - related.offsetWidth) - margin.right) + 'px';
            dims.position.h = 'right';
          } else {
            target.style.left = ((inside ? 0 : related.offsetLeft) - margin.left) + 'px';
            dims.position.h = 'left';
          }
          dims.position.h_by = this.localName;
        }

        if (!dims.position.v) {
          if (this.valign === 'bottom') {
            target.style.bottom = ((inside ? 0 : t_op.offsetHeight - related.offsetTop - related.offsetHeight) - margin.bottom) + 'px';
            dims.position.v = 'bottom';
          } else {
            target.style.top = ((inside ? 0 : related.offsetTop) - margin.top) + 'px';
            dims.position.v = 'top';
          }
          dims.position.v_by = this.localName;
        }
      }

    });
  