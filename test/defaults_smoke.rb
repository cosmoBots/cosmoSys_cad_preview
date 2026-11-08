# Disposable Redmine laboratory only: all settings writes are rolled back.
require 'rack/test'

def assert_defaults(condition, message)
  raise message unless condition
end

admin = User.active.find_by!(admin: true)
ApplicationController.prepend(Module.new do
  define_method(:find_current_user) { admin }
  # This HTTP fixture represents an administrator who has already confirmed
  # sudo mode. It never changes the application's real authentication policy.
  define_method(:sudo_timestamp_valid?) { true }
end)
begin
  Setting.transaction do
    assert_defaults(!Redmine::Plugin.find(:cosmosys_cad_preview).configurable?, 'duplicate integration settings still exposed')
    # Simulate a row left by the removed registration. Redmine correctly no
    # longer accepts this name for new configuration writes.
    obsolete = Setting.find_or_initialize_by(name: 'plugin_cosmosys_cad_preview')
    obsolete.value = {'material_mode'=>'matte', 'lighting'=>'studio'}
    obsolete.save!(validate: false)
    attachment = Attachment.new(filename: 'defaults.glb')
    [%w[original original], %w[matte studio]].each do |material, lighting|
      Setting.plugin_redmine_cad_preview = Setting.plugin_redmine_cad_preview.merge('material_mode'=>material, 'lighting'=>lighting)
      Setting.clear_cache
      assert_defaults(RedmineCadPreview::ViewerOptions.for(attachment) == {'material_mode'=>material, 'lighting'=>lighting}, 'integration overrides upstream defaults')
    end
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.get('/settings/plugin/redmine_cad_preview')
    html = Nokogiri::HTML(session.response.body)
    assert_defaults(session.response.status == 200 && html.at_css('select[name="settings[material_mode]"]') && html.at_css('select[name="settings[lighting]"]'), 'upstream settings unavailable')
    session.get('/settings/plugin/cosmosys_cad_preview')
    assert_defaults(session.response.status == 404, 'obsolete settings endpoint still available')
    raise ActiveRecord::Rollback
  end
  puts 'CAD defaults PASS: upstream owns defaults, stale integration settings ignored, duplicate page removed'
ensure
  Setting.clear_cache
end
