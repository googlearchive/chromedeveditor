# cde_core

Low-level, core functionality for the Chrome Dev Editor (CDE).

This package contains libraries to aid in de-coupling classes and components in
an application.

The `Dependencies` class is a simple dependency manager. It manages a set of
dependencies and can delegate request to parent dependency managers, scoped by
Dart `Zone`s.

The `EventBus` class is an event bus implementation. It lets clients subscribe
to all events on the bus, to subscribe to s filtered subset of the events, and
to publish events to the bus.
