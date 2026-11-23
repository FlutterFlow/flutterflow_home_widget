# The spec (JSON)

`homeWidgetAppFromJson` reads this; `homeWidgetAppToJson` writes it. Every
field not marked required has the default shown. Run
`flutterflow_home_widget validate spec.json` to check a spec: JSON that does
not fit says where (`$.widgets[0].layouts.small.root.type`), and a spec that
fits but would not work lists every problem.

Common forms:

- **Color**: `"#AARRGGBB"` or `"#RRGGBB"` (opaque), or
  `{"light": "#…", "dark": "#…"}` for a dark-mode value.
- **Paint** (a fill or a text or icon color): a color, or `{"value": key}`
  to use a `color` value of the widget.
- **Length**: a number of points (dp on Android), `"fill"` (all the space
  the parent gives) or `"fit"` (the content's size, the default).
- **Alignment**: `[x, y]`, each from -1 (start, top) to 1 (end, bottom).
- **Insets**: `[left, top, right, bottom]`.

## App

| Field | | |
|---|---|---|
| `iosBundleId` | required | The app's bundle id. The extension is `<id>.HomeWidget`. |
| `iosDeviceFamily` | `"1"` | `"1"` (iPhone) or `"1,2"` (iPhone and iPad), as the app's. |
| `routes.scheme` | `""` | The app's deep link scheme. Needed for a tap that opens a page. |
| `routes.host` | `""` | The host of its links. |
| `routes.encodeTwice` | `true` | Whether iOS encodes a page parameter twice (the app's router decodes a pushed link once more). |
| `widgets` | required | The widgets, in gallery order. |

## Widget

| Field | | |
|---|---|---|
| `key` | required | Names the widget in `FFHomeWidget.update` and its native types. Keep it the same across builds: Android identifies a placed widget by it. |
| `name` | `""` | The name in the widget gallery (`"Widget"` when empty). |
| `description` | `""` | The gallery's description. |
| `placeholderText` | `""` | Shown until the app first sends values. |
| `values` | `[]` | `{key, name, type, default}`. `type` is `string`, `integer`, `double`, `boolean`, `dateTime` or `color`. `default` is the wire string (below). |
| `layouts` | required | One layout per size: `small`, `medium`, `large`, `accessoryCircular`, `accessoryRectangular`, `accessoryInline`. Android draws the first three. |
| `refresh` | none | The widget fetches its own values (below). |
| `configuration` | none | Choices a person picks when placing it (below). |

Values travel as strings: integers and doubles as decimal text, booleans as
`true`/`false`, a dateTime as milliseconds since the epoch, a color as
`#AARRGGBB`. The plugin's `FFHomeWidget.encode…` helpers write them.

## Layout

`{"tap": tap, "root": node}`. `tap` is what a tap anywhere on the widget
does; without one it opens the app. In the `small` size and on the Lock
Screen iOS opens one link for the whole widget, so only this tap may open a
page there.

### Every node

| Field | | |
|---|---|---|
| `type` | required | One of the types below. |
| `key` | required | Unique in the layout; names its views. |
| `padding` | none | Insets. |
| `flex` | none | Its share of a row's or column's free space. |
| `visibleIf` | none | A `boolean` value: shown only when true. |
| `tap` | none | What a tap on it does. |
| `align` | none | Where it sits in the space its parent gives it. |

### Types

- `box`: `width`, `height` (lengths), `background` (paint), `radius`,
  `borderWidth`, `borderColor`, `childAlignment`, `clip` (clip the child to
  the rounded shape), `child`.
- `row`, `column`: `mainAxis` (`start`, `center`, `end`, `spaceBetween`,
  `spaceAround`, `spaceEvenly`), `crossAxis` (`start`, `center`, `end`,
  `stretch`; default `center`), `spacing`, `startSpacing`, `endSpacing`,
  `shrinkMain` (take only the space the children need), `children`.
- `stack`: `alignment` (default `[-1, -1]`), `children`.
- `text`: `text` (fixed) or `value` (a value's key; a `dateTime` counts down
  to its time), `fontSize` (14), `fontWeight` (400), `color` (paint),
  `textAlign` (`start`, `center`, `end`), `maxLines`, `ellipsis`,
  `letterSpacing`, `lineHeight` (a multiple of the size), `italic`,
  `underline`, `strikethrough`, `textCase` (`none`, `upper`, `lower`).
- `image`: `asset` (a Flutter asset path the app bundles, `assets/…`),
  `width`, `height`, `fit` (`contain`, `cover`, `fill`), `radius`.
- `icon`: `codePoint` (a Material Icons code point, a number or `"0xe145"`),
  `size` (24), `color` (paint).
- `spacer`: takes the free space of its row or column.
- `divider`: `space` (16), `thickness` (1), `color`, `indent`, `endIndent`.
- `progress`: `circular`, `value` (a number from 0 to 1, or
  `{"value": key}` for an `integer` or `double` value), `color`,
  `trackColor`, `size` (circular: the diameter; linear: the height),
  `thickness` (circular), `width` (linear; default `fill`), `barRadius`
  (linear), `startAngle` (circular, degrees clockwise from the top).

### Taps

- `{"openPage": "/path/:id", "params": [...]}`: opens the app at that route.
  A `:name` segment takes the parameter of that name, the others go in the
  query. Each param is `{"name", "value": key, "format"}` (`format` is
  `text`, `date` or `color`, how the app's router reads it) or
  `{"name", "constant": "text"}`.
- `{"toggle": key}`: flips a `boolean` value in place (iOS 17+).
- `{"step": key, "by": 1, "min": 0, "max": 10, "integer": true}`: adds `by`
  to a number value, kept between `min` and `max` (iOS 17+).
- `{"clear": true}`: clears the widget's values (iOS 17+).

## Refresh

```json
{
  "url": "https://example.com/trip.json",
  "headers": {"Accept": "application/json"},
  "intervalMinutes": 60,
  "values": [{"key": "departure", "type": "dateTime", "path": "$.trip.departure"}]
}
```

The widget fetches `url` every `intervalMinutes` (at least 30: Android does
not update more often) and reads each value at its JSON path. Paths are
plain: `$.a.b[0]`, `$['a b']`.

## Configuration

```json
{
  "title": "City",
  "choices": [{"id": "porto", "name": "Porto", "values": {"city": "Porto"}}],
  "appChoices": true
}
```

A person picks a choice for each copy of the widget they place, and the copy
shows the choice's values over the widget's own. With `appChoices`, the app
adds choices at run time: `FFHomeWidget.update(definitionKey: …, choiceId:
…, choiceName: …, values: …)`.
