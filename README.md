# cosmoSys CAD Preview integration

Development version: `0.1.0-dirty`. Redmine 7.0.1+, cosmoSys 0.2.0+ and
the cosmoBots fork of Redmine CAD Preview `1.0.1-cosmobots.1` or newer.

This plugin supplies initial material and lighting options through the fork's
generic viewer-options provider. It does not duplicate its JavaScript viewer,
change source models or add migrations. Configure it under Administration →
Plugins → cosmoSys CAD Preview integration. Individual viewers can switch
between Original/Matte material and Original/Studio lighting without changing
the instance defaults or the uploaded file.

The fork lives at https://github.com/cosmoBots/redmine_cad_preview and retains
the upstream MIT license and attribution. Studio reflections and matte material
controls are generic features of that fork, not patches in this plugin.

## Interactive wiki and item macro

Use `{{cad_preview(123)}}`, where 123 is the attachment ID, in an item
description or wiki page. Optional height: `{{cad_preview(123, height=520)}}`
(240–1200 pixels; default 520). Width follows the available space.

The macro embeds the existing viewer in a lazy-loaded, same-origin iframe,
without Redmine navigation. It checks attachment visibility before emitting
the frame, and the frame and file routes independently enforce permissions.
Missing, inaccessible or unsupported attachments produce a generic macro error.
Only numeric attachment IDs are supported, not arbitrary URLs or filenames.
The embedded viewer does not save automatic thumbnail snapshots.

Saved editorial cameras and static report figures remain future work. This
macro is interactive HTML, not a figure for PDF/ODT export. The attachment link
below it also lets the reader open the full viewer.
