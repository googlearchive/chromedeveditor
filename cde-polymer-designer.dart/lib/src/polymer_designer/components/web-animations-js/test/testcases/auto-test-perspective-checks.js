timing_test(function() {
  at(0 * 1000, function() {
    assert_styles(".test",{'perspective':'500px'});
  });
  at(0.5 * 1000, function() {
    assert_styles(".test", [
      {'perspective':'412.5px'},
      {'perspective':'625px'},
      {'perspective':'500px'},
      {'perspective':'376px'},
    ]);
  });
  at(1 * 1000, function() {
    assert_styles(".test", [
      {'perspective':'325px'},
      {'perspective':'750px'},
      {'perspective':'none'},
      {'perspective':'252px'},
    ]);
  });
  at(1.5 * 1000, function() {
    assert_styles(".test", [
      {'perspective':'237.5px'},
      {'perspective':'875px'},
      {'perspective':'none'},
      {'perspective':'128px'},
    ]);
  });
  at(2 * 1000, function() {
    assert_styles(".test", [
      {'perspective':'150px'},
      {'perspective':'1000px'},
      {'perspective':'none'},
      {'perspective':'4px'},
    ]);
  });
}, "Auto generated tests");
