# frozen_string_literal: true

module CosmosysCadPreview
  module UpstreamCompatibility
    SUPPORTED_VERSION = '1.0.1-cosmobots.1'
    module_function

    def verify!(version)
      return true if version == SUPPORTED_VERSION

      raise Redmine::PluginRequirementError,
        "cosmosys_cad_preview requires redmine_cad_preview #{SUPPORTED_VERSION}; " \
        "found #{version}. Newer upstream saved-view/macro APIs are not integrated yet."
    end
  end
end
