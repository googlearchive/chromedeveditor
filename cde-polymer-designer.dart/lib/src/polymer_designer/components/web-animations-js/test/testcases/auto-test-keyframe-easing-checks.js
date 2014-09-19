timing_test(function() {
  at(0 * 1000, function() {
    assert_styles("#target",{'height':'0px'});
  });
  at(0.25 * 1000, function() {
    assert_styles("#target",{'height':'12.5px'});
  });
  at(0.5 * 1000, function() {
    assert_styles("#target",{'height':'25px'});
  });
  at(0.75 * 1000, function() {
    assert_styles("#target",{'height':'37.5px'});
  });
  at(1 * 1000, function() {
    assert_styles("#target",{'height':'50px'});
  });
  at(1.25 * 1000, function() {
    assert_styles("#target",{'height':'62.5px'});
  });
  at(1.5 * 1000, function() {
    assert_styles("#target",{'height':'75px'});
  });
  at(1.75 * 1000, function() {
    assert_styles("#target",{'height':'87.5px'});
  });
  at(2 * 1000, function() {
    assert_styles("#target",{'height':'100px'});
  });
  at(2.25 * 1000, function() {
    assert_styles("#target",{'height':'106.5px'});
  });
  at(2.5 * 1000, function() {
    assert_styles("#target",{'height':'125px'});
  });
  at(2.75 * 1000, function() {
    assert_styles("#target",{'height':'143.5px'});
  });
  at(3 * 1000, function() {
    assert_styles("#target",{'height':'150px'});
  });
  at(3.25 * 1000, function() {
    assert_styles("#target",{'height':'150px'});
  });
  at(3.5 * 1000, function() {
    assert_styles("#target",{'height':'150px'});
  });
  at(3.75 * 1000, function() {
    assert_styles("#target",{'height':'200px'});
  });
  at(4 * 1000, function() {
    assert_styles("#target",{'height':'200px'});
  });
  at(4.25 * 1000, function() {
    assert_styles("#target",{'height':'200px'});
  });
  at(4.5 * 1000, function() {
    assert_styles("#target",{'height':'225px'});
  });
  at(4.75 * 1000, function() {
    assert_styles("#target",{'height':'225px'});
  });
  at(5 * 1000, function() {
    assert_styles("#target",{'height':'250px'});
  });
}, "Auto generated tests");
