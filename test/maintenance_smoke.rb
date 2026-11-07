# frozen_string_literal: true

# Disposable laboratory only: fixture writes and HTTP export checks.
require 'rack/test'
require 'tempfile'
require 'securerandom'
require 'open3'
require 'zip'

def check!(condition, message)
  raise "CAD upstream integration: #{message}" unless condition
end

admin = User.active.find_by!(admin: true)
previous_user = User.current
paths = []
User.current = admin
ApplicationController.prepend(Module.new do
  define_method(:find_current_user) { request.headers['X-Cad-Anonymous'] ? User.anonymous : admin }
end)
begin
  check!(Redmine::Plugin.find(:redmine_cad_preview).version == '1.3.0', 'wrong upstream')
  check!(RedmineCadPreview::Macro.singleton_class < CosmosysCadPreview::ReportMacroPatch, 'report patch missing')
  check!(!defined?(CosmosysCadPreview::ReportView), 'obsolete JSON store loaded')
  2.times { CosmosysCadPreviewListener.instance.after_plugins_loaded }
  check!(RedmineCadPreview::Macro.singleton_class.ancestors.count(CosmosysCadPreview::ReportMacroPatch) == 1, 'patch duplicated')
  png, error, status = Open3.capture3('/usr/bin/magick', '-size', '16x16', 'xc:white', 'png:-', binmode: true)
  check!(status.success?, error)
  Project.transaction do
    suffix = SecureRandom.hex(4)
    project = Project.create!(name: "CAD upstream #{suffix}", identifier: "cad-upstream-#{suffix}", cscode: "CU#{suffix}", is_public: false)
    tracker = Tracker.find_by!(csys_item_kind: 'info')
    project.trackers = project.trackers.to_a | [tracker]
    issue = Issue.create!(project: project, tracker: tracker, status: tracker.default_status, author: admin, subject: 'CAD integration')
    attachment = nil
    Tempfile.create(['cad-upstream', '.stl']) do |file|
      file.write("solid triangle\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\nvertex 1 0 0\nvertex 0 1 0\nendloop\nendfacet\nendsolid triangle\n")
      file.flush
      attachment = Attachment.create!(container: issue, author: admin, file: Rack::Test::UploadedFile.new(file.path, 'application/octet-stream'))
    end
    paths << attachment.diskfile
    state = {version: 1, projection: 'perspective', position: [2,2,2], target: [0,0,0], up: [0,1,0],
      near: 0.01, far: 1000, zoom: 1, fov: 45, frustum_height: 1, aspect: 1,
      material: 'original', lighting: 'studio', background: '#ffffff', wireframe: false}.stringify_keys
    front = RedmineCadPreview::Views.save(attachment, 'Front', user: admin, state: state, image: png)
    detail = RedmineCadPreview::Views.save(attachment, 'Detail', user: admin, state: state, image: png)
    check!(front.persisted? && detail.persisted?, 'upstream view save failed')
    paths.concat([front.image.diskfile, detail.image.diskfile])
    check!(RedmineCadPreview::Views.find(attachment, 'FRONT').id == front.id, 'name normalization failed')
    check!(RedmineCadPreview::Views.default(attachment).id == front.id, 'default missing')
    conflict = false
    begin
      RedmineCadPreview::Views.save(attachment, 'front', user: admin, revision: front.revision + 5, state: state, image: png)
    rescue RedmineCadPreview::Views::Conflict
      conflict = true
    end
    check!(conflict && detail.reload.state == state, 'conflict/named isolation failed')
    check!(!front.image.visible?(User.anonymous), 'private PNG exposed')
    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.host!('www.example.com')
    issue.reload.update!(description: "{{cad_preview(#{attachment.id}, view=front)}}\n\n{{cad_preview(#{attachment.id}, view=detail, readonly)}}")
    session.get("/issues/#{issue.id}")
    html = Nokogiri::HTML(session.response.body)
    check!(session.response.status == 200 && html.css('[data-cad-preview]').size == 2, 'inline macro failed')
    check!(html.css('iframe').empty? && !html.at_css('#cad-report-tools'), 'obsolete iframe/toolbar remains')
    check!(html.css('[data-cad-preview]').last.at_css('[data-cad-action="save-view"]').nil?, 'readonly offers saving')
    check!(html.css('[data-cad-preview]').first.at_css('[data-cad-action="save-view"]'), 'ordinary viewer lost saving')
    issue.reload.update!(description: "{{cad_preview(#{attachment.id}, view=front, png, height=180)}} {{cad_preview(#{attachment.id}, view=detail, png, height=180)}}")
    session.get("/issues/#{issue.id}")
    png_html = Nokogiri::HTML(session.response.body)
    check!(png_html.css('.cad-preview-figure img').size == 2, 'PNG-only macro lost images')
    check!(png_html.css('[data-cad-preview], iframe').empty?, 'PNG-only macro started viewers')
    check!(png_html.css('link[rel="stylesheet"]').any? { |link| link['href'].include?('redmine_cad_preview/cad_preview') }, 'PNG-only page lacks inline figure stylesheet')
    session.get("/attachments/#{attachment.id}")
    check!(session.response.status == 200 && Nokogiri::HTML(session.response.body).at_css('#top-menu'), 'attachment layout broken')
    session.get("/cad_previews/#{attachment.id}/views.json", headers: {'X-Cad-Anonymous' => '1'})
    check!([302,401,403,404].include?(session.response.status), 'private views exposed')
    session.get("/#{project.identifier}/cosmosys/report")
    report = Nokogiri::HTML(session.response.body)
    check!(session.response.status == 200, 'report failed')
    figures = report.css('img[src^="data:image/png;base64,"]').select { |img| img['alt'].to_s.include?(attachment.filename) }
    check!(figures.size == 2 && figures.map { |img| img['alt'] }.uniq.size == 2, 'report lost named figures')
    %w[odt docx pdf].each do |format|
      token = report.at_css('meta[name="csrf-token"]')['content']
      session.post("/#{project.identifier}/cosmosys/report/export", params: {format: format, authenticity_token: token})
      check!(session.response.status == 200, "#{format} HTTP failure")
      if format == 'pdf'
        check!(session.response.body.start_with?('%PDF-'), 'missing PDF')
      else
        Zip::File.open_buffer(session.response.body) do |zip|
          check!(zip.entries.any? { |entry| entry.name.match?(%r{\A(?:Pictures|word/media)/}) && !entry.directory? }, "#{format} lost PNG")
        end
      end
    end
    front.update_columns(attachment_digest: 'stale')
    session.get("/#{project.identifier}/cosmosys/report")
    stale_report = Nokogiri::HTML(session.response.body)
    check!(!stale_report.css('img').any? { |img| img['alt'] == "#{attachment.filename} (front)" }, 'stale figure silently reused')
    front.destroy!
    check!(RedmineCadPreview::Views.find(attachment, 'detail').id == detail.id, 'deletion affected another view')
    raise ActiveRecord::Rollback
  end
  puts 'CAD upstream integration PASS: inline/readonly, named/default views, revision conflict, PNG permissions, stale detection, ODT/DOCX/PDF'
ensure
  User.current = previous_user
  FileUtils.rm_f(paths)
end
