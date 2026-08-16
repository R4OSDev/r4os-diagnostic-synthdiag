SYNTHD.R4X
==========

SYNTHD.R4X ist die Synth-, SID-, MIDI- und OPL3-Diagnose.

Projektstruktur seit 0.51.21:
- `build.zig` baut die Diagnose als eigenes SDK-Projekt.
- `build.zig.zon` bindet `r4os_sdk` als Paket.
- `module.R4MF` beschreibt Artefakt, Zielpfad, R4L-Imports und Contract.

Build:

    cd Code\System\Diagnostics\SynthDiag
    ..\..\..\DevTools\Zig\zig.exe build

Ergebnis:

    Code\System\Diagnostics\SynthDiag\zig-out\SYNTHD.R4X

Contract:
- Build-Profil: `Zig/R4XStart`
- R4XStart-Entry: `synthd_main`
- App-Klasse: `console`
- R4L-Imports: `R4SYS`, `R4AUDIO`, `R4DEV`
- Zielpfad im Image: `C:\R4OS\SOFTWARE\TERMINAL\DIAG\SYNTHD.R4X`
