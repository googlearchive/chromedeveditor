

  Polymer('core-scaffold', {
    
    publish: {
      /**
       * When the browser window size is smaller than the `responsiveWidth`, 
       * `core-drawer-panel` changes to a narrow layout. In narrow layout, 
       * the drawer will be stacked on top of the main panel.
       *
       * @attribute responsiveWidth
       * @type string
       * @default '600px'
       */    
      responsiveWidth: '600px',
  
      /**
       * Used to control the header and scrolling behaviour of `core-header-panel`
       *
       * @attribute mode
       * @type string
       * @default 'seamed'
       */     
      mode: {value: 'seamed', reflect: true}
    },

    /**
      * Toggle the drawer panel
      * @method togglePanel
      */    
    togglePanel: function() {
      this.$.drawerPanel.togglePanel();
    },

    /**
      * Open the drawer panel
      * @method openDrawer
      */      
    openDrawer: function() {
      this.$.drawerPanel.openDrawer();
    },

    /**
      * Close the drawer panel
      * @method closeDrawer
      */     
    closeDrawer: function() {
      this.$.drawerPanel.closeDrawer();
    }
    
  });

