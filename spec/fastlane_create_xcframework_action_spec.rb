describe Fastlane do
  describe Fastlane::Actions::CreateXcframeworkAction do
    describe 'Action Test Suite' do
      let(:scheme) { 'iOSModule' }
      let(:destinations) { ['iOS', 'macOS'] }
      let(:bitcode) { 'OTHER_CFLAGS="-fembed-bitcode" BITCODE_GENERATION_MODE="bitcode" ENABLE_BITCODE=YES' }

      it 'verifies available_destinations method' do
        expected_destinations = [
          'iOS', 'iPadOS', 'macOS', 'tvOS', 'watchOS', 'carPlayOS', 'maccatalyst'
        ]
        actual_destinations = described_class.available_destinations.keys
        expect(actual_destinations.sort).to eq(expected_destinations.sort)
      end

      it 'verifies update_destinations method' do
        params = { destinations: destinations }
        generics = described_class.available_destinations.select do |k, _|
          destinations.include?(k)
        end.values.flatten
        result = described_class.update_destinations(params)
        expect(result).to eq(generics)
      end

      it 'verifies update_destinations method when no destination is provided' do
        params = { destinations: nil }
        generics = described_class.available_destinations.select do |k, _|
          k == destinations.first
        end.values.flatten
        result = described_class.update_destinations(params)
        expect(result).to eq(generics)
      end

      it 'verifies update_destinations method when wrong destination is provided' do
        unsupported_destination = 'Android'
        params = { destinations: [destinations.first, unsupported_destination] }
        err = "Error: available destinations: #{described_class.available_destinations.keys}"
        expect { described_class.update_destinations(params) }.to raise_error(err)
      end

      it 'verifies verify_delicate_params method when :scheme option was not provided' do
        params = { scheme: nil }
        err = 'Error: :scheme is required option'
        expect { described_class.verify_delicate_params(params) }.to raise_error(err)
      end

      it 'verifies verify_delicate_params method when :destinations option is not Array' do
        params = { scheme: scheme, destinations: destinations.first }
        err = 'Error: :destinations option should be presented as Array'
        expect { described_class.verify_delicate_params(params) }.to raise_error(err)
      end

      it 'verifies verify_delicate_params method when :destinations option was not provided' do
        params = { scheme: scheme, destinations: nil }
        expect { described_class.verify_delicate_params(params) }.not_to raise_error
      end

      it 'verifies clean method' do
        test_data = 'test'
        params = { remove_xcarchives: true }
        allow(FileUtils).to receive(:rm_rf).and_return(test_data)
        allow(nil).to receive(:xcarchive_path).and_return(test_data)
        result = described_class.clean(params)
        expect(result).to eq(test_data)
      end

      it 'verifies clean method when :remove_xcarchives options equals to false' do
        params = { remove_xcarchives: false }
        result = described_class.clean(params)
        expect(result).to eq(nil)
      end

      it 'verifies provide_shared_values method' do
        allow(nil).to receive(:xcframework_path)
        allow(nil).to receive(:xcframework_dSYMs_path)
        allow(nil).to receive(:xcframework_BCSymbolMaps_path)
        expected_result = ['0', '1', '2']
        allow(File).to receive(:expand_path).and_return(
          expected_result[0], expected_result[0],
          expected_result[1], expected_result[1],
          expected_result[2], expected_result[2]
        )
        described_class.provide_shared_values
        result = [
          ENV['XCFRAMEWORK_OUTPUT_PATH'],
          ENV['XCFRAMEWORK_DSYM_OUTPUT_PATH'],
          ENV['XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH']
        ]
        expect(result).to eq(expected_result)
      end

      it 'verifies copy_BCSymbolMaps method when all params are equals to false' do
        params = { enable_bitcode: false, include_BCSymbolMaps: false }
        described_class.copy_BCSymbolMaps(params)
        expect(FileUtils).not_to receive(:mkdir_p)
      end

      it 'verifies copy_BCSymbolMaps method when :enable_bitcode option is equals to true' do
        allow(nil).to receive(:xcframework_BCSymbolMaps_path)
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return('test')
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:cp_r)

        params = { destinations: destinations, enable_bitcode: true }
        result = described_class.copy_BCSymbolMaps(params)
        expect(result).to eq(destinations)
      end

      it 'verifies copy_BCSymbolMaps method when :include_BCSymbolMaps option is equals to true' do
        allow(nil).to receive(:xcframework_BCSymbolMaps_path)
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return('test')
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:cp_r)

        params = { destinations: destinations, include_BCSymbolMaps: true }
        result = described_class.copy_BCSymbolMaps(params)
        expect(result).to eq(destinations)
      end

      it 'verifies copy_BCSymbolMaps method when symbols_xcarchive_dir was not created' do
        allow(nil).to receive(:xcframework_BCSymbolMaps_path)
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path)
        allow(Dir).to receive(:exist?).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)

        params = { destinations: destinations, enable_bitcode: true }
        result = described_class.copy_BCSymbolMaps(params)
        expect(result).to eq(destinations)
      end

      it 'verifies copy_dSYMs method when :include_dSYMs option is equals to false' do
        params = { include_dSYMs: false }
        described_class.copy_dSYMs(params)
        expect(FileUtils).not_to receive(:mkdir_p)
      end

      it 'verifies copy_dSYMs method' do
        allow(nil).to receive(:xcframework_dSYMs_path)
        allow(nil).to receive(:xcarchive_dSYMs_path)
        allow(nil).to receive(:library_identifier)
        allow(nil).to receive(:framework)
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:cp_r)

        params = { include_dSYMs: false }
        described_class.copy_dSYMs(params)
        expect(FileUtils).not_to receive(:mkdir_p)
      end

      it 'verifies update_xcargs method when :override_xcargs option was provided' do
        params = { override_xcargs: true }
        result = described_class.update_xcargs(params)
        expected_result = " SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES #{bitcode}"
        expect(result).to eq(expected_result)
      end

      it 'verifies update_xcargs method when :override_xcargs and :xcargs options were provided' do
        xcargs = 'TESTME=33'
        params = { override_xcargs: true, xcargs: xcargs }
        result = described_class.update_xcargs(params)
        expected_result = "#{xcargs} SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES #{bitcode}"
        expect(result).to eq(expected_result)
      end

      it 'verifies update_xcargs method when fragile args have to be overwritten' do
        xcargs = 'SKIP_INSTALL=YES BUILD_LIBRARY_FOR_DISTRIBUTION YES ENABLE_BITCODE=NO'
        params = { override_xcargs: true, xcargs: xcargs }
        result = described_class.update_xcargs(params)
        expected_result = " SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES #{bitcode}"
        expect(result).to eq(expected_result)
      end

      it 'verifies update_xcargs method when :override_xcargs option was not provided' do
        xcargs = 'SKIP_INSTALL=YES BUILD_LIBRARY_FOR_DISTRIBUTION YES'
        params = { override_xcargs: nil, xcargs: xcargs }
        result = described_class.update_xcargs(params)
        expected_result = "#{xcargs} #{bitcode}"
        expect(result).to eq(expected_result)
      end

      it 'verifies update_xcargs method when :override_xcargs option is equal to false' do
        params = { enable_bitcode: false }
        result = described_class.update_xcargs(params)
        expect(result).to eq(' ')
      end

      it 'verifies debug_symbols method when xcode version is less than 12' do
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(false)
        # params = { include_debug_symbols: true }
        result = described_class.debug_symbols(index: 0, params: {})
        expect(result).to eq('')
      end

      it 'verifies debug_symbols method when :include_debug_symbols option is equal to false' do
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(true)
        params = { include_debug_symbols: false }
        result = described_class.debug_symbols(index: 0, params: params)
        expect(result).to eq('')
      end

      it 'verifies debug_symbols method' do
        test_data = 'testme'
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path).and_return(test_data)
        allow(nil).to receive(:xcarchive_dSYMs_path).and_return(test_data)
        allow(nil).to receive(:framework).and_return(test_data)
        allow(File).to receive(:expand_path).and_return(test_data)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return([test_data])
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(true)
        params = { include_debug_symbols: true }
        result = described_class.debug_symbols(index: 0, params: params)
        expected_result = "-debug-symbols #{test_data}/#{test_data}.dSYM -debug-symbols #{test_data}"
        expect(result).to eq(expected_result)
      end

      it 'verifies debug_symbols method when :include_debug_symbols option was not provided' do
        test_data = 'testme'
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path).and_return(test_data)
        allow(nil).to receive(:xcarchive_dSYMs_path).and_return(test_data)
        allow(nil).to receive(:framework).and_return(test_data)
        allow(File).to receive(:expand_path).and_return(test_data)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return([test_data])
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(true)
        result = described_class.debug_symbols(index: 0, params: { })
        expected_result = "-debug-symbols #{test_data}/#{test_data}.dSYM -debug-symbols #{test_data}"
        expect(result).to eq(expected_result)
      end

      it 'verifies debug_symbols method when :include_dSYMs option is equals to false' do
        test_data = 'testme'
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path).and_return(test_data)
        allow(nil).to receive(:xcarchive_dSYMs_path).and_return(test_data)
        allow(nil).to receive(:framework).and_return(test_data)
        allow(File).to receive(:expand_path).and_return(test_data)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return([test_data])
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(true)
        params = { include_debug_symbols: true, include_dSYMs: false }
        result = described_class.debug_symbols(index: 0, params: params)
        expected_result = "-debug-symbols #{test_data}"
        expect(result).to eq(expected_result)
      end

      it 'verifies debug_symbols method when :include_BCSymbolMaps and :enable_bitcode options are equal to false' do
        test_data = 'testme'
        allow(nil).to receive(:xcarchive_BCSymbolMaps_path).and_return(test_data)
        allow(nil).to receive(:xcarchive_dSYMs_path).and_return(test_data)
        allow(nil).to receive(:framework).and_return(test_data)
        allow(File).to receive(:expand_path).and_return(test_data)
        allow(Dir).to receive(:exist?).and_return(true)
        allow(Dir).to receive(:children).and_return([test_data])
        allow(Fastlane::Helper).to receive(:xcode_at_least?).and_return(true)
        params = { include_debug_symbols: true, enable_bitcode: false, include_BCSymbolMaps: false }
        result = described_class.debug_symbols(index: 0, params: params)
        expected_result = "-debug-symbols #{test_data}/#{test_data}.dSYM"
        expect(result).to eq(expected_result)
      end

      it 'verifies create_xcframework method' do
        xcframework = 'xcframework'
        xcarchive = 'xcarchive'
        allow(nil).to receive(:xcframework_path).and_return(xcframework)
        allow(nil).to receive(:xcarchive_framework_path).and_return(xcarchive)
        params = { include_debug_symbols: false, destinations: destinations }
        result = described_class.create_xcframework(params)
        expected_result = 'set -o pipefail && xcodebuild -create-xcframework -framework ' \
                          "#{xcarchive} -framework #{xcarchive} -output #{xcframework}"
        expect(result).to eq(expected_result)
      end

      it 'verifies create_xcframework method when :allow_internal_distribution option is equal to true' do
        xcframework = 'xcframework'
        xcarchive = 'xcarchive'
        allow(nil).to receive(:xcframework_path).and_return(xcframework)
        allow(nil).to receive(:xcarchive_framework_path).and_return(xcarchive)
        params = {
          destinations: destinations,
          include_debug_symbols: false,
          allow_internal_distribution: true
        }
        result = described_class.create_xcframework(params)
        expected_result = 'set -o pipefail && xcodebuild -create-xcframework -allow-internal-distribution ' \
                          "-framework #{xcarchive} -framework #{xcarchive} -output #{xcframework}"
        expect(result).to eq(expected_result)
      end
    end
  end
end
