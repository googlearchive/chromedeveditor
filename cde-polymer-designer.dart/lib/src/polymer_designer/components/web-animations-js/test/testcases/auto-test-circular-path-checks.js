timing_test(function() {
  at(0, function() {
    assert_styles("#anim",{'transform':'matrix(0.7924, 0.61, -0.61, 0.7924, 117.5, 87.5)'});
  });
  at(1000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9836, 0.1802, -0.1802, 0.9836, 145.7, 146.2)'});
  });
  at(2000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9755, -0.2198, 0.2198, 0.9755, 209.2, 160.6)'});
  });
  at(3000, function() {
    assert_styles("#anim",{'transform':'matrix(0.4368, -0.8996, 0.8996, 0.4368, 260.1, 120)'});
  });
  at(4000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9328, -0.3605, 0.3605, -0.9328, 260.2, 54.85)'});
  });
  at(5000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9995, -0.03009, 0.03009, -0.9995, 209.2, 14.32)'});
  });
  at(6000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.7815, 0.6239, -0.6239, -0.7815, 145.7, 28.86)'});
  });
  at(7000, function() {
    assert_styles("#anim",{'transform':'matrix(0.7924, 0.61, -0.61, 0.7924, 247.5, 187.5)'});
  });
  at(8000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9836, 0.1802, -0.1802, 0.9836, 275.7, 246.2)'});
  });
  at(9000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9755, -0.2198, 0.2198, 0.9755, 339.2, 260.6)'});
  });
  at(10000, function() {
    assert_styles("#anim",{'transform':'matrix(0.4368, -0.8996, 0.8996, 0.4368, 390.1, 220)'});
  });
  at(11000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9328, -0.3605, 0.3605, -0.9328, 390.2, 154.8)'});
  });
  at(12000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9995, -0.03009, 0.03009, -0.9995, 339.2, 114.3)'});
  });
  at(13000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.7815, 0.6239, -0.6239, -0.7815, 275.7, 128.9)'});
  });
  at(14000, function() {
    assert_styles("#anim",{'transform':'matrix(0.7924, 0.61, -0.61, 0.7924, 377.5, 287.5)'});
  });
  at(15000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9836, 0.1802, -0.1802, 0.9836, 405.7, 346.2)'});
  });
  at(16000, function() {
    assert_styles("#anim",{'transform':'matrix(0.9755, -0.2198, 0.2198, 0.9755, 469.2, 360.6)'});
  });
  at(17000, function() {
    assert_styles("#anim",{'transform':'matrix(0.4368, -0.8996, 0.8996, 0.4368, 520.1, 320)'});
  });
  at(18000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9328, -0.3605, 0.3605, -0.9328, 520.2, 254.8)'});
  });
  at(19000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.9995, -0.03009, 0.03009, -0.9995, 469.2, 214.3)'});
  });
  at(20000, function() {
    assert_styles("#anim",{'transform':'matrix(-0.7815, 0.6239, -0.6239, -0.7815, 405.7, 228.9)'});
  });
}, "Auto generated tests");
