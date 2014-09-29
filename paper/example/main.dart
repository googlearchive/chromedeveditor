
import 'dart:html';

void main() {
  Element e = querySelector('#done');
  e.onClick.listen((_) {
    print(_);
  });

  Element dialog = querySelector('#dialog');
  dialog.on['close'].listen((_) =>print('Closed!'));
}
