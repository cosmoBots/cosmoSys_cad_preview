# frozen_string_literal: true

require 'redmine'
require_relative 'lib/cosmosys_cad_preview/report_macro_patch'

Redmine::Plugin.register :cosmosys_cad_preview do
  name 'cosmoSys CAD Preview integration'
  author 'cosmoBots.eu'
  description 'Reports and CAD model controls for cosmoSys.'
  version '0.1.8'
  url 'https://github.com/cosmoBots/cosmoSys_cad_preview'
  author_url 'https://cosmobots.eu'
  requires_redmine version_or_higher: '7.0.1'
  requires_redmine_plugin :cosmosys, version_or_higher: '0.2.8'
end

# The dependency sorts after this plugin. Register only after all plugins load.
class CosmosysCadPreviewListener < Redmine::Hook::Listener
  def after_plugins_loaded(_context = {})
    # Reject unadapted releases before installing patches or accessing their APIs.
    CosmosysCadPreview::UpstreamCompatibility.verify!(Redmine::Plugin.find(:redmine_cad_preview).version)
    Redmine::Plugin.find(:cosmosys_cad_preview).requires_redmine_plugin(
      :redmine_cad_preview, version: '1.3.0'
    )
    macro_api = RedmineCadPreview::Macro.singleton_class
    macro_api.prepend CosmosysCadPreview::ReportMacroPatch unless macro_api < CosmosysCadPreview::ReportMacroPatch
    converter = RedmineCadPreview::DwgConverter.singleton_class
    converter.prepend CosmosysCadPreview::DwgConverterPolicy unless converter < CosmosysCadPreview::DwgConverterPolicy
    Cosmosys::MaterializationReferenceRewriter.register(:cad_preview) do |text, attachment_id_map|
      CosmosysCadPreview::AttachmentMacroRewriter.call(text, attachment_id_map)
    end
  end
end
