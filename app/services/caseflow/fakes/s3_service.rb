# frozen_string_literal: true
module Caseflow
  class Fakes::S3Service
    cattr_accessor :files

    def self.store_file(filename, content, _type = :content)
      self.files ||= {}
      self.files[filename] = content
    end

    def self.fetch_file(filename, dest_filepath)
      self.files ||= {}
      File.open(dest_filepath, "wb") do |f|
        f.write(files[filename])
      end
    end

    def self.fetch_content(filename)
      self.files ||= {}
      self.files[filename]
    end

    def self.stream_content(_filename)
      Enumerator.new do |y|
        10.times do |i|
          y << "This is line #{i}\n"
        end
      end
    end
  end
end
