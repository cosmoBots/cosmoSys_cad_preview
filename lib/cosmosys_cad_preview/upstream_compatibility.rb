# frozen_string_literal: true

module CosmosysCadPreview
  module UpstreamCompatibility
    SUPPORTED_VERSION = '1.3.0'
    module_function

    def verify!(version)
      return true if version == SUPPORTED_VERSION

      raise Redmine::PluginRequirementError,
        "cosmosys_cad_preview requires redmine_cad_preview #{SUPPORTED_VERSION}; " \
        "found #{version}. This integration uses the upstream saved-view and macro APIs."
    end
  end
end
