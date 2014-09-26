
      document.addEventListener('click', function(e) {
        var pages = document.querySelector('core-pages');
        pages.selected = (pages.selected + 1) % pages.children.length;
      });
    