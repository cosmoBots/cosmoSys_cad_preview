# frozen_string_literal: true

require 'base64'
require 'json'
require 'fileutils'
require 'securerandom'
require 'open3'

module CosmosysCadPreview
  # Editorial content, not a thumbnail cache. Included in Redmine files backups.
  # A single atomic JSON file commits camera and PNG together.
  module ReportView
    MAX_BODY = 6.megabytes
    class Invalid < StandardError; end
    class Conflict < StandardError; end
    module_function

    def view_name(value = nil)
      name = value.nil? ? 'default' : value
      raise Invalid unless name.is_a?(String) && name.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}\z/)
      name
    end

    def path(attachment, view: nil)
      name = view_name(view)
      filename = name == 'default' ? "#{attachment.id}.json" : "#{attachment.id}.#{name}.json"
      File.join(Attachment.storage_path, 'cosmosys_cad_report_views', filename)
    end

    def delete_all(attachment)
      default = path(attachment)
      FileUtils.rm_f([default] + Dir.glob(File.join(File.dirname(default), "#{attachment.id}.*.json")))
    end

    def read(attachment, view: nil)
      data = JSON.parse(File.binread(path(attachment, view: view)))
      data if data['digest'] == attachment.digest && data['filesize'] == attachment.filesize
    rescue Errno::ENOENT, JSON::ParserError
      nil
    end

    def validate_state!(state)
      raise Invalid unless state.is_a?(Hash) && state['version'] == 1
      if state['projection'] == 'drawing'
        raise Invalid unless state['center'].is_a?(Array) && state['center'].size == 2 &&
          state['center'].all? { |n| number?(n) && n.abs <= 1e15 }
        raise Invalid unless number?(state['view_width']) && (0.0..1e18).cover?(state['view_width']) && state['view_width'].positive?
        raise Invalid unless number?(state['aspect']) && (0.1..10).cover?(state['aspect'])
        return state.slice('version', 'projection', 'center', 'view_width', 'aspect')
      end
      raise Invalid unless %w[perspective orthographic].include?(state['projection'])
      %w[position target up].each do |key|
        vector = state[key]
        raise Invalid unless vector.is_a?(Array) && vector.size == 3 && vector.all? { |n| number?(n) && n.abs <= 1e15 }
      end
      %w[near far zoom fov frustum_height aspect].each do |key|
        raise Invalid unless number?(state[key]) && state[key].positive?
      end
      raise Invalid unless state['near'] < state['far'] && state['far'] <= 1e18 && state['frustum_height'] <= 1e18
      raise Invalid unless (1..120).cover?(state['fov']) && (0.01..100).cover?(state['zoom'])
      raise Invalid unless (0.1..10).cover?(state['aspect'])
      raise Invalid unless state['up'].sum { |n| n * n }.positive? && state['position'] != state['target']
      raise Invalid unless %w[original matte].include?(state['material']) && %w[original studio].include?(state['lighting'])
      raise Invalid unless state['background'].is_a?(String) && state['background'].match?(/\A#[0-9a-f]{6}\z/i)
      raise Invalid unless [true, false].include?(state['wireframe'])
      state.slice('version', 'projection', 'position', 'target', 'up', 'near', 'far', 'zoom',
                  'fov', 'frustum_height', 'aspect', 'material', 'lighting', 'background', 'wireframe')
    end

    def number?(value)
      value.is_a?(Numeric) && value.finite?
    end

    def validate_image!(value, state)
      raise Invalid unless value.is_a?(String) && value.start_with?('data:image/png;base64,') && value.bytesize <= MAX_BODY
      bytes = Base64.strict_decode64(value.delete_prefix('data:image/png;base64,'))
      raise Invalid unless bytes.start_with?("\x89PNG\r\n\x1a\n".b) && bytes.bytesize >= 33 && bytes.byteslice(12, 4) == 'IHDR'
      width, height = bytes.byteslice(16, 8).unpack('NN')
      raise Invalid unless (1..1600).cover?(width) && (1..1600).cover?(height)
      # The saved viewport aspect restores the camera; the cropped figure has
      # its own dimensions and must not be forced back to that viewport ratio.
      output, _error, status = Open3.capture3('/usr/bin/magick', 'identify', '-limit', 'memory', '32MiB',
        '-limit', 'map', '64MiB', '-limit', 'time', '5', '-regard-warnings', '-format', '%m %w %h', 'png:-', stdin_data: bytes, binmode: true)
      raise Invalid unless status.success? && output == "PNG #{width} #{height}"
      [Base64.strict_encode64(bytes), width, height]
    rescue ArgumentError
      raise Invalid
    end

    def save!(attachment, payload, user, view: nil)
      name = view_name(view)
      state = validate_state!(payload['state'])
      image, width, height = validate_image!(payload['cad_report_image'], state)
      destination = path(attachment, view: name)
      FileUtils.mkdir_p(File.dirname(destination))
      File.open("#{destination}.lock", File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        current = read(attachment, view: name)
        raise Conflict unless current&.fetch('revision') == payload['revision']
        data = { 'view' => name, 'state' => state, 'png' => image, 'width' => width, 'height' => height,
                 'revision' => SecureRandom.uuid, 'digest' => attachment.digest, 'filesize' => attachment.filesize,
                 'author_id' => user.id, 'saved_at' => Time.now.utc.iso8601 }
        temporary = "#{destination}.#{SecureRandom.hex(8)}.tmp"
        begin
          File.open(temporary, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(JSON.generate(data)) }
          File.rename(temporary, destination)
        ensure
          FileUtils.rm_f(temporary) if temporary
        end
        data
      end
    end
  end
end
