prettify-element
===================

See the [component page](http://polymer.github.io/prettify-element) for more information.

prettify-import
==================

Import files are a new invention, so libraries like [`prettify`](https://code.google.com/p/prettify/) do not yet provide them.

`prettify-import` is an intermediary that provides an import file for the `prettify` component. 
`prettify-import` depends on `prettify`.

Components that want to use `prettify` standalone should depend on `prettify-import`.  Such components need not use Polymer or `prettify-element`, but we put the import and the element in one package for convenience.
