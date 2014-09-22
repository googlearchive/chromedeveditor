
  
    document.querySelector('#mediaQuery').addEventListener('core-media-change',
      function(e) {
        document.body.classList.toggle('core-narrow', e.detail.matches);
      });
  
  