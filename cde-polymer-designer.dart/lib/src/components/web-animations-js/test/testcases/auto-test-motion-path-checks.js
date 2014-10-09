timing_test(function() {
  at(0 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.9701425001453319, 0.24253562503633294, -0.24253562503633294, 0.9701425001453319, 387.5, 87.5)'});
  }, "Check #animTR at t=0ms");
  at(0 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.315770091409682, 0.9488357336078364, -0.9488357336078364, 0.315770091409682, 87.5, 287.5)'});
  }, "Check #animBL at t=0ms");
  at(0 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0.7992672511833444, 0.6009757575691558, -0.6009757575691558, 0.7992672511833444, 387.5, 287.5)'});
  }, "Check #animBR at t=0ms");
  at(1 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.9701425001453319, 0.24253562503633294, -0.24253562503633294, 0.9701425001453319, 387.5, 87.5)'});
  }, "Check #animTR at t=1000ms");
  at(1 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 87.5, 237.5)'});
  }, "Check #animBL at t=1000ms");
  at(1 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 387.5, 237.5)'});
  }, "Check #animBR at t=1000ms");
  at(2 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.9701425001453319, 0.24253562503633294, -0.24253562503633294, 0.9701425001453319, 387.5, 87.5)'});
  }, "Check #animTR at t=2000ms");
  at(2 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(1, 0, 0, 1, 137.5, 237.5)'});
  }, "Check #animBL at t=2000ms");
  at(2 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(1, 0, 0, 1, 437.5, 237.5)'});
  }, "Check #animBR at t=2000ms");
  at(3 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 387.5, 62.5)'});
  }, "Check #animTR at t=3000ms");
  at(3 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(1, 0, 0, 1, 187.5, 237.5)'});
  }, "Check #animBL at t=3000ms");
  at(3 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(1, 0, 0, 1, 487.5, 237.5)'});
  }, "Check #animBR at t=3000ms");
  at(4 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 387.5, 37.5)'});
  }, "Check #animTR at t=4000ms");
  at(4 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.5753043900207572, 0.8179393980135964, -0.8179393980135964, 0.5753043900207572, 216.27749633789063, 278.3883361816406)'});
  }, "Check #animBL at t=4000ms");
  at(4 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0.309, -0.9511, 0.9511, 0.309, 387.5, 287.5)'});
  }, "Check #animBR at t=4000ms");
  at(5 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(1, 0, 0, 1, 437.5, 37.5)'});
  }, "Check #animTR at t=5000ms");
  at(5 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.5742821086196931, 0.818657473989775, -0.818657473989775, 0.5742821086196931, 245.05499267578125, 319.27667236328125)'});
  }, "Check #animBL at t=5000ms");
  at(5 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0, -1, 1, 0, 387.5, 287.5)'});
  }, "Check #animBR at t=5000ms");
  at(6 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(1, 0, 0, 1, 487.5, 37.5)'});
  }, "Check #animTR at t=6000ms");
  at(6 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.5763239825284185, 0.8172213085588157, -0.8172213085588157, 0.5763239825284185, 273.8324890136719, 360.1650085449219)'});
  }, "Check #animBL at t=6000ms");
  at(6 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(-0.309, -0.9511, 0.9511, -0.309, 387.5, 287.5)'});
  }, "Check #animBR at t=6000ms");
  at(7 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.5742821086196931, 0.818657473989775, -0.818657473989775, 0.5742821086196931, 530.666259765625, 98.83250427246094)'});
  }, "Check #animTR at t=7000ms");
  at(7 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(-0.9318041877673755, -0.36296136937583534, 0.36296136937583534, -0.9318041877673755, 227.24935913085938, 341.998779296875)'});
  }, "Check #animBL at t=7000ms");
  at(7 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(-0.931197578528315, -0.3645148415949653, 0.3645148415949653, -0.931197578528315, 527.2493896484375, 341.998779296875)'});
  }, "Check #animBR at t=7000ms");
  at(8 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.5742821086196931, 0.818657473989775, -0.818657473989775, 0.5742821086196931, 573.83251953125, 160.16500854492188)'});
  }, "Check #animTR at t=8000ms");
  at(8 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(-0.932004671541296, -0.36244626115494827, 0.36244626115494827, -0.932004671541296, 180.66622924804688, 323.83251953125)'});
  }, "Check #animBL at t=8000ms");
  at(8 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(-0.932004671541296, -0.36244626115494827, 0.36244626115494827, -0.932004671541296, 480.6662292480469, 323.83251953125)'});
  }, "Check #animBR at t=8000ms");
  at(9 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(-0.932004671541296, -0.36244626115494827, 0.36244626115494827, -0.932004671541296, 480.6662292480469, 123.83251953125)'});
  }, "Check #animTR at t=9000ms");
  at(9 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(-0.9318041877673755, -0.36296136937583534, 0.36296136937583534, -0.9318041877673755, 134.08311462402344, 305.666259765625)'});
  }, "Check #animBL at t=9000ms");
  at(9 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(-0.9316028474785737, -0.3634778322949191, 0.3634778322949191, -0.9316028474785737, 434.0831298828125, 305.666259765625)'});
  }, "Check #animBR at t=9000ms");
  at(10 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.9701425001453319, 0.24253562503633294, -0.24253562503633294, 0.9701425001453319, 387.5, 87.5)'});
  }, "Check #animTR at t=10000ms");
  at(10 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.315770091409682, 0.9488357336078364, -0.9488357336078364, 0.315770091409682, 87.5, 287.5)'});
  }, "Check #animBL at t=10000ms");
  at(10 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0.7992672511833444, 0.6009757575691558, -0.6009757575691558, 0.7992672511833444, 387.5, 287.5)'});
  }, "Check #animBR at t=10000ms");
  at(11 * 1000, function() {
    assert_styles("#animTR", {'transform':'matrix(0.9701425001453319, 0.24253562503633294, -0.24253562503633294, 0.9701425001453319, 387.5, 87.5)'});
  }, "Check #animTR at t=11000ms");
  at(11 * 1000, function() {
    assert_styles("#animBL", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 87.5, 237.5)'});
  }, "Check #animBL at t=11000ms");
  at(11 * 1000, function() {
    assert_styles("#animBR", {'transform':'matrix(0.00000000000000006123031769111886, -1, 1, 0.00000000000000006123031769111886, 387.5, 237.5)'});
  }, "Check #animBR at t=11000ms");
}, "Autogenerated checks.");
