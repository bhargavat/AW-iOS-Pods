install! 'cocoapods', :integrate_targets => false

source 'https://stash.air-watch.com/scm/icpd/specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
inhibit_all_warnings!
use_frameworks!

target 'AWSDK-iOS' do
	pod 'AirWatchSDK', :git => 'ssh://git@stash.air-watch.com:7999/isdkl/airwatchsdk.git', :branch => 'release/17.6'
end