# amalgame-ui-forms

> ## ⚠️ Sunset — 2026-05-15
>
> **`amalgame-ui-forms` is no longer the recommended GUI toolkit for
> Amalgame apps.** Replace it with [`amalgame-ui-web`](https://github.com/amalgame-lang/amalgame-ui-web)
> v0.0.3+ — a webview-based binding that renders HTML/CSS/JS in the
> OS-native engine (WebView2 / WKWebView / WebKitGTK) with an AM-side
> `Element` / `Page` builder and JS ↔ AM IPC via `Window.Bind`.
>
> The decision matrix that drove the pivot lives in [`docs/proposals/amalgame-ui-web.md`](https://github.com/amalgame-lang/Amalgame/blob/main/docs/proposals/amalgame-ui-web.md)
> in the main repo. TL;DR: SDL retained-mode means re-implementing every
> widget by hand (rounded corners, native fonts, OS theming, HiDPI, …)
> with zero leverage from the OS — webview gets all of that for free.
>
> v0.1.4 stays on the packages-index for existing consumers; no further
> releases are planned. Existing apps keep working — this is a "stop
> investing here", not a "your code breaks". Migration guide TBD when a
> first consumer needs it.

---

Cross-platform retained-mode **Forms toolkit** for
[Amalgame](https://github.com/amalgame-lang/Amalgame).
Widgets (`Form`, `Label`, `Button`, `TextBox`, `Panel`,
`CheckBox`, `RadioButton`, `ListBox`, `ComboBox`, `MenuBar`) +
layouts (`StackLayout`, `GridLayout`, `AbsoluteLayout`) +
theming (light/dark + OS detection) + HiDPI scaling.

Sits on top of [`amalgame-ui-sdl`](https://github.com/amalgame-lang/amalgame-ui-sdl)
for the platform layer.

> **Status: v0.1.4 — sunset.** No further development. Use `amalgame-ui-web`.

## Prerequisites

Same as [`amalgame-ui-sdl`](https://github.com/amalgame-lang/amalgame-ui-sdl#prerequisites)
(SDL2 + SDL2_ttf), since this package pulls ui-sdl as a
transitive dep:

| OS / distro | Command |
|---|---|
| Debian / Ubuntu | `sudo apt install libsdl2-dev libsdl2-ttf-dev` |
| Fedora / RHEL | `sudo dnf install SDL2-devel SDL2_ttf-devel` |
| Arch / Manjaro | `sudo pacman -S sdl2 sdl2_ttf` |
| macOS (Homebrew) | `brew install sdl2 sdl2_ttf` |
| Windows (MSYS2) | `pacman -S mingw-w64-x86_64-SDL2 mingw-w64-x86_64-SDL2_ttf` |

Full per-OS detail (deploy-time, SDL3 opt-in, static link variants)
in the [ui-sdl README](https://github.com/amalgame-lang/amalgame-ui-sdl#prerequisites).

## Install

```bash
amc package add github.com/amalgame-lang/amalgame-ui-forms@v0.0.1-dev
```

Pulls in `amalgame-ui-sdl` transitively. Requires **amc 0.8.0+**.

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
