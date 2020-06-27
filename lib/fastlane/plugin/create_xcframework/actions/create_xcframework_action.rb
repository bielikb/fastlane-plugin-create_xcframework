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
            params[:archive_path] = @xchelper.xcarchive_path(framework_index)
            XcarchiveAction.run(params)
          end

          create_xcframework

          copy_dSYMs(params)

          copy_BCSymbolMaps(params)

          clean

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

      def self.clean
        @xchelper.xcarchive_frameworks_path.each { |framework| FileUtils.rm_rf(framework.split('/').first) }
      end

      def self.create_xcframework
        xcframework = @xchelper.xcframework_path
        begin
          FileUtils.rm_rf(xcframework) if File.exist?(xcframework)
          framework_links = @xchelper.xcarchive_frameworks_path.map { |path| "-framework #{path}" }.join(' ')
          Actions.sh("set -o pipefail && xcodebuild -create-xcframework #{framework_links} -output #{xcframework}")
        rescue => err
          UI.user_error!(err)
        end
      end

      def self.copy_dSYMs(params)
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
        return unless params[:include_bitcode]

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
        FastlaneCore::UI.important('Overwriting SKIP_INSTALL and BUILD_LIBRARY_FOR_DISTRIBUTION options')
        if params[:xcargs]
          params[:xcargs].gsub!(/SKIP_INSTALL(=|\s+)(YES|NO)/, '')
          params[:xcargs].gsub!(/BUILD_LIBRARY_FOR_DISTRIBUTION(=|\s+)(YES|NO)/, '')
          params[:xcargs] += ' '
        end
        xcargs = ['SKIP_INSTALL=NO', 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES']

        if params[:include_bitcode]
          params[:xcargs].gsub!(/ENABLE_BITCODE(=|\s+)(YES|NO)/, '') if params[:xcargs]
          xcargs << ['OTHER_CFLAGS="-fembed-bitcode"', 'BITCODE_GENERATION_MODE="bitcode"', 'ENABLE_BITCODE=YES']
        end

        params[:xcargs].to_s + xcargs.join(' ')
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
            include_bitcode: true,
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
        "Create xcframework plugin generates xcframework for specified destinations. The output of this action consists of the xcframework itself, dSYM and BCSymbolMaps, if bitcode is enabled."
      end

      def self.available_options
        XcarchiveAction.available_options + [
          FastlaneCore::ConfigItem.new(
            key: :scheme,
            description: "The project's scheme. Make sure it's marked as Shared",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_bitcode,
            description: "Should the xcframework include bitcode?",
            optional: true,
            is_string: false,
            default_value: false
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
            key: :product_name,
            description: "The name of your module. Optional if equals to :scheme. Equivalent to CFBundleName",
            optional: true
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
