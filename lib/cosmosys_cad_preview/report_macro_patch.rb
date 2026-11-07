# frozen_string_literal: true

require 'base64'

module CosmosysCadPreview
  # Upstream owns parsing, lookup, authorization and the interactive macro.
  # Only cosmoSys reports need flat, self-contained images for image grouping
  # and the server-side ODT/DOCX/PDF pipeline.
  module ReportMacroPatch
    def render(view, object, args, **options)
      super(view, object, args, **options.merge(static: options[:static] || cosmosys_report?(view)))
    end

    private

    def cosmosys_report?(view)
      controller = view.controller
      controller.is_a?(Cosmosys::ItemsController) && %w[report report_export].include?(controller.action_name)
    end

    def render_images(view, attachment, views, height, static)
      unless cosmosys_report?(view)
        images = super
        # Upstream loads its stylesheet with interactive viewers, but a PNG-only
        # HTML page also needs the inline figure rules. Do not load WebGL or add
        # stylesheet links to email/native static exports.
        return images if static || view.instance_variable_get(:@cad_preview_assets) ||
          view.instance_variable_get(:@cosmosys_cad_png_styles)

        view.instance_variable_set(:@cosmosys_cad_png_styles, true)
        return view.safe_join([view.stylesheet_link_tag('cad_preview', plugin: 'redmine_cad_preview'), images])
      end

      view.safe_join(views.map do |saved|
        if !saved || saved.stale? || !saved.image&.visible?(User.current) || !File.file?(saved.image.diskfile)
          message = saved&.stale? ? :text_cad_preview_view_stale : :text_cad_preview_no_views
          next view.content_tag(:p, view.safe_join([
            I18n.t(message), ' ', view.link_to(attachment.filename, view.attachment_path(attachment))
          ]))
        end
        png = File.binread(saved.image.diskfile)
        width, image_height = CadPreviewView.png_dimensions(png)
        view.image_tag("data:image/png;base64,#{Base64.strict_encode64(png)}",
          alt: "#{attachment.filename} (#{saved.name})", width: width, height: image_height,
          style: ("max-height: #{height}px" if height))
      end)
    end
  end
end
