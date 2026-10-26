# PlatformIO-Builder
### Automatically finds and builds PlatformIO firmware environments in your project. 

## 1. Download the script
| OS | File |
|---|---|
| Windows | build-firmwares.ps1 |
|Linux | build-firmwares.sh |

## 2. Make the script executable (Linux only)
Open a terminal in the project folder and run:
chmod +x build-firmwares.sh

## 3. Run the script
Windows (PowerShell):
```powershell
.\build-firmwares.ps1
```
Linux:
```sh
./build-firmwares.sh
```

## 4. Select the builds you need
The script will list all available PlatformIO environments found in your project.

Filter the list to show only the projects you want to build.
Check (tick) the specific environment(s) you need.
Click "Build" and watch the terminal output for progress and errors.
## 5. Find your firmware files
After a successful build, the .bin / .hex firmware files are saved in the project root (the same folder as build-firmwares.ps1 / build-firmwares.sh).

Each file is named after its environment (e.g. mega2560.bin, esp32dev.bin).
