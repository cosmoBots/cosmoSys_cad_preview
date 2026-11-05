# frozen_string_literal: true

module CosmosysCadPreview
  # Server policy, not a shell command supplied by a Redmine administrator.
  # This does not isolate the converter from the application's filesystem.
  module DwgConverterPolicy
    EXECUTABLE = '/usr/local/bin/dwg2dxf'
    AVAILABILITY_TIMEOUT = 5
    CONVERSION_TIMEOUT = 120

    def command
      EXECUTABLE
    end

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
        run([command, '--version'], 'DWG converter availability')
      end
      @available[command] = !!status&.success?
    rescue Timeout::Error, SystemCallError, IOError
      @available[command] = false
    end

    private

    def command_arguments
      [command]
    end
  end
end
