# create_xcframework plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-create_xcframework)

## About create_xcframework

Fastlane plugin that creates xcframework for given list of destinations 🚀

## Requirements

* Xcode 11.x or greater. Download it at the [Apple Developer - Downloads](https://developer.apple.com/downloads) or the [Mac App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12).

## Getting Started

To get started with `create_xcframework`, add it to your project by running:

```bash
$ fastlane add_plugin create_xcframework
```

## Usage

```ruby
create_xcframework(
    product_name: 'Sample',
    scheme: 'Sample',
    workspace: 'Sample.xcworkspace',
    include_bitcode: true,
    destinations: ['iOS', 'maccatalyst'],
    xcframework_output_directory: 'Products/xcframeworks'
)
```
