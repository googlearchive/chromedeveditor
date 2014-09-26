
        // Get the core-transition
        var meta = document.createElement('core-meta');
        meta.type = 'transition';
        var transition = meta.byId('my-fade-out');

        // Run the animation
        var animated = document.getElementById('animate-me');
        transition.go(animated);
    