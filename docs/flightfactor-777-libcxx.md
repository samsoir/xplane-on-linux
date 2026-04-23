# FlightFactor 777-200ER — libc++ preload workaround

The FlightFactor 777-200ER's `stsff_aircraft_performance_lua` module ships with its own bundled copy of `libc++.so.1` and `libc++abi.so.1` — the LLVM C++ runtime — inside the aircraft folder. It's compiled against that specific ABI.

On some Linux distributions, the system-installed `libc++` is either missing, a different major version, or gets resolved ahead of the bundled copy at `dlopen()` time. The plugin then fails to load or X-Plane crashes shortly after the aircraft is selected.

The fix is to `LD_PRELOAD` the bundled libraries before launching X-Plane, which forces the dynamic linker to use the exact versions the plugin expects.

## Symptoms

Any of the following, typically when loading or flying the FF 777:

- X-Plane crashes on aircraft load.
- The aircraft loads but panels/systems misbehave and `Log.txt` shows errors from `stsff_aircraft_performance_lua`.
- Missing-symbol errors in `Log.txt` referencing `libc++` / `libc++abi` or mangled C++ symbols.
- Works fine on one distro and breaks on another with no other changes.

## The script

[`scripts/run_X-Plane-12.sh`](../scripts/run_X-Plane-12.sh) is a thin wrapper:

```bash
#!/usr/bin/env bash

bundle="./Aircraft/FlightFactor777_200ER/modules/cpp-libs/stsff_aircraft_performance_lua/bundle"

LD_PRELOAD="${bundle}/libc++abi.so.1:${bundle}/libc++.so.1" exec "$@"
```

It sets `LD_PRELOAD` to the two bundled libraries (colon-separated — order matters: `libc++abi` before `libc++`) and `exec`s whatever command was passed in, replacing the shell in the process tree.

## Installation

Copy the script into the X-Plane root (the directory containing `X-Plane-x86_64`):

```sh
cp scripts/run_X-Plane-12.sh "/path/to/X-Plane 12/"
chmod +x "/path/to/X-Plane 12/run_X-Plane-12.sh"
```

Then launch via the wrapper instead of running `X-Plane-x86_64` directly:

```sh
cd "/path/to/X-Plane 12"
./run_X-Plane-12.sh ./X-Plane-x86_64
```

Any additional arguments you normally pass to X-Plane can be appended — `exec "$@"` forwards everything.

## Notes and caveats

- **Path assumptions.** The script uses relative paths (`./Aircraft/...`), so it only works when invoked with the X-Plane root as the current working directory. Launching it via an absolute path from elsewhere will silently drop the preload.
- **FF 777 must be installed.** If the `bundle` directory doesn't exist the linker will warn about missing `LD_PRELOAD` entries but still launch — so absence of the aircraft is non-fatal, just noisy.
- **Scope.** Only affects this one aircraft. If another payware aircraft has the same issue, either extend the `LD_PRELOAD` list or make a dedicated wrapper.
- **Version bumps.** If FlightFactor ship a new 777 variant (e.g. a 777-300ER module) with its own bundle path, the script will need updating to match.
- **Desktop integration.** If you launch X-Plane from a `.desktop` file or Steam, point the launcher's `Exec=` / launch command at this script instead of `X-Plane-x86_64`.
