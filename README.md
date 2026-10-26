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

Saved editorial views, wiki macros and static report figures remain future
work. This first implementation only covers viewer appearance integration.
