module Fastlane
  module Actions
    module SharedValues
      XCFRAMEWORK_OUTPUT_PATH ||= :XCFRAMEWORK_OUTPUT_PATH
      XCFRAMEWORK_DSYM_OUTPUT_PATH ||= :XCFRAMEWORK_DSYM_OUTPUT_PATH
      XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH ||= :XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH
    end

    require 'fastlane_core/ui/ui'
    require 'fastlane/actions/xcodebuild'
    require_relative '../helper/create_xcframework_helper'

    class CreateXcframeworkAction < Action
      def self.run(params)
        if Helper.xcode_at_least?('11.0.0')
          verify_delicate_params(params)
          params[:destinations] = update_destinations(params)
          params[:xcargs] = update_xcargs(params)

          @xchelper = Helper::CreateXcframeworkHelper.new(params)

          params[:destinations].each_with_index do |destination, framework_index|
            params[:destination] = destination
            params[:archive_path] = @xchelper.xcarchive_path_for_destination(framework_index)
            XcarchiveAction.run(params)
          end

          create_xcframework(params)

          copy_dSYMs(params)

          copy_BCSymbolMaps(params)

          clean(params)

          provide_shared_values
        else
          FastlaneCore::UI.important('xcframework can be produced only using Xcode 11 and above')
        end
      end

      def self.provide_shared_values
        Actions.lane_context[SharedValues::XCFRAMEWORK_OUTPUT_PATH] = File.expand_path(@xchelper.xcframework_path)
        ENV[SharedValues::XCFRAMEWORK_OUTPUT_PATH.to_s] = File.expand_path(@xchelper.xcframework_path)
        Actions.lane_context[SharedValues::XCFRAMEWORK_DSYM_OUTPUT_PATH] = File.expand_path(@xchelper.xcframework_dSYMs_path)
        ENV[SharedValues::XCFRAMEWORK_DSYM_OUTPUT_PATH.to_s] = File.expand_path(@xchelper.xcframework_dSYMs_path)
        Actions.lane_context[SharedValues::XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH] = File.expand_path(@xchelper.xcframework_BCSymbolMaps_path)
        ENV[SharedValues::XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH.to_s] = File.expand_path(@xchelper.xcframework_BCSymbolMaps_path)
      end

      def self.clean(params)
        FileUtils.rm_rf(@xchelper.xcarchive_path) if params[:remove_xcarchives]
      end

      def self.create_xcframework(params)
        xcframework = @xchelper.xcframework_path
        begin
          FileUtils.rm_rf(xcframework) if File.exist?(xcframework)
          framework_links = params[:destinations].each_with_index.map do |_, index|
            "-framework #{@xchelper.xcarchive_framework_path(index)} #{debug_symbols(index: index, params: params)}"
          end

          Actions.sh("set -o pipefail && xcodebuild -create-xcframework #{framework_links.join(' ')} -output #{xcframework}")
        rescue => err
          UI.user_error!(err)
        end
      end

      def self.debug_symbols(index:, params:)
        return "" unless Helper.xcode_at_least?('12.0.0') && params[:include_debug_symbols] == true

        debug_symbols = []

        # Include dSYMs in xcframework
        if params[:include_dSYMs] != false
          debug_symbols << "-debug-symbols #{@xchelper.xcarchive_dSYMs_path(index)}/#{@xchelper.framework}.dSYM"
        end

        # Include BCSymbols in xcframework
        if params[:include_BCSymbolMaps] != false && params[:enable_bitcode] != false
          bc_symbols_dir = @xchelper.xcarchive_BCSymbolMaps_path(index)
          if Dir.exist?(bc_symbols_dir)
            arguments = Dir.children(bc_symbols_dir).map { |path| "-debug-symbols #{File.expand_path("#{bc_symbols_dir}/#{path}")}" }
            debug_symbols << arguments.join(' ')
          end
        end

        debug_symbols.join(' ')
      end

      def self.copy_dSYMs(params)
        return if params[:include_dSYMs] == false

        dSYMs_output_dir = @xchelper.xcframework_dSYMs_path
        FileUtils.mkdir_p(dSYMs_output_dir)

        params[:destinations].each_with_index do |_, framework_index|
          dSYM_source = "#{@xchelper.xcarchive_dSYMs_path(framework_index)}/#{@xchelper.framework}.dSYM"
          identifier = @xchelper.library_identifier(framework_index)
          dSYM = "#{@xchelper.framework}.#{identifier}.dSYM"
          dSYM_destination = "#{dSYMs_output_dir}/#{dSYM}"

          FastlaneCore::UI.important("▸ Copying #{dSYM} to #{dSYMs_output_dir}")
          FileUtils.cp_r(dSYM_source, dSYM_destination)
        end
      end

      def self.copy_BCSymbolMaps(params)
        return if params[:enable_bitcode] == false || params[:include_BCSymbolMaps] == false

        symbols_output_dir = @xchelper.xcframework_BCSymbolMaps_path
        FileUtils.mkdir_p(symbols_output_dir)

        params[:destinations].each_with_index do |_, framework_index|
          symbols_xcarchive_dir = @xchelper.xcarchive_BCSymbolMaps_path(framework_index)
          next unless Dir.exist?(symbols_xcarchive_dir)

          FileUtils.cp_r("#{symbols_xcarchive_dir}/.", symbols_output_dir)
          FastlaneCore::UI.important("▸ Copying #{Dir.children(symbols_xcarchive_dir)} to #{symbols_output_dir}")
        end
      end

      def self.verify_delicate_params(params)
        UI.user_error!("Error: :scheme is required option") if params[:scheme].nil?
        if !params[:destinations].nil? && !params[:destinations].kind_of?(Array)
          UI.user_error!("Error: :destinations option should be presented as Array")
        end
      end

      def self.update_xcargs(params)
        xcargs = []
        if params[:override_xcargs]
          FastlaneCore::UI.important('Overwriting SKIP_INSTALL and BUILD_LIBRARY_FOR_DISTRIBUTION options')
          if params[:xcargs]
            params[:xcargs].gsub!(/SKIP_INSTALL(=|\s+)(YES|NO)/, '')
            params[:xcargs].gsub!(/BUILD_LIBRARY_FOR_DISTRIBUTION(=|\s+)(YES|NO)/, '')
            params[:xcargs] += ' '
          end
          xcargs.concat(['SKIP_INSTALL=NO', 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES'])
        end

        if params[:enable_bitcode] != false
          params[:xcargs].gsub!(/ENABLE_BITCODE(=|\s+)(YES|NO)/, '') if params[:xcargs]
          xcargs << ['OTHER_CFLAGS="-fembed-bitcode"', 'BITCODE_GENERATION_MODE="bitcode"', 'ENABLE_BITCODE=YES']
        end

        params[:xcargs].to_s + ' ' + xcargs.join(' ')
      end

      def self.update_destinations(params)
        return available_destinations.values[0] if params[:destinations].nil?

        requested_destinations = params[:destinations].map do |requested_de|
          available_destinations.select { |available_de, _| available_de == requested_de }.values
        end
        UI.user_error!("Error: available destinations: #{available_destinations.keys}") if requested_destinations.any?(&:empty?)

        requested_destinations.flatten
      end

      def self.available_destinations
        {
          'iOS' => ['generic/platform=iOS', 'generic/platform=iOS Simulator'],
          'iPadOS' => ['generic/platform=iPadOS', 'generic/platform=iPadOS Simulator'],
          'tvOS' => ['generic/platform=tvOS', 'generic/platform=tvOS Simulator'],
          'watchOS' => ['generic/platform=watchOS', 'generic/platform=watchOS Simulator'],
          'carPlayOS' => ['generic/platform=carPlayOS', 'generic/platform=carPlayOS Simulator'],
          'macOS' => ['generic/platform=macOS'],
          'maccatalyst' => ['generic/platform=macOS,variant=Mac Catalyst']
        }
      end

      #####################################################
      #                   Documentation                   #
      #####################################################

      def self.description
        "Fastlane plugin that creates xcframework for given list of destinations."
      end

      def self.example_code
        [
          create_xcframework(
            workspace: 'path/to/your.xcworkspace',
            scheme: 'framework scheme',
            destinations: ['iOS'],
            xcframework_output_directory: 'output_directory'
          )
        ]
      end

      def self.output
        [
          ['XCFRAMEWORK_OUTPUT_PATH', 'The path to the newly generated xcframework'],
          ['XCFRAMEWORK_DSYM_OUTPUT_PATH', 'The path to the folder with dSYMs'],
          ['XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH', 'The path to the folder with BCSymbolMaps']
        ]
      end

      def self.authors
        ["Boris Bielik", "Alexey Alter-Pesotskiy"]
      end

      def self.details
        'Create xcframework plugin generates xcframework for specified destinations. ' \
          'The output of this action consists of the xcframework itself, which contains dSYM and BCSymbolMaps, if bitcode is enabled.'
      end

      def self.available_options
        XcarchiveAction.available_options + [
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            description: "The project's scheme. Make sure it's marked as Shared",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :enable_bitcode,
            description: "Should the project be built with bitcode enabled?",
            optional: true,
            is_string: false,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :destinations,
            description: "Use custom destinations for building the xcframework",
            optional: true,
            is_string: false,
            default_value: ['iOS']
          ),
          FastlaneCore::ConfigItem.new(
            key: :xcframework_output_directory,
            description: "The directory in which the xcframework should be stored in",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_dSYMs,
            description: "Includes dSYM files in the xcframework",
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_BCSymbolMaps,
            description: "Includes BCSymbolMap files in the xcframework",
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_debug_symbols,
            description: 'This feature was added in Xcode 12.0.' \
                          'If this is set to false, the dSYMs and BCSymbolMaps wont be added to XCFramework itself',
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :product_name,
            description: "The name of your module. Optional if equals to :scheme. Equivalent to CFBundleName",
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :remove_xcarchives,
            description: 'This option will auto-remove the xcarchive files once the plugin finishes.' \
                          'Set this to false to preserve the xcarchives',
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :override_xcargs,
            description: 'This option will override xcargs SKIP_INSTALL and BUILD_LIBRARY_FOR_DISTRIBUTION.' \
                          'If set to true, SKIP_INSTALL will be set to NO and BUILD_LIBRARY_FOR_DISTRIBUTION will be set to YES' \
                          'Set this to false to preserve the passed xcargs',
            optional: true,
            default_value: true
          )
        ]
      end

      def self.category
        :building
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
