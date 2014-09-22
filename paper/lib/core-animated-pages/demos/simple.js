
    function change() {
      var s = document.querySelector('select');
      document.querySelector('core-animated-pages').transitions = document.querySelector('select').options[s.selectedIndex].value;
    }

    var up = true;
    var max = 4;
    function stuff() {
      var p = document.querySelector('core-animated-pages');
      if (up && p.selected === max || !up && p.selected === 0) {
        up = !up;
      }
      if (up) {
        p.selected += 1;
      } else {
        p.selected -= 1;
      }
    }
  