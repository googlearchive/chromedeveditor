timing_test(function() {
  at(0 * 1000, function() {
    assert_styles(".test",{'webkitTransformOrigin':'50px 50px'});
  });
  at(1 * 1000, function() {
    assert_styles(".test", [
      {'webkitTransformOrigin':'50px 50px'},
      {'webkitTransformOrigin':'25px 50px'},
      {'webkitTransformOrigin':'75px 50px'},
      {'webkitTransformOrigin':'50px 25px'},
      {'webkitTransformOrigin':'50px 75px'},
      {'webkitTransformOrigin':'37.5px 50px'},
      {'webkitTransformOrigin':'25px 25px'},
      {'webkitTransformOrigin':'30px 50px'},
      {'webkitTransformOrigin':'30px 50px 50px'},
      {'webkitTransformOrigin':'75px 75px 50px'},
      {'webkitTransformOrigin':'75px 35px'},
      {'webkitTransformOrigin':'75px 35px -100px'},
    ]);
  });
  at(2 * 1000, function() {
    assert_styles(".test", [
      {'webkitTransformOrigin':'50px 50px'},
      {'webkitTransformOrigin':'0px 50px'},
      {'webkitTransformOrigin':'100px 50px'},
      {'webkitTransformOrigin':'50px 0px'},
      {'webkitTransformOrigin':'50px 100px'},
      {'webkitTransformOrigin':'25px 50px'},
      {'webkitTransformOrigin':'0px 0px'},
      {'webkitTransformOrigin':'10px 50px'},
      {'webkitTransformOrigin':'10px 50px 100px'},
      {'webkitTransformOrigin':'100px 100px 100px'},
      {'webkitTransformOrigin':'100px 20px'},
      {'webkitTransformOrigin':'100px 20px -200px'},
    ]);
  });
}, "Auto generated tests");
