# frozen_string_literal: true

require 'minitest/autorun'
module Redmine
  class PluginRequirementError < StandardError; end
end
require_relative '../lib/cosmosys_cad_preview/upstream_compatibility'

class UpstreamCompatibilityTest < Minitest::Test
  def test_accepts_only_the_validated_fork_version
    assert CosmosysCadPreview::UpstreamCompatibility.verify!('1.0.1-cosmobots.1')
  end

  def test_rejects_modern_upstream_and_other_unvalidated_builds
    %w[1.0.0 1.0.1 1.0.1-cosmobots.2 1.1.0 1.1.1 1.2.0 2.0.0].each do |version|
      error = assert_raises(Redmine::PluginRequirementError) do
        CosmosysCadPreview::UpstreamCompatibility.verify!(version)
      end
      assert_includes error.message, version
      assert_includes error.message, '1.0.1-cosmobots.1'
    end
  end
end
