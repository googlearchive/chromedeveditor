
(function() {
  var strings = [
    "PARKOUR!",
    "Neque porro quisquam est qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit...",
    "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book."
  ];

  var namegen = {
    generateString: function(inLength) {
      var s = '';
      for (var i=0; i<inLength; i++) {
        s += String.fromCharCode(Math.floor(Math.random() * 26) + 97);
      }
      return s;
    },
    generateName: function(inMin, inMax) {
      return this.generateString(Math.floor(Math.random() * (inMax - inMin + 1) + inMin));
    }
  };

  Polymer('list-test', {
    count: 1000,
    ready: function() {
      this.data = this.generateData();
    },
    generateData: function() {
      var names = [], data = [];
      for (var i=0; i<this.count; i++) {
        names.push(namegen.generateName(4, 8));
      }
      names.sort();
      for (var i=0, o; i<this.count; i++) {
        var name = names[i];
        var divider = name.charAt(0);
        if (divider === (names[i-1] || '').charAt(0)) {
          divider = null;
        }
        o = {
          index: i,
          name: name,
          divider: divider,
          details: strings[i % 3],
          time: '8:29pm'
        };
        data.push(o);
        if (divider) {
          o = Object.create(o);
          o.divider = false;
          data.push(o);
        }
      }
      return data;
    },
    tapAction: function(e) {
      console.log('tap', e);
    }
  });
})();  
