# Edgeneon

An animated neon glow along the edges of your Mac's screen.

The macOS menu bar is transparent, so a window placed *underneath* it shows
right through — the colors appear behind the clock and the menus with nothing
covering them. The same window extends past the menu bar and fades out, and
three more windows do the left, right and bottom edges. They all sit behind
your normal windows and ignore the mouse, so nothing is covered and nothing is
in the way.

Run it with no arguments and it stays lit. Give it `--duration` and it fades in,
glows, fades out and exits — which makes it a one-liner for build hooks, test
runners and long-running jobs.

## Install

Requires macOS.

Try it without installing anything:

```sh
nix run github:kawarimidoll/edgeneon -- --duration 10
```

Install it as an ordinary command:

```sh
nix profile install github:kawarimidoll/edgeneon
```

Or declare it as a flake input:

```nix
inputs.edgeneon.url = "github:kawarimidoll/edgeneon";
```

and add the package where your setup keeps them — nix-darwin:

```nix
environment.systemPackages = [ inputs.edgeneon.packages.${pkgs.system}.default ];
```

home-manager:

```nix
home.packages = [ inputs.edgeneon.packages.${pkgs.system}.default ];
```

Without nix — one file, no dependencies, put the binary anywhere on `PATH`:

```sh
git clone https://github.com/kawarimidoll/edgeneon
cd edgeneon
swiftc -O main.swift -o edgeneon
install -m755 edgeneon ~/.local/bin/
```

## Keeping it running

Nothing is needed for the `--duration` uses above; this is only for leaving the
glow on. Start it in the background with `edgeneon &`, or wire it as a login
agent — home-manager:

```nix
launchd.agents.edgeneon = {
  enable = true;
  config = {
    ProgramArguments = [ "${inputs.edgeneon.packages.${pkgs.system}.default}/bin/edgeneon" ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};
```

## Usage

```
usage: edgeneon [options]
  --colors <hex,...>  gradient colors (default: rainbow)
  --duration <sec>    how long to glow. 0 stays until killed (default: 0)
  --width <px>        how far the glow spills from the screen edge (default: 30)
  --saturation <0-1>  rainbow saturation. lower is more pastel (default: 0.45)
  --cycle <sec>       seconds for the colors to travel one full loop (default: 8)
  --blur <px>         how soft the glow is (default: 6)
  --opacity <0-1>     overall strength (default: 1)
  --fade <sec>        fade in and out time (default: 0.4)
  --version           print the version
  --help              print this help
```

`--colors` takes any number of `#rrggbb` values and blends between them. One
color gives a steady glow, two or more scroll around the screen. `--saturation`
only shapes the built-in rainbow; explicit colors are used exactly as given.

```sh
edgeneon                                    # rainbow, stays until killed
edgeneon --colors 22c55e --duration 3       # green for 3 seconds
edgeneon --colors eb3583,dddccc             # crimson and white
edgeneon --colors 8de0cd,bcc7e4,f699f2      # mint, lavender and pink
```

## Using it as a hook

```sh
make test && edgeneon --colors 22c55e --duration 3 \
          || edgeneon --colors ef4444,f97316 --duration 5
```

Instances stack on purpose: a permanent rainbow can keep running while a hook
flashes a color over it.

With nix you do not need a config file for presets — a wrapper script is the
preset, and it lands on `PATH` so callers that never touch your shell can use
it too:

```nix
let neon = "${inputs.edgeneon.packages.${pkgs.system}.default}/bin/edgeneon";
in {
  home.packages = [
    (pkgs.writeShellScriptBin "neon-ok"    "exec ${neon} --colors 22c55e,86efac --duration 3")
    (pkgs.writeShellScriptBin "neon-error" "exec ${neon} --colors ef4444,f97316 --duration 5")
  ];
}
```

## Stopping it

| Started with   | Stop with                                 |
| -------------- | ----------------------------------------- |
| the foreground | `Ctrl+C`                                  |
| `edgeneon &`   | `pkill edgeneon`                          |
| a launchd agent | `launchctl bootout gui/$UID/<agent label>` |

## Notes

- The four edge glows sit at window level `-1`: behind every normal window, in
  front of the desktop. They never cover anything you are working on.
- The menu bar band is a separate window above the menu bar, blended into it
  with `colorBlendMode` — it takes the color and leaves the luminance, so the
  menu titles, the Apple logo and the status items stay just as legible. It has
  to be above: a notched display paints its menu bar opaquely and nothing
  underneath shows through. That costs nothing, because the band covers only
  the menu bar strip, where no ordinary window may go.
- Because the band recolors rather than paints, how strong it looks depends on
  your desktop picture. A flat white or black wallpaper takes less color than a
  mid-tone one.
- Each edge loops its own gradient, so colors do not line up at the corners.

## Development

```sh
./test.sh            # build main.swift and smoke-test the CLI
nix build .#default  # build the way a release does, version and all
```

## License

[MIT](LICENSE)
