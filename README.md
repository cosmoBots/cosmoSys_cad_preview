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

Use names to show the same attachment independently in several places:

```text
{{cad_preview(123, view=front, height=420)}}
{{cad_preview(123, view=detail, height=420)}}
```

Each attachment + view name has its own camera, PNG, lock and revision.
The toolbar identifies the active view. Saving/restoring affects only that
name; repeating the same name elsewhere deliberately shares that view.
Names are case-sensitive, 1–64 ASCII letters/digits/hyphens/underscores,
starting with a letter or digit. `default` (or no `view=`) selects the legacy
view, preserving existing captures without migration. A new name starts empty,
never falls back to the default view. `view` and `height` may appear in either
order; duplicate or unknown options are rejected. Links retain the view name.

The macro embeds the existing viewer in a lazy-loaded, same-origin iframe,
without Redmine navigation. It checks attachment visibility before emitting
the frame, and the frame and file routes independently enforce permissions.
Missing, inaccessible or unsupported attachments produce a generic macro error.
Only numeric attachment IDs are supported, not arbitrary URLs or filenames.
The embedded viewer does not save automatic thumbnail snapshots.

## Saved report view (3D models and 2D drawings)

The embedded and full attachment viewers offer **Save view for reports** to
users allowed to edit the attachment. It saves camera position/target/up,
perspective or orthographic projection, zoom/frustum, viewport aspect, material,
lighting, wireframe and background together with a PNG capture (maximum 1600 px
per side). DXF/DWG drawings save scene center, view width and viewport aspect
instead of a 3D camera. The original model and its automatic thumbnail are never replaced.

Captures render with a transparent background and crop to nontransparent pixel
bounds before optional downscaling. No background color is subtracted: white
surfaces remain intact. Image dimensions are independent of the saved viewport
aspect, which is still used when restoring the interactive view. Empty captures
are rejected. Existing figures are preserved; save again to replace an old
full-window image with a transparent cropped capture.

**Return to report view** restores the saved camera and appearance; exploring
the model does not change the figure. The saved view is applied on opening.
The viewport preserves the saved aspect ratio rather than stretching its frame.
Buttons show pressed, busy/spinner, success and error feedback, with accessible
status announcements. Save/restore buttons are rendered in the initial HTML,
disabled until the model loads, and remain visible with an explicit error if
loading fails. The compact iframe removes Redmine's desktop minimum width;
its toolbar stays sticky while scrolling.
Read-only users can restore/explore but cannot save. Concurrent edits conflict
instead of silently overwriting the other user's view; reload before retrying.

In cosmoSys HTML reports and ODT/DOCX/PDF exports, the macro renders the saved
PNG directly, without loading WebGL or requiring a server-side browser. If no
view exists, a notice and link are shown, not an invented camera. Captures are
explicit editorial content, not a cache. Views are keyed by attachment and name.

Storage: `files/cosmosys_cad_report_views/<attachment_id>.json`, with camera and
base64 PNG in a single atomically replaced file for the default view; named
views use `<attachment_id>.<view>.json`. Include this directory in
Redmine files backups. No database migration is required. A model digest/size
change invalidates its views, and deleting the attachment removes all its view records.
The save endpoint checks CSRF, edit permission, camera values, PNG format/size,
and optimistic revision. Image payloads are filtered from request logs.
PNG validation uses ImageMagick already provided by cosmoSys.

Limits: proprietary thumbnail-only formats do not save a view; DWG still needs
the optional converter (not installed in 3001). Snapshot/copy transfer and ID rewriting of
these macros remain future work: transferring a project currently requires
recreating its editorial views. This does not extend standalone Redmine wiki
PDF export; the static figure path is the cosmoSys report exporter.
