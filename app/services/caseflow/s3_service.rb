# frozen_string_literal: true
require "aws-sdk"

# Thin interface to all things Amazon S3
module Caseflow
  class S3Service
    def self.store_file(filename, content_or_filepath, type = :content, bucket:)
      init!

      content = type == :content ? content_or_filepath : File.open(content_or_filepath, "rb")

      @client.put_object(acl: "private",
                         bucket: bucket || default_bucket,
                         key: filename,
                         body: content,
                         server_side_encryption: "AES256")
    end

    def self.fetch_file(filename, dest_filepath, bucket:)
      init!

      @client.get_object(
        response_target: dest_filepath,
        bucket: bucket || default_bucket,
        key: filename
      )
    end

    def self.fetch_content(filename, bucket:)
      init!

      @client.get_object(
        bucket: bucket || default_bucket,
        key: filename
      ).body.read
    rescue Aws::S3::Errors::NoSuchKey
      nil
    end

    def self.init!
      return if @client

      Aws.config.update(region: "us-gov-west-1")

      @client = Aws::S3::Client.new
    end

    def self.default_bucket
      Rails.application.config.s3_bucket_name
    end
  end
end
