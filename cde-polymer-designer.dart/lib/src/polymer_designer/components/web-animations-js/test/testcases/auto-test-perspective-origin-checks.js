timing_test(function() {
  at(0 * 1000, function() {
    assert_styles(".test",{'perspectiveOrigin':'50px 50px'});
  });
  at(0.5 * 1000, function() {
    assert_styles(".test", [
      {'perspectiveOrigin':'37.5px 37.5px'},
      {'perspectiveOrigin':'37.5px 50px'},
      {'perspectiveOrigin':'62.5px 50px'},
      {'perspectiveOrigin':'50px 37.5px'},
      {'perspectiveOrigin':'50px 62.5px'},
      {'perspectiveOrigin':'50px 50px'},
      {'perspectiveOrigin':'37.5px 37.5px'},
      {'perspectiveOrigin':'57.5px 57.5px'},
      {'perspectiveOrigin':'42.5px 52.5px'},
      {'perspectiveOrigin':'37.5px 62.5px'},
    ]);
  });
  at(1 * 1000, function() {
    assert_styles(".test", [
      {'perspectiveOrigin':'25px 25px'},
      {'perspectiveOrigin':'25px 50px'},
      {'perspectiveOrigin':'75px 50px'},
      {'perspectiveOrigin':'50px 25px'},
      {'perspectiveOrigin':'50px 75px'},
      {'perspectiveOrigin':'50px 50px'},
      {'perspectiveOrigin':'25px 25px'},
      {'perspectiveOrigin':'65px 65px'},
      {'perspectiveOrigin':'35px 55px'},
      {'perspectiveOrigin':'25px 75px'},
    ]);
  });
  at(1.5 * 1000, function() {
    assert_styles(".test", [
      {'perspectiveOrigin':'12.5px 12.5px'},
      {'perspectiveOrigin':'12.5px 50px'},
      {'perspectiveOrigin':'87.5px 50px'},
      {'perspectiveOrigin':'50px 12.5px'},
      {'perspectiveOrigin':'50px 87.5px'},
      {'perspectiveOrigin':'50px 50px'},
      {'perspectiveOrigin':'12.5px 12.5px'},
      {'perspectiveOrigin':'72.5px 72.5px'},
      {'perspectiveOrigin':'27.5px 57.5px'},
      {'perspectiveOrigin':'12.5px 87.5px'},
    ]);
  });
  at(2 * 1000, function() {
    assert_styles(".test", [
      {'perspectiveOrigin':'0px 0px'},
      {'perspectiveOrigin':'0px 50px'},
      {'perspectiveOrigin':'100px 50px'},
      {'perspectiveOrigin':'50px 0px'},
      {'perspectiveOrigin':'50px 100px'},
      {'perspectiveOrigin':'50px 50px'},
      {'perspectiveOrigin':'0px 0px'},
      {'perspectiveOrigin':'80px 80px'},
      {'perspectiveOrigin':'20px 60px'},
      {'perspectiveOrigin':'0px 100px'},
    ]);
  });
}, "Auto generated tests");
