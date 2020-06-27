describe Fastlane::Actions::CreateXcframeworkAction do
  describe '#run' do
    it 'prints a message' do
      expect(Fastlane::UI).to receive(:message).with("The create_xcframework plugin is working!")

      Fastlane::Actions::CreateXcframeworkAction.run(nil)
    end
  end
end
