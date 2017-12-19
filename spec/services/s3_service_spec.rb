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
end
