timing_test(function() {
  at(0, function() {
    assert_styles(".target",{'d':'M10,10v100l100,-50z'});
  });
  at(200, function() {
    assert_styles(".target",{'d':'M48,10L48,94.72L52.72,110L112.2,87.89L148,57.64L125.9,38.94L48,10'});
  });
  at(400, function() {
    assert_styles(".target",{'d':'M86,10L86,98.54L95.44,110L159.2,93.42L186,55.28L169.4,31.71L86,10'});
  });
  at(600, function() {
    assert_styles(".target",{'d':'M124,10L124,102.4L138.2,110L206.1,98.94L224,52.92L212.9,24.47L124,10'});
  });
  at(800, function() {
    assert_styles(".target",{'d':'M162,10L162,106.2L180.9,110L253.1,104.5L262,50.56L256.5,17.24L162,10'});
  });
  at(1000, function() {
    assert_styles(".target",{'d':'M10,10v100l100,-50z'});
  });
}, "Auto generated tests");
