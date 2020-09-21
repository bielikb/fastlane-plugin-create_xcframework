# create_xcframework plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-create_xcframework)

## About create_xcframework

Fastlane plugin that creates xcframework for given list of destinations 🚀

## Requirements

* Xcode 11.x or greater. Download it at the [Apple Developer - Downloads](https://developer.apple.com/downloads) or the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12).
* fastlane

## Getting Started

To get started with `create_xcframework` plugin, add it to your project by running:

```bash
$ fastlane add_plugin create_xcframework
```

## Usage

```ruby
create_xcframework(
    workspace: 'path/to/your.xcworkspace',
    scheme: 'framework scheme',
    product_name: 'Sample', # optional if scheme doesnt match the name of your framework
    destinations: ['iOS', 'maccatalyst'],
    xcframework_output_directory: 'path/to/your/output dir'
)
```

Run
```bash
$ fastlane actions create_xcframework
```
to learn more about the plugin.

### Supported destinations

* iOS
* iPadOS
* maccatalyst
* tvOS
* watchOS
* carPlayOS
* macOS

## Output

#### Files:
* xcframework
* dSYMs dir
* BCSymbolMaps dir (if bitcode is enabled)

#### Env vars:
* XCFRAMEWORK_OUTPUT_PATH
* XCFRAMEWORK_DSYM_OUTPUT_PATH
* XCFRAMEWORK_BCSYMBOLMAPS_OUTPUT_PATH


## Contribution

- If you **want to contribute**, read the [Contributing Guide](https://github.com/bielikb/fastlane-plugin-create_xcframework/blob/master/CONTRIBUTING.md)
