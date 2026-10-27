# frozen_string_literal: true

module CosmosysCadPreview
  module AttachmentPatch
    def self.included(base)
      base.after_destroy_commit :cosmosys_cad_remove_report_view
    end

    private

    def cosmosys_cad_remove_report_view
      FileUtils.rm_f(CosmosysCadPreview::ReportView.path(self))
    end
  end
end
