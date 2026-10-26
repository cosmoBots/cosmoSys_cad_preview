# frozen_string_literal: true

Redmine::WikiFormatting::Macros.register do
  desc 'Embed a readable CAD attachment. Example: {{cad_preview(123, height=520)}}'
  macro :cad_preview do |_object, args|
    id, *options = args.map { |arg| arg.to_s.strip }
    height_option = options.first.to_s
    unless id.to_s.match?(/\A[1-9]\d*\z/) && options.size <= 1 &&
           (options.empty? || height_option.match?(/\Aheight=\d+\z/))
      raise l(:text_cosmosys_cad_macro_usage)
    end
    height = options.empty? ? 520 : height_option.delete_prefix('height=').to_i
    raise l(:text_cosmosys_cad_macro_usage) unless (240..1200).cover?(height)

    attachment = Attachment.find_by(id: id)
    unless attachment && attachment.visible?(User.current) && RedmineCadPreview.previewable?(attachment)
      raise l(:text_cosmosys_cad_macro_unavailable)
    end

    viewer_url = url_for(controller: 'cosmosys_cad_embeds', action: 'show', id: attachment.id, only_path: true)
    attachment_url = attachment_path(attachment)
    content_tag(:div, class: 'cosmosys-cad-embed') do
      safe_join([
        content_tag(:iframe, '', src: viewer_url, title: attachment.filename,
                    width: '100%', height: height, loading: 'lazy',
                    allow: 'fullscreen', style: 'border: 1px solid #dee2e6; max-width: 100%;'),
        content_tag(:p, link_to(attachment.filename, attachment_url))
      ])
    end
  end
end
