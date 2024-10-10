require_relative 'lib/subscriptions_test_kit/version'

Gem::Specification.new do |spec|
  spec.name          = 'subscriptions_test_kit'
  spec.version       = SubscriptionsTestKit::VERSION
  spec.authors       = ['Karl Naden, Emily Semple, Tom Strassner']
  spec.email         = ['inferno@groups.mitre.org']
  spec.summary       = 'Subscriptions Test Kit'
  spec.description   = 'Inferno test kit for FHIR R5-style Subscriptions'
  spec.homepage      = 'https://github.com/inferno-framework/subscriptions-test-kit'
  spec.license       = 'Apache-2.0'
  spec.add_dependency 'inferno_core', '~> 0.4.43'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.2')
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.files = [
    Dir['lib/**/*.rb'],
    Dir['lib/**/*.json'],
    Dir['lib/**/*.md'],
    Dir['lib/**/*.csv'],
    'LICENSE'
  ].flatten

  spec.require_paths = ['lib']
end
