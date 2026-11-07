# cosmoSys CAD Preview integration

Development version **0.1.7-dirty**. Redmine 7.0.1+, cosmoSys 0.2.8+ and
Redmine CAD Preview **1.3.0**, currently upstream commit `9679499`.
This is an integration candidate, not a tagged production release.

> **EXPERIMENTAL — opt-in:** Expect defects, incomplete features and breaking
> changes. This classification applies to our integration, not to upstream.

## Ownership and interoperability

[Redmine CAD Preview](https://github.com/flowalchs/redmine_cad_preview) owns the
`cad_preview` macro, inline/lazy viewers, named/default views, camera state,
transparent cropped PNG capture, permissions, revisions and database storage.
This plugin no longer registers that macro or provides its own iframe,
capture toolbar, JSON storage or view endpoints. Upstream retains its license
and attribution; the cosmoBots fork mirrors upstream without extra runtime code.

This integration retains:
- Static, self-contained figures for cosmoSys HTML and ODT/DOCX/PDF reports.
- Attachment-ID rewriting when cosmoSys materializes snapshots.
- Generic rigid-node motion controls used by Architecture and PORIS–CAD.
- Initial material/lighting defaults through the upstream ViewerOptions API.
- Bounded DWG converter availability and conversion time.

## Embedding and report figures

Use upstream syntax in item, document and wiki descriptions:

```text
{{cad_preview(123)}}
{{cad_preview(123, view=front, height=420)}}
{{cad_preview(model.glb, view=detail)}}
{{cad_preview(123, view=*, png)}}
{{cad_preview(123, readonly)}}
```

Names are normalized by upstream. Omitting `view=` selects its default view;
an explicit missing name is not replaced by another view. Save permissions are
managed by upstream roles (own attachments or all visible attachments).
`readonly` hides editorial editing controls, not access authorization.

`png` also works in ordinary HTML: put two macros on the same Markdown line to
show two static figures without loading viewers. The integration includes the
upstream figure stylesheet on PNG-only HTML pages too; interactive viewers are
not needed just to obtain that layout. Use `height=` to keep the pair compact.

In cosmoSys reports, the upstream parser and authorization still select the
attachment and view. We consume `RedmineCadPreview::Views` and embed its saved
PNG directly, preserving adjacent-image grouping without WebGL or a server-side
browser. Missing or stale saved figures produce a notice; exploration never
changes a saved figure. Upstream handles ordinary Redmine wiki PDF and email.

## Temporary models and motion controls

Architecture preflight and PORIS–CAD use the upstream partial with
`readonly: true` and no automatic thumbnail capture. They do not persist slider
poses. `model_controls.js` retains local/global translations and rotations,
limits/defaults, parent-first composition, explicit Euler orders and selection
of visible GLB nodes through `extras.cosmosys_cad_node_index`. Each update starts
from rest; the module does not know about items, PORIS or MQTT.

## DWG conversion

The executable is configured by upstream through Redmine's
`config/configuration.yml` (`dwg2dxf_command`) or the Redmine process PATH.
A legacy web setting cannot select an executable. This integration does not
override the server's command or duplicate the upstream settings page.

Availability has a five-second deadline; conversion timeout is configurable up
to 120 seconds. Timeout cleanup terminates and reaps the process group.
These bounds are not process isolation or a sandbox. CAD conversion remains
experimental. Deployment must verify its installed binary is reachable by the
Redmine execution user using the new configuration method.

## Storage and snapshots

New saved views and images belong to upstream's database table and Attachment
records; include the database and file store in backups. Run its migration and
assign the upstream save-view permissions before testing.

Experimental JSON views from earlier integration builds are not migrated or
deleted automatically. They are no longer read; recreate demo views as needed.
The existing backup remains available.

For snapshots, numeric attachment references in `cad_preview` are rewritten
using the core source-ID map, including cross-item/document/page references
inside the captured scope. Filenames use upstream's attachment lookup.
This does not yet preserve saved cameras/images or PORIS–CAD bindings across
project snapshots/copies; that remains separate experimental work.

## Validation

`npm test` checks the retained control module. Ruby tests in `test/` cover
compatibility and converter bounds. `test/maintenance_smoke.rb` exercises
upstream persistence, macro isolation, permissions and report exports in an
isolated Redmine laboratory, never against a live user's project.
