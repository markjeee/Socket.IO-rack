require 'rubygems'
gem 'echoe'
require 'echoe'

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

gem 'rspec'
require 'spec/rake/spectask'

Spec::Rake::SpecTask.new do |t|
  t.spec_opts.push("-f s")
end
