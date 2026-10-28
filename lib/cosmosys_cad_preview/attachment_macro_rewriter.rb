# frozen_string_literal: true

module CosmosysCadPreview
  module AttachmentMacroRewriter
    module_function

    def call(text, attachment_id_map)
      text.gsub(/(\{\{cad_preview\(\s*)([1-9]\d*)(\s*(?:,[^{}]*?)?\)\}\})/) do |macro|
        prefix, id, suffix = Regexp.last_match.captures
        target = attachment_id_map[id.to_i]
        target ? "#{prefix}#{target}#{suffix}" : macro
      end
    end
  end
end
