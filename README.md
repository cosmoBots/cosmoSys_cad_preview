# cosmoSys CAD Preview integration

Version **0.1.8-dirty**. Redmine 7.0.1+, cosmoSys 0.2.8+ and
Redmine CAD Preview **1.3.0**.

> **EXPERIMENTAL — opt-in:** Expect defects, incomplete features and breaking
> changes. This classification applies to our integration, not to upstream.

## Features

This plugin extends [Redmine CAD Preview](https://github.com/flowalchs/redmine_cad_preview)
with static figures for cosmoSys reports, attachment-reference remapping on
snapshot import, and motion controls for Architecture and PORIS integrations.
Embedding, saved views and view permissions are provided by Redmine CAD Preview.
That upstream project retains its own license and authorship.

Configure initial material and lighting under **Administration → Plugins →
Redmine CAD Preview → Configure**. This integration has no separate appearance
settings. Saved views retain their own material and lighting.

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
show two static figures without loading viewers. Use `height=` to keep the pair
compact. Reports embed the saved PNG; missing or stale figures produce a notice.
Exploring the viewer does not change a saved figure.

Architecture and PORIS–CAD controls move models temporarily. These poses are
not stored as report views.

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


For snapshots, numeric attachment references in `cad_preview` are rewritten
using the core source-ID map, including cross-item/document/page references
inside the captured scope. Filenames use upstream's attachment lookup.
This does not yet preserve saved cameras/images or PORIS–CAD bindings across
project snapshots/copies; that remains separate experimental work.
