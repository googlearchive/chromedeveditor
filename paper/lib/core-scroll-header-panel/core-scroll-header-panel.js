

  Polymer('core-scroll-header-panel', {
    
    /**
     * Fired when the content has been scrolled.
     *
     * @event scroll
     */
     
    /**
     * Fired when the header is transformed.
     *
     * @event core-header-transform
     */
     
    publish: {
      /**
       * If true, the header's height will condense to `_condensedHeaderHeight`
       * as the user scrolls down from the top of the content area.
       *
       * @attribute condenses
       * @type boolean
       * @default false
       */
      condenses: false,

      /**
       * If true, no cross-fade transition from one background to another.
       *
       * @attribute noDissolve
       * @type boolean
       * @default false
       */
      noDissolve: false,

      /**
       * If true, the header doesn't slide back in when scrolling back up.
       *
       * @attribute noReveal
       * @type boolean
       * @default false
       */
      noReveal: false,

      /**
       * If true, the header is fixed to the top and never moves away.
       *
       * @attribute fixed
       * @type boolean
       * @default false
       */
      fixed: false,
      
      /**
       * If true, the condensed header is always shown and does not move away.
       *
       * @attribute keepCondensedHeader
       * @type boolean
       * @default false
       */
      keepCondensedHeader: false,

      /**
       * The height of the header when it is at its full size.
       *
       * By default, the height will be measured when it is ready.  If the height
       * changes later the user needs to either set this value to reflect the
       * new height or invoke `measureHeaderHeight()`.
       *
       * @attribute headerHeight
       * @type number
       */
      headerHeight: 0,

      /**
       * The height of the header when it is condensed.
       *
       * By default, `_condensedHeaderHeight` is 1/3 of `headerHeight` unless
       * this is specified.
       *
       * @attribute condensedHeaderHeight
       * @type number
       */
      condensedHeaderHeight: 0,
      
      /**
       * By default, the top part of the header stays when the header is being
       * condensed.  Set this to true if you want the top part of the header
       * to be scrolled away.
       *
       * @attribute scrollAwayTopbar
       * @type boolean
       * @default false
       */
      scrollAwayTopbar: false
    },

    prevScrollTop: 0,
    
    headerMargin: 0,
    
    y: 0,
    
    observe: {
      'headerMargin fixed': 'setup'
    },
    
    ready: function() {
      this._scrollHandler = this.scroll.bind(this);
      this.scroller.addEventListener('scroll', this._scrollHandler);
    },
    
    detached: function() {
      this.scroller.removeEventListener('scroll', this._scrollHandler);
    },
    
    domReady: function() {
      this.async('measureHeaderHeight');
    },

    get header() {
      return this.$.headerContent.getDistributedNodes()[0];
    },
    
    /**
     * Returns the scrollable element.
     *
     * @property scroller
     * @type Object
     */
    get scroller() {
      return this.$.mainContainer;
    },
    
    measureHeaderHeight: function() {
      var header = this.header;
      if (this.header) {
        this.headerHeight = header.offsetHeight;
      }
    },
    
    headerHeightChanged: function() {
      if (!this.condensedHeaderHeight) {
        // assume _condensedHeaderHeight is 1/3 of the headerHeight
        this._condensedHeaderHeight = this.headerHeight * 1 / 3;
      }
      this.condensedHeaderHeightChanged();
    },
    
    condensedHeaderHeightChanged: function() {
      if (this.condensedHeaderHeight) {
        this._condensedHeaderHeight = this.condensedHeaderHeight;
      }
      if (this.headerHeight) {
        this.headerMargin = this.headerHeight - this._condensedHeaderHeight;
      }
    },
    
    condensesChanged: function() {
      if (this.condenses) {
        this.scroll();
      } else {
        // reset transform/opacity set on the header
        this.condenseHeader(null);
      }
    },
    
    setup: function() {
      var s = this.scroller.style;
      s.paddingTop = this.fixed ? '' : this.headerHeight + 'px';
      s.top = this.fixed ? this.headerHeight + 'px' : '';
      if (this.fixed) {
        this.transformHeader(null);
      } else {
        this.scroll();
      }
    },
    
    transformHeader: function(y) {
      var s = this.$.headerContainer.style;
      this.translateY(s, -y);
      
      if (this.condenses) {
        this.condenseHeader(y);
      }
      
      this.fire('core-header-transform', {y: y, height: this.headerHeight, 
          condensedHeight: this._condensedHeaderHeight});
    },
    
    condenseHeader: function(y) {
      var reset = y == null;
      // adjust top bar in core-header so the top bar stays at the top
      if (!this.scrollAwayTopbar && this.header.$ && this.header.$.topBar) {
        this.translateY(this.header.$.topBar.style, 
            reset ? null : Math.min(y, this.headerMargin));
      }
      // transition header bg
      var hbg = this.$.headerBg.style;
      if (!this.noDissolve) {
        hbg.opacity = reset ? '' : (this.headerMargin - y) / this.headerMargin;
      }
      // adjust header bg so it stays at the center
      this.translateY(hbg, reset ? null : y / 2);
      // transition condensed header bg
      var chbg = this.$.condensedHeaderBg.style;
      if (!this.noDissolve) {
        chbg = this.$.condensedHeaderBg.style;
        chbg.opacity = reset ? '' : y / this.headerMargin;
        // adjust condensed header bg so it stays at the center
        this.translateY(chbg, reset ? null : y / 2);
      }
    },
    
    translateY: function(s, y) {
      s.transform = s.webkitTransform = y == null ? '' : 
          'translate3d(0, ' + y + 'px, 0)';
    },
    
    scroll: function(event) {
      if (!this.header) {
        return;
      }
      
      var sTop = this.scroller.scrollTop;
      
      var y = Math.min(this.keepCondensedHeader ? 
          this.headerMargin : this.headerHeight, Math.max(0, 
          (this.noReveal ? sTop : this.y + sTop - this.prevScrollTop)));
      
      if (this.condenses && this.prevScrollTop >= sTop && sTop > this.headerMargin) {
        y = Math.max(y, this.headerMargin);
      }
      
      if (!event || !this.fixed && y !== this.y) {
        requestAnimationFrame(this.transformHeader.bind(this, y));
      }
      
      this.prevScrollTop = Math.max(sTop, 0);
      this.y = y;
      
      if (event) {
        this.fire('scroll', {target: this.scroller}, this, false);
      }
    }

  });

