designer
========

# Getting Started

1. Clone the repo and `cd` in
2. Run `git fetch --tags` to get all releases
3. Run `git checkout [LATEST TAG]`, ex: `git checkout 0.3.5`
4. From the root of the project run `bower install`
5. Start a local server, ex: `python -m SimpleHTTPServer`
6. Navigate to http://localhost:[YOUR SERVER PORT]

## Things to know

### Bower Resolutions

When you run `bower install` it may ask you to pick a version of a particular dependency. Because the designer is still very bleeding edge and we're constantly fixing bugs, we often recommend you choose the `master` option if it's presented. You can preserve this resolution by preceding it with a bang "!" symbol. Long term we hope to eliminate the need for this action by making sure all dependencies in designer work with the current tag and do not require resolutions.

## Adding your own components to designer

1. Add a `metadata.html` file to your component's repo
2. Add your component as a dependency in designer's `bower.json`
3. Run `bower install` to fetch your component
4. Add the path to your `metadata.html` file to the `index.html` file

``` html
<!-- designer/index.html -->
<script>
  var metadata = [
    '../components/core-elements/metadata.html',
    '../components/more-elements/metadata.html',
    '../components/my-element/metadata.html'  // <-- add your element here
  ];
</script>
```

### metadata.html

The `metadata.html` file instructs the designer on how to work with your component. The `metadata.html` consists of an `x-meta` tag that contains:

- A `template` for your element. The contents of this template are what the user will be dragging onto the stage, so it can be used to stub out a version of your element with default attribute values and inline styles.
- **Optional** `property` elements for generating [property editors](#property-editors) in the Properties panel.
- A `template`for your element's HTML import.

``` html
<!-- Example metadata.html -->
<x-meta id="google-map" label="Google Map" group="Google Web Components">

  <template>
    <google-map zoom="18" style="width: 400px; height: 400px; display: block;"></google-map>
  </template>

  <property name="zoom"
            kind="number">
  </property>
  
  <property name="mapType"
            kind="select"
            options="roadmap,satellite,hybrid,terrain">
  </property>

  <!-- Make sure you put your element import last! -->
  <!-- https://github.com/Polymer/designer/issues/59 -->
  <template id="imports">
    <link rel="import" href="google-map.html">
  </template>

</x-meta>
```

The `x-meta` element supports the following attributes:

Attribute     | Type        | Required?   | Description
---           | ---         | ---         | ---
`id`          | *String*    | `true`      | A unique id for your element
`label`       | *String*    | `true`      | The name your element will display in the Element's Palette
`group`       | *String*    | `false`     | The group that will contain your element in the Element's Palette
`isContainer` | *Boolean*   | `false`     | Indicates if your element can contain other elements

### Property Editors

Every element will generate property editors for all of its published properties (anything appearing in the `attributes` attribute or the `publish` object), and any attributes defined in its `metadata.html` template.

The default behavior is to generate string editors for these properties. By using a `property` element, you may hint to the designer that it should display a more specific editor. Below is a list of all of the currently supported editor types with examples.

#### String

A basic string editor

<strong>Example:</strong>

``` html
<property name="username" kind="string"></property>
```

#### Number

A basic number editor. Will call `Number(value)` to insure values are processed correctly.

<strong>Example:</strong>

``` html
<property name="count" kind="number"></property>
```

#### Color

A color picker

<strong>Example:</strong>

``` html
<property name="color" kind="color"></property>
```

#### Boolean

A checkbox

<strong>Example:</strong>

``` html
<property name="showMapMarker" kind="boolean"></property>
```

#### Select

A dropdown for selecting from a list of options.

Attribute     | Type        | Description
---           | ---         | ---
`options`     | *String*    | A comma separated list of options

<strong>Example:</strong>

``` html
<property name="sizes" kind="select" options="small,medium,large"></property>
```

#### Text

A `textarea` for long form text content.

<strong>Example:</strong>

``` html
<property name="description" kind="text"></property>
```

#### JSON

A `textarea` for JSON content.

<strong>Example:</strong>

``` html
<property name="user" kind="json"></property>
```

#### Range

A range slider

Attribute     | Type        | Description
---           | ---         | ---
`min`          | *Number*   | Minimum range value
`max`       | *Number*      | Maximum range value
`step`       | *Number*     | The increment used when increasing or decreasing the range slider
`defaultValue` | *Number*   | Initial value for range slider

<strong>Example:</strong>

``` html
<property name="total" kind="range" min="1.0" max="5.0" step="0.1" defaultValue="3.5"></property>
```
