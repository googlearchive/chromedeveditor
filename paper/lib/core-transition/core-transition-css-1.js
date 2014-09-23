
        // Get the core-transition
        var meta = document.createElement('core-meta');
        meta.type = 'transition';
        var transition1 = meta.byId('my-transition-top');

        // Set up the animation
        var animated = document.getElementById('animate-me');
        transition1.setup(animated);
        transition1.go(animated, {opened: true});
    