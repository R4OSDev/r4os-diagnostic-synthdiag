# SYNTHD.R4X

`SYNTHD.R4X` is an independent R4OS diagnostic program implemented in Zig.

## Package

- Version: `0.1.7`
- Image target: `/R4OS/SOFTWARE/TERMINAL/DIAG/SYNTHD.R4X`
- Image scope: `test`
- Canonical project manifest: `module.R4MF`

The manifest is the single source of truth for the artifact, imports, image
target, and package metadata.

SID Stop, SID Release and MIDI Close retry Busy for at most three seconds
with one-tick waits. The diagnostic prints and checks the actual final Stop and Release values. A
private SID acknowledgement alone is not a hardware/DMA completion receipt.
The real MIDI/OPL3/SID protocol selftests run before the strict active-role
checks, so a valid lazy R4P is activated by the first diagnosis. Missing roles,
failed activation, protocol errors and DSP failures still fail the diagnosis.

## Build

On Windows:

    Build.bat

On Linux:

    ./Build.sh

The build starters resolve the current local R4OS dependency checkouts through
`Settings.R4S`. The URL and hash entries in `build.zig.zon` record the
last verified standalone dependency identities; workspace builds use the
mapped local checkouts.

## Documentation

Detailed German technical notes from the migration are preserved in
`DOCUMENTATION.de.txt`. Source-transfer provenance is recorded in
`PROVENANCE.txt`.

## License

Original R4OS material is licensed under Apache License 2.0. See `LICENSE`
and `NOTICE`. Any repository-specific external material is documented in
`THIRD_PARTY_NOTICES.md`.
