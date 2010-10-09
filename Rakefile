require 'rubygems'
gem 'echoe'
require 'echoe'

gem 'rspec'
require 'spec/rake/spectask'

Echoe.new("Socket.IO-rack") do |p|
  p.author="markjeee"
  p.project = "palmade"
  p.summary = "Socket.IO Rack version (server side)"

  p.dependencies = [ ]

  p.need_tar_gz = false
  p.need_tgz = true

  p.clean_pattern += [ "pkg", "lib/*.bundle", "*.gem", ".config" ]
  p.rdoc_pattern = [ 'README', 'LICENSE', 'COPYING', 'lib/**/*.rb', 'doc/**/*.rdoc' ]
end

Spec::Rake::SpecTask.new do |t|
  t.rcov = true
  t.spec_files = FileList['test/**/*_spec.rb']
end
