# frozen_string_literal: true

require 'redmine'
require_relative 'config/macros_registration'

Redmine::Plugin.register :cosmosys_cad_preview do
  name 'cosmoSys CAD Preview integration'
  author 'cosmoBots.eu'
  description 'CAD viewer defaults for cosmoSys; requires the cosmoBots CAD Preview fork.'
  version '0.1.0-dirty'
  url 'https://github.com/cosmoBots/cosmoSys_cad_preview'
  author_url 'https://cosmobots.eu'
  requires_redmine version_or_higher: '7.0.1'
  requires_redmine_plugin :cosmosys, version_or_higher: '0.2.0'
  settings default: { 'material_mode' => 'original', 'lighting' => 'studio' },
           partial: 'settings/cosmosys_cad_preview'
end

# The dependency sorts after this plugin. Register only after all plugins load.
class CosmosysCadPreviewListener < Redmine::Hook::Listener
  def after_plugins_loaded(_context = {})
    Redmine::Plugin.find(:cosmosys_cad_preview).requires_redmine_plugin(
      :redmine_cad_preview, version_or_higher: '1.0.1-cosmobots.1'
    )
    RedmineCadPreview::ViewerOptions.register(:cosmosys) do |_attachment|
      Setting.plugin_cosmosys_cad_preview.slice('material_mode', 'lighting')
    end
  end
end
