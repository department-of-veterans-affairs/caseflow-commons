# frozen_string_literal: true
module Caseflow
  class Fakes::S3Service
    cattr_accessor :files

    def self.store_file(filename, content, _type = :content, _bucket:)
      self.files ||= {}
      self.files[filename] = content
    end

    def self.fetch_file(filename, dest_filepath, _bucket:)
      self.files ||= {}
      File.open(dest_filepath, "wb") do |f|
        f.write(files[filename])
      end
    end

    def self.fetch_content(filename, _bucket:)
      self.files ||= {}
      self.files[filename]
    end
  end
end
