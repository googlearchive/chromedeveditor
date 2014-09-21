
(function() {
  var avatar;

  Polymer('core-drag-drop', {

    observe: {
      'x y': 'coordinatesChanged'
    },

    ready: function() {
      if (!avatar) {
        avatar = document.createElement('core-drag-avatar');
        document.body.appendChild(avatar);
      }
      this.avatar = avatar;
      this.dragging = false;
    },

    draggingChanged: function() {
      this.avatar.style.display = this.dragging ? '' : 'none';
    },

    coordinatesChanged: function() {
      var x = this.x, y = this.y;
      this.avatar.style.transform = 
        this.avatar.style.webkitTransform = 
          'translate(' + x + 'px, ' + y + 'px)';
    },

    attached: function() {
      var listen = function(event, handler) {
        Polymer.addEventListener(this.parentNode, event, this[handler].bind(this));
      }.bind(this);
      //
      listen('trackstart', 'trackStart');
      listen('track', 'track');
      listen('trackend', 'trackEnd');
      //
      var host = this.parentNode.host || this.parentNode;
      host.style.cssText += '; user-select: none; -webkit-user-select: none; -moz-user-select: none; -ms-user-select: none;';
    },

    trackStart: function(event) {
      this.avatar.style.cssText = '';
      this.dragInfo = {
        event: event,
        avatar: this.avatar
      };
      this.fire('drag-start', this.dragInfo);
      // flaw #1: what if user doesn't need `drag()`?
      this.dragging = Boolean(this.dragInfo.drag);
    },

    track: function(event) {
      if (this.dragging) {
        this.x = event.pageX;
        this.y = event.pageY;
        this.dragInfo.event = event;
        this.dragInfo.p = {x : this.x, y: this.y};
        this.dragInfo.drag(this.dragInfo);
      }
    },

    trackEnd: function(event) {
      if (this.dragging) {
        this.dragging = false;
        if (this.dragInfo.drop) {
          this.dragInfo.framed = this.framed(event.relatedTarget);
          this.dragInfo.event = event;
          this.dragInfo.drop(this.dragInfo);
        }
      }
      this.dragInfo = null;
    },

    framed: function(node) {
      var local = node.getBoundingClientRect();
      return {x: this.x - local.left, y: this.y - local.top};
    }

  });

})();
