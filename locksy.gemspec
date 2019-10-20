require_relative 'lib/locksy/version.rb'

Gem::Specification.new do |spec|
  spec.name = 'locksy'
  spec.version = Locksy::VERSION
  spec.summary = 'A tool to provide distributed locking'
  spec.description = spec.summary
  spec.license = 'MIT'
  spec.authors = %w(dan@52degreesnorth.com)
  spec.files = Dir.glob 'lib/**/*.rb'
  spec.require_paths = %w(lib)
  spec.homepage = 'https://github.com/danleyden/locksy'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-its', '~> 1.3'
  spec.add_development_dependency 'rubocop', '~> 0.57.2'

  # to allow production users to only bring in those providers they need
  # this is specified as a dev dependency. If the dynamo db implementation
  # is to be used... add it as a dep for your app
  spec.add_development_dependency 'aws-sdk-dynamodb'
end
