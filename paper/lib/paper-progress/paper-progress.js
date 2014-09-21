
  
    Polymer('paper-progress', {
      
      /**
       * The number that represents the current secondary progress.
       *
       * @attribute secondaryProgress
       * @type number
       * @default 0
       */
      secondaryProgress: 0,
      
      step: 0,
      
      observe: {
        'value secondaryProgress min max': 'update'
      },
      
      update: function() {
        this.super();
        this.secondaryProgress = this.clampValue(this.secondaryProgress);
        this.secondaryRatio = this.calcRatio(this.secondaryProgress) * 100;
      }
      
    });
    
  