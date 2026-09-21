# OpenSC2K

An open-source remake of SimCity 2000, built with Godot.

## Objective

Build a working, playable, open-source remake of SimCity 2000 for Windows 95 in Godot.
Run the full simulation and provide every original player tool.
Match the supplied game as closely as practical.
Load and save cities that the supplied game can use.

## Working rules

- Use Godot 4 and typed GDScript unless a native module is necessary.
- Keep simulation state separate from display state.
- Preserve unknown save chunks and unknown bytes during a load-save cycle.
- Do not write to a supplied city or scenario file. Write tests to a temporary or generated path.
- Add an automated test for each implemented file-format rule or simulation rule when practical.
- Use deterministic pseudo-random state in the simulation. Save it when the original format permits this.
- Use computer-use automation for live Godot input and visual checks.
- Run Godot tests and live checks with the Dummy audio driver. Automated validation must not play sound.
- Use Simplified Technical English where practical.

## GDScript readability

- Write intentional integer quotients inline as `a / b`. GDScript integer
  division already truncates toward zero. Put
  `@warning_ignore_start("integer_division")` at file level, after the class
  doc comment, in each file that divides integers.
- Use blank lines between functions and between logical blocks within a function.
- Put control-flow bodies on separate indented lines.
- Preserve existing wrapping of calls, signatures, expressions, and data tables.
- Keep compact arrays and grouped arguments. Do not put each value or argument
  on its own line during a general readability pass.
- Prefer focused line breaks and blank lines.
- Keep related assignments together. Preserve behavior when formatting code.

## Validation gates

For code changes, use
`tools/validate_project.sh --suite <domain>` or explicit `--test <id>` entries.
The runner checks source diffs, Godot parsing, and project startup with Dummy audio.
Its diff check excludes documentation and Markdown.
Independent groups use half the logical CPUs, capped at eight workers by default.
Use `--jobs 1` for per-test performance measurements. Native windows run in one
sequential group alongside headless checks. Stateful pairs keep their order and
shared disposable preferences. Shared fixture preparation finishes first.
Use `--list` to review the selected coverage.

- Domains: `formats`, `simulation`, `tools`, `rendering`, `scurk`, `ui`, and `audio`.
- Run `routine` before merge. It retains functional product coverage.
- Run `full` for shared codec, city-model, grid, snapshot, or simulation changes.
  It includes product tests, reference audits, and populated-city soaks.
- Run `audit` for decoder, importer, resource mapping, palette, audit-tool, or
  reference-corpus changes. It retains the independent decoder comparisons.
- Run `native` for renderer or shader changes. Use computer-use automation for
  live input and visual review. Headless checks do not prove GPU pixel output.
- Run `release` before release. It includes full and native checks and rejects
  missing prerequisites or skipped coverage.
- Documentation-only changes do not require automated validation.

The `formats` core selection retains load and byte-exact round-trip checks for
all supplied cities and scenarios. The full aggregate retains every functional core case.
Cover each distinct rule, format, direction, and relevant map boundary. Avoid full
size/mode/rotation cross products when the tested rules are independent. Batch
compatible cases in one fixture and retain representative end-to-end checks.
Fixtures are explicit prerequisites; reuse requires matching input, engine, and
output hashes. Never overwrite an edited
fixture. Use disposable test preferences, not the normal game profile.

Aim for one or two seconds per focused test and less than five seconds when practical.
Investigate entries above ten seconds. Reduce repeated setup and independent parameter
combinations before removing functional cases. Do not split tests only to hide runtime.
Record slower retained cases and their purpose in the runtime cleanup report.

Do not validate documentation or markdown files.
Test functionality. Do not add assertions for fixed prose, cosmetic spacing,
border widths, font defaults, or editor node naming. Keep geometry checks for
input, picking, camera limits, and viewport fit.

A static check does not prove live compatibility with the Windows game.

## Commit rules

- Commit small, working changes often.
- Use a one-line commit message.
- Keep `references/` out of commits.
