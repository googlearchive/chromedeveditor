timing_test(function() {
  at(0 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(0, 240, 50, 1)'});
  });
  at(0.2 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(30, 200, 90, 1)'});
  });
  at(0.4 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(60, 160, 130, 1)'});
  });
  at(0.6000000000000001 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(90, 120, 170, 1)'});
  });
  at(0.8 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(120, 80, 210, 1)'});
  });
  at(1 * 1000, function() {
    assert_styles(".anim",{'stroke':'rgba(150, 40, 250, 1)'});
  });
}, "Auto generated tests");
