describe Fastlane do
  describe Fastlane::Helper::CreateXcframeworkHelper do
    describe 'Helper Test Suite' do
      let(:product_name) { 'iOSModule' }
      let(:framework_index) { 0 }
      let(:xc_output) { 'test' }

      it 'verifies product_name method' do
        params = { product_name: product_name }
        result = described_class.new(params).product_name
        expect(result).to eq(product_name)
      end

      it 'verifies that scheme can be used instead of the product_name' do
        params = { scheme: product_name }
        result = described_class.new(params).product_name
        expect(result).to eq(product_name)
      end

      it 'verifies xcframework method' do
        params = { scheme: product_name }
        result = described_class.new(params).xcframework
        expect(result).to eq("#{product_name}.xcframework")
      end

      it 'verifies framework method' do
        params = { scheme: product_name }
        result = described_class.new(params).framework
        expect(result).to eq("#{product_name}.framework")
      end

      it 'verifies xcframework_output_directory' do
        params = { xcframework_output_directory: xc_output }
        result = described_class.new(params).output_directory
        expect(result).to eq(xc_output)
      end

      it 'verifies empty xcframework_output_directory' do
        params = { xcframework_output_directory: '' }
        result = described_class.new(params).output_directory
        expect(result).to eq('')
      end

      it 'verifies xcarchive_path method' do
        params = { scheme: product_name, xcframework_output_directory: xc_output }
        result = described_class.new(params).xcarchive_path
        expect(result).to eq("#{xc_output}/archives")
      end

      it 'verifies xcarchive_path_for_destination method' do
        params = { scheme: product_name }
        helper = described_class.new(params)
        xcarchive_path = helper.xcarchive_path
        result = helper.xcarchive_path_for_destination(framework_index)
        expect(result).to eq("#{xcarchive_path}/#{framework_index}_#{product_name}.xcarchive")
      end

      it 'verifies xcarchive_framework_path method' do
        params = { scheme: product_name }
        helper = described_class.new(params)
        framework = helper.framework
        xcarchive_path_for_destination = helper.xcarchive_path_for_destination(framework_index)
        framework_path = "#{xcarchive_path_for_destination}/Products/Library/Frameworks/#{framework}"

        allow(File).to receive(:exist?).with(framework_path).and_return(true)
        result = helper.xcarchive_framework_path(framework_index)
        expect(result).to eq(framework_path)
      end

      it 'verifies xcarchive_framework_path method error message' do
        err = "▸ PRODUCT_NAME was misdefined: `#{product_name}`. Please, provide :product_name option"
        params = { scheme: product_name }
        expect do
          described_class.new(params).xcarchive_framework_path(framework_index)
        end.to raise_error(err)
      end

      it 'verifies xcarchive_frameworks_path method' do
        params = { scheme: product_name, destinations: ['iOS', 'macOS'] }
        helper = described_class.new(params)
        framework = helper.framework

        expected_result = params[:destinations].each_with_index.map do |_, i|
          xcarchive_path_for_destination = helper.xcarchive_path_for_destination(i)
          framework_path = "#{xcarchive_path_for_destination}/Products/Library/Frameworks/#{framework}"
          allow(File).to receive(:exist?).with(framework_path).and_return(true)
          helper.xcarchive_framework_path(i)
        end

        result = helper.xcarchive_frameworks_path
        expect(result).to eq(expected_result)
      end

      it 'verifies xcarchive_dSYMs_path method' do
        params = { scheme: product_name }
        helper = described_class.new(params)
        expected_result = "#{helper.xcarchive_path_for_destination(framework_index)}/dSYMS"
        allow(File).to receive(:expand_path).and_return(expected_result)
        result = helper.xcarchive_dSYMs_path(framework_index)
        expect(result).to eq(expected_result)
      end

      it 'verifies xcframework_dSYMs_path method' do
        params = { scheme: product_name, xcframework_output_directory: xc_output }
        helper = described_class.new(params)
        output_directory = helper.output_directory
        expected_result = "#{output_directory}/#{product_name}.dSYMs"
        allow(File).to receive(:expand_path).and_return(expected_result)
        result = helper.xcframework_dSYMs_path
        expect(result).to eq(expected_result)
      end

      it 'verifies xcarchive_BCSymbolMaps_path method' do
        params = { scheme: product_name }
        helper = described_class.new(params)
        expected_result = "#{helper.xcarchive_path_for_destination(framework_index)}/BCSymbolMaps"
        allow(File).to receive(:expand_path).and_return(expected_result)
        result = helper.xcarchive_BCSymbolMaps_path(framework_index)
        expect(result).to eq(expected_result)
      end

      it 'verifies xcframework_BCSymbolMaps_path method' do
        params = { scheme: product_name, xcframework_output_directory: xc_output }
        helper = described_class.new(params)
        output_directory = helper.output_directory
        expected_result = "#{output_directory}/#{product_name}.BCSymbolMaps"
        allow(File).to receive(:expand_path).and_return(expected_result)
        result = helper.xcframework_BCSymbolMaps_path
        expect(result).to eq(expected_result)
      end

      it 'verifies xcframework_path method' do
        params = { scheme: product_name, xcframework_output_directory: xc_output }
        helper = described_class.new(params)
        output_directory = helper.output_directory
        xcframework = helper.xcframework
        expected_result = "#{output_directory}/#{xcframework}"
        allow(File).to receive(:expand_path).and_return(expected_result)
        result = helper.xcframework_path
        expect(result).to eq(expected_result)
      end

      it 'verifies library_identifier method' do
        params = { scheme: product_name, xcframework_output_directory: xc_output }
        expected_result = 'path/to/library.framework'
        allow(Dir).to receive(:chdir).and_return([expected_result])
        allow(FileUtils).to receive(:compare_file).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
        result = described_class.new(params).library_identifier(framework_index)
        expect(result).to eq(expected_result)
      end

      it 'verifies library_identifier method error message' do
        allow(Dir).to receive(:chdir).and_return(['path/to/library.framework'])
        allow(FileUtils).to receive(:compare_file).and_return(false)
        allow(File).to receive(:exist?).and_return(true)

        params = { scheme: product_name, xcframework_output_directory: xc_output }
        helper = described_class.new(params)
        xcframework_path = helper.xcframework_path
        framework_path = helper.xcarchive_framework_path(framework_index)
        err = "Error: #{xcframework_path} doesn't contain #{framework_path}"
        expect { helper.library_identifier(framework_index) }.to raise_error(err)
      end
    end
  end
end
