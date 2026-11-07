# frozen_string_literal: true

module CosmosysCadPreview
  # Resource bounds for the upstream server-configured converter.
  # This does not isolate the converter from the application's filesystem.
  module DwgConverterPolicy
    AVAILABILITY_TIMEOUT = 5
    CONVERSION_TIMEOUT = 120

    def timeout
      value = RedmineCadPreview.settings['conversion_timeout'].to_i
      value = RedmineCadPreview::DEFAULT_SETTINGS.fetch('conversion_timeout').to_i unless value.positive?
      [value, CONVERSION_TIMEOUT].min
    end

    def available?
      @available ||= {}
      return @available[command] if @available.key?(command)

      # The upstream runner rescues this timeout and terminates its process group.
      status = Timeout.timeout(AVAILABILITY_TIMEOUT, Timeout::Error) do
        run(command_arguments + ['--version'], 'DWG converter availability')
      end
      @available[command] = !!status&.success?
    rescue Timeout::Error, SystemCallError, IOError
      @available[command] = false
    end
  end
end
