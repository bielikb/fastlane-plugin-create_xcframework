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
          remove_module_reference(params)
          sign_xcframework(params)
          zip_xcframework(params)
          delete_xcframework(params)

          copy_dSYMs(params)

          copy_BCSymbolMaps(params)

          clean(params)

          

          provide_shared_values(params)
        else
          UI.important('xcframework can be produced only using Xcode 11 and above')
        end
      end

      def self.provide_shared_values(params)
        frameworks = params[:frameworks] || [nil]
        frameworks.each do |framework|
          xcframework_path = framework ? @xchelper.get_xcframework_path(framework) : @xchelper.xcframework_path
          dsyms_path = framework ? @xchelper.framework_dSYMs_path(framework) : @xchelper.xcframework_dSYMs_path
          bcsymbolmaps_path = framework ? @xchelper.framework_BCSymbolMaps_path(framework) : @xchelper.xcframework_BCSymbolMaps_path
      
          Actions.lane_context[SharedValues::XCFRAMEWORK_OUTPUT_PATH] = File.expand_path(xcframework_path)
          ENV[SharedValues::XCFRAMEWORK_OUTPUT_PATH.to_s] = File.expand_path(xcframework_path)
          Actions.lane_context[SharedValues::XCFRAMEWORK_DSYM_OUTPUT_PATH] = File.expand_path(dsyms_path)
          ENV[SharedValues::XCFRAMEWORK_DSYM_OUTPUT_PATH.to_s] = File.expand_path(dsyms_path)
          Actions.lane_context[SharedValues::XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH] = File.expand_path(bcsymbolmaps_path)
          ENV[SharedValues::XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH.to_s] = File.expand_path(bcsymbolmaps_path)
        end
      end

      def self.clean(params)
        FileUtils.rm_rf(@xchelper.xcarchive_path) if params[:remove_xcarchives]
      end

      def self.create_xcframework(params)
        UI.message("params: #{params}")

        if params[:frameworks]
          params[:frameworks].each do |framework|
            UI.message("▸ Creating xcframework for #{framework}")
            xcframework = @xchelper.get_xcframework_path(framework)
            UI.message("▸ Creating xcframework for #{framework} at path: #{xcframework}")
            begin
              FileUtils.rm_rf(xcframework) if File.exist?(xcframework)
      
              arguments = ['-create-xcframework']
              arguments << '-allow-internal-distribution' if params[:allow_internal_distribution]
      
              params[:destinations].each_with_index do |_, index|
                arguments << "-framework #{@xchelper.get_xcarchive_framework_path(index, framework)}"
                arguments << debug_symbols(index: index, params: params, framework: framework)
              end
              arguments << "-output #{xcframework}"
              UI.message("set -o pipefail && xcodebuild #{arguments.reject(&:empty?).join(' ')}")

              Actions.sh("set -o pipefail && xcodebuild #{arguments.reject(&:empty?).join(' ')}")
            rescue StandardError => e
              UI.user_error!(e)
            end
          end
        else
          xcframework = @xchelper.xcframework_path
          UI.message("▸ Creating xcframework at path: #{xcframework}")
          begin
            FileUtils.rm_rf(xcframework) if File.exist?(xcframework)
      
            arguments = ['-create-xcframework']
            arguments << '-allow-internal-distribution' if params[:allow_internal_distribution]
      
            params[:destinations].each_with_index do |_, index|
              arguments << "-framework #{@xchelper.xcarchive_framework_path(index)}"
              arguments << debug_symbols(index: index, params: params, framework: @xchelper.framework)
            end
            arguments << "-output #{xcframework}"
      
            Actions.sh("set -o pipefail && xcodebuild #{arguments.reject(&:empty?).join(' ')}")
          rescue StandardError => e
            UI.user_error!(e)
          end
        end
      end

      def self.sign_xcframework(params)
        return if params[:code_sign_identity].nil?
      
        frameworks = params[:frameworks] || [nil]
      
        frameworks.each do |framework|
          xcframework = framework ? @xchelper.get_xcframework_path(framework) : @xchelper.xcframework_path
          UI.message("▸ Signing xcframework with '#{params[:code_sign_identity]}' at path: #{xcframework}")
      
          begin
            command = "codesign --force --sign '#{params[:code_sign_identity]}' --timestamp=none #{xcframework}"
            UI.message(command)
            Actions.sh(command)
          rescue StandardError => e
            UI.user_error!(e)
          end
        end
      end

      def self.zip_xcframework(params)
        return if params[:zip_xcframework].nil?

        # Check if the zip utility is installed
        unless system("which zip > /dev/null 2>&1")
          UI.important("zip utility is not installed. Installing...")
          system("brew install zip") || UI.crash!("Error: Failed to install zip utility")
        end

        frameworks = params[:frameworks] || [nil]

        frameworks.each do |framework|
          xcframework = framework ? @xchelper.get_xcframework_path(framework) : @xchelper.xcframework_path
          UI.message("▸ Zipping xcframework at path: #{xcframework}")

          begin
            zip_path = "#{xcframework}.zip"
            FileUtils.rm_f(zip_path) if File.exist?(zip_path)

            command = "zip -r -X #{zip_path} #{xcframework}"
            UI.message(command)

            Actions.sh(command)
          rescue StandardError => e
            UI.user_error!(e)
          end
        end
      end

      def self.delete_xcframework(params)
        return if params[:delete_xcframework].nil?

        frameworks = params[:frameworks] || [nil]

        frameworks.each do |framework|
          xcframework = framework ? @xchelper.get_xcframework_path(framework) : @xchelper.xcframework_path
          UI.message("▸ Deleting xcframework at path: #{xcframework}")

          begin
            FileUtils.rm_rf(xcframework)
          rescue StandardError => e
            UI.user_error!(e)
          end
        end
      end



      # #Fix compile problem go to xcframework and run this command (https://developer.apple.com/forums/thread/123253):
      # #The generated file includes many module references that Swift thinks are class references because it uses the class ahead of the module
      # #The problem is that in the Swiftinterface file, we have a class named ABCConnections, but the module is also called ABCConnections. 
      def self.remove_module_reference(params)
        return if params[:ignore_module_reference].nil?
      
        frameworks = params[:frameworks] || [nil]
      
        frameworks.each do |framework|
          output_path = framework ? @xchelper.get_xcframework_path(framework) : @xchelper.xcframework_path
          params[:ignore_module_reference].each do |module_reference|
            begin
              command = "find #{output_path} -name '*.swiftinterface' -exec sed -i -e 's/#{module_reference}\\.//g' {} \\;"
              success = system(command)
              unless success
                UI.error("Failed to execute command: #{command}")
              else
                UI.success("▸ Removed module reference for #{module_reference} in all matching files")
              end
            rescue => e
              UI.error("Error: #{e.message}")
            end
          end
        end
      end

      def self.debug_symbols(index:, params:, framework: nil)
        return '' if !Helper.xcode_at_least?('12.0.0') || params[:include_debug_symbols] == false
      
        frameworks = params[:frameworks] || [framework]
        debug_symbols = []
      
        frameworks.each do |fw|
          # Include dSYMs in xcframework
          if params[:include_dSYMs] != false
            debug_symbols << "-debug-symbols #{@xchelper.xcarchive_dSYMs_path(index)}/#{fw}.dSYM"
          end
      
          # Include BCSymbols in xcframework
          if params[:include_BCSymbolMaps] != false
            bc_symbols_dir = @xchelper.xcarchive_BCSymbolMaps_path(index)
            if Dir.exist?(bc_symbols_dir)
              arguments = Dir.children(bc_symbols_dir).map { |path| "-debug-symbols #{File.expand_path("#{bc_symbols_dir}/#{path}")}" }
              debug_symbols << arguments.join(' ')
            end
          end
        end
      
        debug_symbols.join(' ')
      end

      def self.copy_dSYMs(params)
        return if params[:include_dSYMs] == false
      
        frameworks = params[:frameworks] || [nil]
      
        frameworks.each_with_index do |framework, framework_index|
          dSYMs_output_dir = framework ? @xchelper.framework_dSYMs_path(framework) : @xchelper.xcframework_dSYMs_path
          FileUtils.mkdir_p(dSYMs_output_dir)
      
          dSYM_source = "#{@xchelper.xcarchive_dSYMs_path(framework_index)}/#{framework}.dSYM"
          identifier = @xchelper.library_identifier(framework_index)
          dSYM = "#{framework}.#{identifier}.dSYM"
          dSYM_destination = "#{dSYMs_output_dir}/#{dSYM}"
      
          UI.important("▸ Copying #{dSYM} to #{dSYMs_output_dir}")
          FileUtils.cp_r(dSYM_source, dSYM_destination)
        end
      end

      def self.copy_BCSymbolMaps(params)
        return if params[:include_BCSymbolMaps] == false
      
        frameworks = params[:frameworks] || [nil]
      
        frameworks.each_with_index do |framework, framework_index|
          symbols_output_dir = framework ? @xchelper.framework_BCSymbolMaps_path(framework) : @xchelper.xcframework_BCSymbolMaps_path
          FileUtils.mkdir_p(symbols_output_dir)
      
          symbols_xcarchive_dir = @xchelper.xcarchive_BCSymbolMaps_path(framework_index)
          next unless Dir.exist?(symbols_xcarchive_dir)
      
          FileUtils.cp_r("#{symbols_xcarchive_dir}/.", symbols_output_dir)
          UI.important("▸ Copying #{Dir.children(symbols_xcarchive_dir)} to #{symbols_output_dir}")
        end
      end

      def self.verify_delicate_params(params)
        UI.user_error!('Error: :scheme is required option') if params[:scheme].nil?
        if !params[:destinations].nil? && !params[:destinations].kind_of?(Array)
          UI.user_error!('Error: :destinations option should be presented as Array')
        end
      end

      def self.update_xcargs(params)
        xcargs = params[:override_xcargs].to_s.strip.split(' ')
        skip_install_set = false
        build_library_for_distribution_set = false
      
        xcargs.each do |arg|
          if arg.match?(/SKIP_INSTALL(=|\s+)/)
            skip_install_set = true
            unless arg.match?(/SKIP_INSTALL=NO/)
              xcargs.delete(arg)
              xcargs << 'SKIP_INSTALL=NO'
            end
          end
      
          if arg.match?(/BUILD_LIBRARY_FOR_DISTRIBUTION(=|\s+)/)
            build_library_for_distribution_set = true
            unless arg.match?(/BUILD_LIBRARY_FOR_DISTRIBUTION=YES/)
              xcargs.delete(arg)
              xcargs << 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES'
            end
          end
        end
      
        xcargs << 'SKIP_INSTALL=NO' unless skip_install_set
        xcargs << 'BUILD_LIBRARY_FOR_DISTRIBUTION=YES' unless build_library_for_distribution_set
      
        xcargs.join(' ')
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
          'maccatalyst' => ['generic/platform=macOS,variant=Mac Catalyst'],
          'visionOS' => ['generic/platform=visionOS', 'generic/platform=visionOS Simulator']
        }
      end

      #####################################################
      #                   Documentation                   #
      #####################################################

      def self.description
        'Fastlane plugin that creates xcframework for given list of destinations.'
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
        ['Boris Bielik', 'Alexey Alter-Pesotskiy']
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
            key: :destinations,
            description: 'Use custom destinations for building the xcframework',
            optional: true,
            is_string: false,
            default_value: ['iOS']
          ),
          FastlaneCore::ConfigItem.new(
            key: :xcframework_output_directory,
            description: 'The directory in which the xcframework should be stored in',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_dSYMs,
            description: 'Includes dSYM files in the xcframework',
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :include_BCSymbolMaps,
            description: 'Includes BCSymbolMap files in the xcframework',
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
            description: 'The name of your module. Optional if equals to :scheme. Equivalent to CFBundleName',
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
            key: :allow_internal_distribution,
            description: 'This option will create an xcframework with the allow-internal-distribution flag.' \
                         'Allows the usage of @testable when importing the created xcframework in tests',
            optional: true,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :override_xcargs,
            description: 'This option will override xcargs SKIP_INSTALL and BUILD_LIBRARY_FOR_DISTRIBUTION.' \
                          'If set to true, SKIP_INSTALL will be set to NO and BUILD_LIBRARY_FOR_DISTRIBUTION will be set to YES' \
                          'Set this to false to preserve the passed xcargs',
            optional: true,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :frameworks,
            description: 'List of frameworks to create xcframework for',
            optional: true,
            is_string: false,
            type: Array,
            default_value: []),
          FastlaneCore::ConfigItem.new(
            key: :code_sign_identity,
            description: 'Code sign identity to use for building the xcframework',
            optional: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :zip_xcframework,
            description: 'Zip the xcframework after creation',
            optional: true,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :ignore_module_reference,
            description: 'List of module references to remove from the xcframework',
            optional: true,
            is_string: false,
            type: Array,
            default_value: []),
          FastlaneCore::ConfigItem.new(
            key: :delete_xcframework,
            description: 'Delete the xcframework after creation',
            optional: true,
            default_value: false
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
