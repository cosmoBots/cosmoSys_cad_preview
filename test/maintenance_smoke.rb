# frozen_string_literal: true

# Run with rails runner in an isolated Redmine laboratory, never a live instance.
require 'rack/test'
require 'tempfile'
require 'securerandom'

def check!(condition, message)
  raise "CAD maintenance regression: #{message}" unless condition
end

admin = User.active.find_by!(admin: true)
previous_user, previous_autologin = User.current, Setting.autologin
original_settings = Setting.plugin_redmine_cad_preview.deep_dup
project = nil
paths = []
User.current = admin
begin
  check!(Attachment < CosmosysCadPreview::AttachmentPatch, 'cleanup patch not installed')
  2.times { CosmosysCadPreviewListener.instance.after_plugins_loaded }
  callbacks = Attachment._commit_callbacks.count { |c| c.filter == :cosmosys_cad_remove_report_view }
  check!(callbacks == 1, 'cleanup callback missing or duplicated')
  upstream = Redmine::Plugin.find(:redmine_cad_preview)
  original_version = upstream.version
  begin
    upstream.version '1.2.0'
    rejected = false
    begin
      CosmosysCadPreviewListener.instance.after_plugins_loaded
    rescue Redmine::PluginRequirementError => error
      rejected = error.message.include?('1.0.1-cosmobots.1')
    end
    check!(rejected, 'unadapted upstream version did not fail with a dependency error')
  ensure
    upstream.version original_version
  end
  Setting.plugin_redmine_cad_preview = original_settings.merge('dwg2dxf_command' => 'ruby -e arbitrary_code')
  check!(RedmineCadPreview::DwgConverter.command == '/usr/local/bin/dwg2dxf', 'web command still active')
  partial = Redmine::Plugin.find(:redmine_cad_preview).settings[:partial]
  settings_html = ApplicationController.render(partial: partial)
  check!(!settings_html.include?('settings[dwg2dxf_command]'), 'editable command field remains')
  check!(settings_html.include?('/usr/local/bin/dwg2dxf'), 'server policy not displayed')

  suffix = SecureRandom.hex(4)
  project = Project.create!(name: "CAD maintenance #{suffix}", identifier: "cad-maint-#{suffix}", cscode: "CM#{suffix}")
  tracker = Tracker.find_by!(csys_item_kind: 'info')
  project.trackers = project.trackers.to_a | [tracker]
  issue = Issue.create!(project: project, tracker: tracker, status: tracker.default_status, author: admin, subject: 'Attachment layout regression')
  Setting.autologin = 365 if Setting.autologin.to_i.zero?
  session = ActionDispatch::Integration::Session.new(Rails.application)
  session.host!('www.example.com')
  session.cookies['autologin'] = admin.generate_autologin_token
  attachments = []
  ['notes.txt', 'example.rb', 'pixel.png'].each do |filename|
    Tempfile.create(['cad-maintenance', File.extname(filename)]) do |file|
      if filename.end_with?('.png')
        png, error, status = Open3.capture3('/usr/bin/magick', '-size', '2x2', 'xc:white', 'png:-', binmode: true)
        check!(status.success?, error)
        file.binmode
        file.write(png)
      else
        file.write("# attachment regression\nputs 'example'\n")
      end
      file.flush
      upload = Rack::Test::UploadedFile.new(file.path, filename.end_with?('.png') ? 'image/png' : 'text/plain', original_filename: filename)
      attachment = Attachment.create!(container: issue, author: admin, file: upload)
      attachments << attachment
      session.get("/attachments/#{attachment.id}")
      html = Nokogiri::HTML(session.response.body)
      check!(session.response.status == 200, "#{filename} HTTP response")
      check!(html.at_css('#top-menu') && html.at_css('.attachments'), "#{filename} lost standard attachment layout")
    end
  end

  removed, retained = attachments.first(2)
  [removed, retained].each do |attachment|
    [nil, 'front'].each do |view|
      path = CosmosysCadPreview::ReportView.path(attachment, view: view)
      FileUtils.mkdir_p(File.dirname(path))
      [path, "#{path}.lock"].each { |entry| File.write(entry, '{}'); paths << entry }
    end
  end
  removed.destroy!
  paths.each do |path|
    belongs_to_removed = File.basename(path).start_with?("#{removed.id}.")
    check!(File.exist?(path) != belongs_to_removed, "incorrect cleanup: #{File.basename(path)}")
  end
  puts 'CAD maintenance PASS: idempotent registration, server command policy, normal attachment layouts, committed deletion of views/locks without affecting another attachment'
ensure
  project&.destroy!
  FileUtils.rm_f(paths)
  Setting.plugin_redmine_cad_preview = original_settings
  Setting.autologin = previous_autologin
  User.current = previous_user
end
