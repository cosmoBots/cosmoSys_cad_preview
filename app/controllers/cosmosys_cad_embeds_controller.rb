# frozen_string_literal: true

# Reuse the upstream attachment authorization and viewer, with a compact layout.
class CosmosysCadEmbedsController < CadPreviewsController
  before_action :find_report_view_name
  before_action :authorize_view_edit, only: :save_view

  def view
    data = CosmosysCadPreview::ReportView.read(@attachment, view: @cad_report_view_name)
    response.headers['Cache-Control'] = 'no-store'
    render json: data ? data.except('png', 'digest', 'filesize').merge('view' => @cad_report_view_name) :
      { state: nil, revision: nil, view: @cad_report_view_name }
  end

  def save_view
    format = RedmineCadPreview.format_of(@attachment.filename)
    return head :unprocessable_content if RedmineCadPreview::IMAGE_FORMATS.include?(format)
    body = request.body.read(CosmosysCadPreview::ReportView::MAX_BODY + 1)
    return head :payload_too_large if body.bytesize > CosmosysCadPreview::ReportView::MAX_BODY
    payload = JSON.parse(body)
    raise CosmosysCadPreview::ReportView::Invalid unless payload.is_a?(Hash)
    drawing = %w[dxf dwg].include?(format)
    raise CosmosysCadPreview::ReportView::Invalid unless payload['state'].is_a?(Hash) &&
      (payload['state']['projection'] == 'drawing') == drawing
    data = CosmosysCadPreview::ReportView.save!(@attachment, payload, User.current, view: @cad_report_view_name)
    response.headers['Cache-Control'] = 'no-store'
    render json: data.except('png', 'digest', 'filesize')
  rescue JSON::ParserError, CosmosysCadPreview::ReportView::Invalid
    head :unprocessable_content
  rescue CosmosysCadPreview::ReportView::Conflict
    head :conflict
  end

  def show
    response.headers['Cache-Control'] = 'no-store'
    @cad_format = RedmineCadPreview.format_of(@attachment.filename)
    @cad_image = RedmineCadPreview::PreviewImage.extract(@attachment)
    @cad_snapshot = false # Reading an embedded view must not save a thumbnail.
    prepend_view_path File.expand_path('../views/cosmosys_cad_embeds', __dir__)
    render template: 'attachments/cad_preview', layout: 'cosmosys_cad_embed'
  end

  private

  def find_report_view_name
    @cad_report_view_name = CosmosysCadPreview::ReportView.view_name(request.query_parameters['view'])
  rescue CosmosysCadPreview::ReportView::Invalid
    head :unprocessable_content
  end

  def authorize_view_edit
    @attachment.editable? ? true : deny_access
  end
end
