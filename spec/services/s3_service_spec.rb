require "spec_helper"
require "pry"

describe Caseflow::S3Service do
  context "store_file" do
    let(:filename) { "somefilename.ext" }

    context "file as input argument" do
      let(:filepath) { "path/to/somefilename.ext" }
      let(:type) { "file" }

      it "passes input filename and path to upload function" do
        allow(Caseflow::S3Service).to receive(:upload_file_to_s3) do |name, path|
          expect(name).to eq(filename)
          expect(path).to eq(filepath)
        end

        expect(Caseflow::S3Service.store_file(filename, filepath, type)).to be_truthy
      end
    end

    context "content as input argument" do
      let(:content) { "some content" }

      it "passes input filename and temp path to upload function" do
        tempfile_path = nil

        allow(Caseflow::S3Service).to receive(:upload_file_to_s3) do |name, path|
          expect(name).to eq(filename)
          expect(path).to_not eq(content)

          tempfile_path = path
          expect(File.exist?(tempfile_path)).to eq(true)
        end

        expect(Caseflow::S3Service.store_file(filename, content)).to be_truthy
        expect(File.exist?(tempfile_path)).to eq(false)
      end

      it "cleans up the tempfile when it dies" do
        tempfile_path = nil

        allow(Caseflow::S3Service).to receive(:upload_file_to_s3) do |_, path|
          tempfile_path = path
          fail StandardError
        end

        expect { Caseflow::S3Service.store_file(filename, content) }.to raise_error(StandardError)
        expect(File.exist?(tempfile_path)).to eq(false)
      end
    end
  end

  context "live tests" do
    # Create and destroy an S3 bucket every time we run this test.
    before(:context) do
      aws_bucket.tap do |bucket|
        bucket.create
        fail "could not create bucket #{test_bucket_name}" unless bucket.exists?
      end
    end
    after(:context) do
      aws_bucket.tap do |bucket|
        bucket.delete!
        fail "could not delete bucket #{test_bucket_name}" if bucket.exists?
      end
    end

    before { aws_bucket.clear! }
    before { allow(Caseflow::S3Service).to receive(:bucket_name).and_return(test_bucket_name) }

    context "fetch_content" do
      let(:nonexistent_filename) { "nonexistent_filename" }
      it "returns nil for object not found in bucket" do
        expect(Caseflow::S3Service.fetch_content(nonexistent_filename)).to eq(nil)
      end
    end

    context "store_file" do
      let(:utf8_filename) { "object_from_content" }
      let(:utf8_content) { "maybe we got lost in translation" }
      it "uploads object to s3 from content" do
        expect(Caseflow::S3Service.store_file(utf8_filename, utf8_content)).to eq(true)
      end

      let(:ascii_8bit_filename) { "ascii_8bit_content" }
      let(:ascii_8bit_content) { "Buenos Días".force_encoding("ASCII-8BIT") }
      it "correctly handles ASCII-8BIT encoded content" do
        expect(Caseflow::S3Service.store_file(ascii_8bit_filename, ascii_8bit_content)).to eq(true)
      end
    end

    context "fetch_content" do
      let(:ascii_8bit_filename) { "ascii_8bit_content" }
      let(:ascii_8bit_content) { "Buenos Días".force_encoding("ASCII-8BIT") }
      it "correctly downloads object from S3 and respects content encoding" do
        # Upload the file that we expect to have non-utf8 encoded contents.
        Caseflow::S3Service.store_file(ascii_8bit_filename, ascii_8bit_content)
        expect(Caseflow::S3Service.fetch_content(ascii_8bit_filename)).to eq(ascii_8bit_content)
      end
    end
  end

  def aws_bucket
    @bucket ||= Aws::S3::Resource.new(client: Aws::S3::Client.new(region: "us-gov-west-1")).bucket(test_bucket_name)
  end

  def test_bucket_name
    @test_bucket_name ||= "dsva-appeals-s3-test-#{SecureRandom.uuid}"
  end
end
