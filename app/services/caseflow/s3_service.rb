# frozen_string_literal: true
require "aws-sdk"

# Thin interface to all things Amazon S3
module Caseflow
  class S3Service
    def self.exists?(key)
      init!
      @bucket.object(key).exists?
    end

    def self.store_file(filename, content_or_filepath, type = :content)
      init!

      # Always create and destroy a temp file.
      tempfile = Tempfile.new(filename)
      begin
        # If the calling code does not pass the type argument then we expect the second argument
        # will be file contents. Write those contents to a tempfile and upload that temp file.
        filepath = content_or_filepath
        if type == :content
          tempfile.write(content_or_filepath)
          tempfile.rewind
          filepath = tempfile.path
        end
        @bucket.object(filename).upload_file(filepath, acl: "private", server_side_encryption: "AES256")
      ensure
        tempfile.close!
      end
    end

    def self.fetch_file(filename, dest_filepath)
      init!

      @bucket.object(filename).download_file(dest_filepath)
    end

    def self.fetch_content(filename)
      init!

      tempfile = Tempfile.new(filename)
      begin
        @bucket.object(filename).download_file(tempfile.path)
        tempfile.read
      ensure
        tempfile.close!
      end
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def self.stream_content(key)
      init!

      return unless exists?(key)

      # When you pass a block to #get_object, chunks of data are yielded as they are read off the socket.
      Enumerator.new do |y|
        @client.get_object(
          bucket: bucket_name,
          key: key
        ) do |segment|
          y << segment
        end
      end
    end

    def self.init!
      return if @bucket

      Aws.config.update(region: "us-gov-west-1")

      @client = Aws::S3::Client.new
      @resource = Aws::S3::Resource.new(client: @client)
      @bucket = @resource.bucket(bucket_name)
    end

    def self.bucket_name
      Rails.application.config.s3_bucket_name
    end
  end
end
