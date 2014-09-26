
    (function() {

      var ANIMATION_GROUPS = {
        'par': AnimationGroup,
        'seq': AnimationSequence
      };

      Polymer({

        publish: {
          /**
           * If target is set, any children without a target will be assigned the group's
           * target when this property is set.
           *
           * @property target
           * @type HTMLElement|Node|Array|Array<HTMLElement|Node>
           */

          /**
           * For a `core-animation-group`, a duration of "auto" means the duration should
           * be the specified duration of its children. If set to anything other than
           * "auto", any children without a set duration will be assigned the group's duration.
           *
           * @property duration
           * @type number
           * @default "auto"
           */
          duration: {value: 'auto', reflect: true},

          /**
           * The type of the animation group. 'par' creates a parallel group and 'seq' creates
           * a sequential group.
           *
           * @property type
           * @type String
           * @default 'par'
           */
          type: {value: 'par', reflect: true}
        },

        typeChanged: function() {
          this.apply();
        },

        targetChanged: function() {
          // Only propagate target to children animations if it's defined.
          if (this.target) {
            this.doOnChildren(function(c) {
              c.target = this.target;
            }.bind(this));
          }
        },

        durationChanged: function() {
          if (this.duration && this.duration !== 'auto') {
            this.doOnChildren(function(c) {
              // Propagate to children that is not a group and has no
              // duration specified.
              if (!c.type && (!c.duration || c.duration === 'auto')) {
                c.duration = this.duration;
              }
            }.bind(this));
          }
        },

        doOnChildren: function(inFn) {
          var children = this.children;
          if (!children.length) {
            children = this.shadowRoot ? this.shadowRoot.childNodes : [];
          }
          Array.prototype.forEach.call(children, function(c) {
            // TODO <template> in the way
            c.apply && inFn(c);
          }, this);
        },

        makeAnimation: function() {
          return new ANIMATION_GROUPS[this.type](this.childAnimations, this.timingProps);
        },

        hasTarget: function() {
          var ht = this.target !== null;
          if (!ht) {
            this.doOnChildren(function(c) {
              ht = ht || c.hasTarget();
            }.bind(this));
          }
          return ht;
        },

        apply: function() {
          // Propagate target and duration to child animations first.
          this.durationChanged();
          this.targetChanged();
          this.doOnChildren(function(c) {
            c.apply();
          });
          return this.super();
        },

        get childAnimationElements() {
          var list = [];
          this.doOnChildren(function(c) {
            if (c.makeAnimation) {
              list.push(c);
            }
          });
          return list;
        },

        get childAnimations() {
          var list = [];
          this.doOnChildren(function(c) {
            if (c.animation) {
              list.push(c.animation);
            }
          });
          return list;
        }
      });

    })();
  