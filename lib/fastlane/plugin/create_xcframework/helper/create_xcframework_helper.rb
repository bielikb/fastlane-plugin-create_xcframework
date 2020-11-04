module Fastlane
  module Helper
    class CreateXcframeworkHelper
      def initialize(params)
        @params = params
      end

      def product_name
        @params[:product_name] ||= @params[:scheme]
      end

      def xcframework
        "#{product_name}.xcframework"
      end

      def framework
        "#{product_name}.framework"
      end

      def xcarchive_path
        "#{output_directory}/archives"
      end

      def xcarchive_path_for_destination(framework_index)
        "#{xcarchive_path}/#{framework_index}_#{product_name}.xcarchive"
      end

      def xcarchive_framework_path(framework_index)
        framework_path = "#{xcarchive_path_for_destination(framework_index)}/Products/Library/Frameworks/#{framework}"
        return framework_path if File.exist?(framework_path)

        FastlaneCore::UI.user_error!("▸ PRODUCT_NAME was misdefined: `#{product_name}`. Please, provide :product_name option")
      end

      def xcarchive_frameworks_path
        @params[:destinations].each_with_index.map { |_, i| xcarchive_framework_path(i) }
      end

      def xcarchive_dSYMs_path(framework_index)
        File.expand_path("#{xcarchive_path_for_destination(framework_index)}/dSYMS")
      end

      def xcframework_dSYMs_path
        File.expand_path("#{output_directory}/#{product_name}.dSYMs")
      end

      def xcarchive_BCSymbolMaps_path(framework_index)
        File.expand_path("#{xcarchive_path_for_destination(framework_index)}/BCSymbolMaps")
      end

      def xcframework_BCSymbolMaps_path
        File.expand_path("#{output_directory}/#{product_name}.BCSymbolMaps")
      end

      def xcframework_path
        File.expand_path("#{output_directory}/#{xcframework}")
      end

      def output_directory
        @params[:xcframework_output_directory] ? @params[:xcframework_output_directory] : ''
      end

      def library_identifier(framework_index)
        framework_path = xcarchive_framework_path(framework_index)
        framework_basename = framework_path.split('/').last
        framework_root = framework_basename.split('.').first
        library_identifiers = Dir.chdir(xcframework_path) do
          Dir.glob('*').select { |f| File.directory?(f) }
        end
        library_identifier = library_identifiers.detect do |id|
          FileUtils.compare_file(
            "#{framework_path}/#{framework_root}",
            "#{xcframework_path}/#{id}/#{framework_basename}/#{framework_root}"
          )
        end
        UI.user_error!("Error: #{xcframework_path} doesn't contain #{framework_path}") if library_identifier.nil?

        library_identifier
      end
    end
  end
end
