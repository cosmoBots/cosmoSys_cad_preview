# frozen_string_literal: true

Redmine::WikiFormatting::Macros.register do
  desc 'Embed a CAD attachment. Example: {{cad_preview(123, view=front, height=520)}}'
  macro :cad_preview do |_object, args|
    id, *options = args.map { |arg| arg.to_s.strip }
    parsed = {}
    unless id.to_s.match?(/\A[1-9]\d*\z/) && options.size <= 2 && options.all? { |option|
      key, value = option.split('=', 2)
      valid = %w[height view].include?(key) && value.present? && !parsed.key?(key)
      parsed[key] = value if valid
      valid
    }
      raise l(:text_cosmosys_cad_macro_usage)
    end
    raise l(:text_cosmosys_cad_macro_usage) if parsed['height'] && !parsed['height'].match?(/\A\d+\z/)
    height = parsed.fetch('height', '520').to_i
    raise l(:text_cosmosys_cad_macro_usage) unless (240..1200).cover?(height)
    begin
      view_name = CosmosysCadPreview::ReportView.view_name(parsed['view'])
    rescue CosmosysCadPreview::ReportView::Invalid
      raise l(:text_cosmosys_cad_macro_usage)
    end

    attachment = Attachment.find_by(id: id)
    unless attachment && attachment.visible?(User.current) && RedmineCadPreview.previewable?(attachment)
      raise l(:text_cosmosys_cad_macro_unavailable)
    end

    view_params = view_name == 'default' ? {} : { view: view_name }
    viewer_url = url_for(controller: '/cosmosys_cad_embeds', action: 'show', id: attachment.id, only_path: true, **view_params)
    attachment_url = view_name == 'default' ? attachment_path(attachment) : viewer_url
    title = view_name == 'default' ? attachment.filename : "#{attachment.filename} — #{view_name}"
    if controller.is_a?(Cosmosys::ItemsController) && %w[report report_export].include?(controller.action_name)
      saved = CosmosysCadPreview::ReportView.read(attachment, view: view_name)
      next saved ? image_tag("data:image/png;base64,#{saved.fetch('png')}", alt: title,
                             width: saved.fetch('width'), height: saved.fetch('height')) :
        content_tag(:p, safe_join([l(:text_cosmosys_cad_view_missing), ' ', link_to(title, viewer_url)]))
    end
    content_tag(:div, class: 'cosmosys-cad-embed') do
      safe_join([
        content_tag(:iframe, '', src: viewer_url, title: title,
                    width: '100%', height: height, loading: 'lazy',
                    allow: 'fullscreen', style: 'border: 1px solid #dee2e6; max-width: 100%; scroll-margin-top: 64px;'),
        content_tag(:p, link_to(title, attachment_url))
      ])
    end
  end
end
