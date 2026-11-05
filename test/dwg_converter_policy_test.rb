# frozen_string_literal: true

require 'minitest/autorun'
require 'timeout'
require_relative '../lib/cosmosys_cad_preview/dwg_converter_policy'

module RedmineCadPreview
  def self.settings
    { 'dwg2dxf_command' => 'ruby -e arbitrary_code', 'conversion_timeout' => '99999' }
  end
end

class DwgConverterPolicyTest < Minitest::Test
  def converter
    Object.new.extend(CosmosysCadPreview::DwgConverterPolicy)
  end

  def test_web_command_is_not_consumed_and_timeout_is_bounded
    instance = converter
    assert_equal '/usr/local/bin/dwg2dxf', instance.command
    assert_equal ['/usr/local/bin/dwg2dxf'], instance.send(:command_arguments)
    assert_equal 120, instance.timeout
  end

  def test_availability_uses_fixed_argv_and_caches_result
    instance = converter
    calls = []
    instance.define_singleton_method(:run) do |args, _description|
      calls << args
      Struct.new(:success?).new(true)
    end
    2.times { assert instance.available? }
    assert_equal [['/usr/local/bin/dwg2dxf', '--version']], calls
  end

  def test_missing_binary_and_timeout_are_unavailable
    [Errno::ENOENT, Timeout::Error].each do |error|
      instance = converter
      instance.define_singleton_method(:run) { |*| raise error }
      refute instance.available?
    end
  end
end
