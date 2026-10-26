# frozen_string_literal: true

# Reuse the upstream attachment authorization and viewer, with a compact layout.
class CosmosysCadEmbedsController < CadPreviewsController
  def show
    @cad_format = RedmineCadPreview.format_of(@attachment.filename)
    @cad_image = RedmineCadPreview::PreviewImage.extract(@attachment)
    @cad_snapshot = false # Reading an embedded view must not save a thumbnail.
    prepend_view_path File.expand_path('../views/cosmosys_cad_embeds', __dir__)
    render template: 'attachments/cad_preview', layout: 'cosmosys_cad_embed'
  end
end
