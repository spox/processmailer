spec = Gem::Specification.new do |s|
    s.name              = 'processmailer'
    s.author            = %q(spox)
    s.email             = %q(spox@modspox.com)
    s.version           = '0.0.2'
    s.summary           = %q(Process Post Office)
    s.platform          = Gem::Platform::RUBY
    s.has_rdoc          = true
    s.files             = %w(README.rdoc LICENSE lib/processmailer.rb lib/processmailer/Actions.rb lib/processmailer/Exceptions.rb lib/processmailer/LogHelper.rb lib/processmailer/Postbox.rb lib/processmailer/PostOffice.rb)
    s.rdoc_options      = %w(--title ProcessMailer --main README.rdoc --line-numbers)
    s.extra_rdoc_files  = %w(README.rdoc LICENSE)
    s.require_paths     = %w(lib)
    s.required_ruby_version = '>= 1.8.6'
    s.add_dependency    'ActionPool'
    s.homepage          = %q(http://github.com/spox/processmailer)
    s.description         = 'ProcessMailer for concurrent data processing'
end