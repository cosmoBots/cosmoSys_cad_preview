# frozen_string_literal: true

require 'redmine'
require_relative 'config/macros_registration'
Rails.application.config.filter_parameters << :cad_report_image

Redmine::Plugin.register :cosmosys_cad_preview do
  name 'cosmoSys CAD Preview integration'
  author 'cosmoBots.eu'
  description 'CAD viewer defaults for cosmoSys; requires the cosmoBots CAD Preview fork.'
  version '0.1.2'
  url 'https://github.com/cosmoBots/cosmoSys_cad_preview'
  author_url 'https://cosmobots.eu'
  requires_redmine version_or_higher: '7.0.1'
  requires_redmine_plugin :cosmosys, version_or_higher: '0.2.7'
  settings default: { 'material_mode' => 'original', 'lighting' => 'studio' },
           partial: 'settings/cosmosys_cad_preview'
end

# The dependency sorts after this plugin. Register only after all plugins load.
class CosmosysCadPreviewListener < Redmine::Hook::Listener
  def after_plugins_loaded(_context = {})
    Cosmosys::MaterializationReferenceRewriter.register(:cad_preview) do |text, attachment_id_map|
      CosmosysCadPreview::AttachmentMacroRewriter.call(text, attachment_id_map)
    end
    Redmine::Plugin.find(:cosmosys_cad_preview).requires_redmine_plugin(
      :redmine_cad_preview, version_or_higher: '1.0.1-cosmobots.1'
    )
    RedmineCadPreview::ViewerOptions.register(:cosmosys) do |_attachment|
      Setting.plugin_cosmosys_cad_preview.slice('material_mode', 'lighting')
    end
  end
end

class CosmosysCadPreviewViewListener < Redmine::Hook::ViewListener
  render_on :view_layouts_base_body_bottom, partial: 'cosmosys_cad_embeds/report_tools'
end

Rails.application.config.to_prepare do
  Attachment.include CosmosysCadPreview::AttachmentPatch unless Attachment < CosmosysCadPreview::AttachmentPatch
end
