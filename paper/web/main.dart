
import 'dart:html';

void main() {
  Element e = querySelector('#done');
  e.onClick.listen((_) {
    print('Done!');
  });
}
