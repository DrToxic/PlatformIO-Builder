# PlatformIO-Builder

Select and build ESP32 and nRF52 environments from an existing PlatformIO project.
These are helper scripts, not a firmware project: copy the appropriate script into
your project root beside `platformio.ini`. Install [PlatformIO Core](https://docs.platformio.org/en/latest/core/installation/index.html) first.

## Linux / Bash

Requires Bash 4+ and Python 3. PlatformIO is found in `.venv/bin/pio` or on `PATH`;
use `--pio PATH` (or `PIO`) to select another executable.

```bash
chmod +x build-firmwares.sh
./build-firmwares.sh                         # searchable numbered selector
./build-firmwares.sh --search LoRaFish       # filter by environment name
./build-firmwares.sh --env YOUR_ENV          # repeat --env for several targets
./build-firmwares.sh --all --search LoRaFish # build all matching targets
```

The terminal selector accepts numbers, comma-separated ranges, `all`, `search`, or `q`.

## Windows / PowerShell

```powershell
.\build-firmwares.ps1
```

Uses Windows Forms with search, checkboxes, **Select Visible**, and **Build Selected**.
PlatformIO is discovered in the project `.venv`, the user PlatformIO environment,
on `PATH`, or via `py -m platformio`. The script checks for `platformio.ini` and
reports missing tools. The published `build-firmwares.ps1` is the current source
script named `builds.ps1`, retained under this repository's established filename.

## Build behavior and outputs

Both scripts group selected targets into one ESP32 batch followed by one nRF52
batch; nRF52 uses the project's `create_uf2` target (which the project must provide).
Bash uses `-j 1`. Successful batches copy firmware to the project root, named for
the environment: Bash copies `ENV.bin` for ESP32 and `ENV.uf2` for nRF52;
PowerShell copies available `.bin` / `.uf2` artifacts. Existing same-named output
files are overwritten, so check build errors before using any prior output.

## Verification

The current Bash script passed `bash -n` and the existing isolated mock-PlatformIO
test on Linux: batch ordering/arguments, artifact copying, failure handling,
invalid environments/options, search selection, and empty matches. No actual
firmware compilation was performed for this publication. Windows GUI/runtime
and Fedora-specific behavior have not been tested; mock tests are not hardware
or cross-platform acceptance.
