# amalgame-ui-forms

Cross-platform retained-mode **Forms toolkit** for
[Amalgame](https://github.com/amalgame-lang/Amalgame).
Widgets (`Form`, `Label`, `Button`, `TextBox`, `Panel`,
`CheckBox`, `RadioButton`, `ListBox`, `ComboBox`, `MenuBar`) +
layouts (`StackLayout`, `GridLayout`, `AbsoluteLayout`) +
theming (light/dark + OS detection) + HiDPI scaling.

Sits on top of [`amalgame-ui-sdl`](https://github.com/amalgame-lang/amalgame-ui-sdl)
for the platform layer.

> **Status: v0.0.1-dev — work in progress.** Public API is being designed.

## Install

```bash
amc package add github.com/amalgame-lang/amalgame-ui-forms@v0.0.1-dev
```

Pulls in `amalgame-ui-sdl` transitively. Requires **amc 0.8.0+**
and the SDL2 dev headers on the host (see `amalgame-ui-sdl`'s
README for OS-specific package names).

## Surface (planned for v0.1.0)

```amalgame
import Amalgame.UI.Forms

class Program {
    public static void Main() {
        let form: Form = new Form("Hello", 320, 200)
        let label: Label = new Label("Welcome!")
        let button: Button = new Button("Close")
        button.OnClick = (e) => { form.Close() }

        let stack: StackLayout = new StackLayout(StackOrientation.Vertical)
        stack.Add(label)
        stack.Add(button)
        form.SetLayout(stack)

        Application.Run(form)
    }
}
```

## Scope (v0.1.0 target)

### Widgets
- `Form` — top-level window
- `Label` — read-only text
- `Button` — clickable button with `OnClick` handler
- `TextBox` — single-line text input
- `Panel` — container
- `CheckBox`, `RadioButton`
- `ListBox`, `ComboBox`
- `MenuBar`

### Layouts
- `StackLayout` (vertical / horizontal)
- `GridLayout` (rows × cols)
- `AbsoluteLayout` (X/Y/W/H)

### Theming
- `Theme` class with `Background`, `Text`, `Accent`, `Border`, etc.
- `Theme.Light()` / `Theme.Dark()` presets
- `Theme.FromOS()` — picks Light or Dark based on the host's
  current appearance setting (uses `amalgame-ui-sdl`'s detector)

### Application lifecycle
- `Application.Run(rootForm)` blocking event loop
- `Application.SetTheme(theme)`
- `Application.Quit()`

## Events

All widgets follow the same event-handler-in-property pattern:

```amalgame
button.OnClick     = (e) => { ... }
textBox.OnChanged  = (e) => { ... }
form.OnClosing     = (e) => { ... }
```

Handlers are closures, leveraging Amalgame v0.3.4+ capturing
lambdas. Setting a handler to `null` removes it.

## Tests

```bash
./tests/run_tests.sh /path/to/amc
```

## License

Apache-2.0 — see `LICENSE`. Transitively depends on SDL2
(Zlib-licensed) via `amalgame-ui-sdl`.
