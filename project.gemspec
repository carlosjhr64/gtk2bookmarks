require 'date'
require 'find'

project_version = File.expand_path( File.dirname(__FILE__) ).split(/\//).last
project, version = nil, nil
if project_version=~/^(\w+)-(\d+\.\d+\.\d+)$/ then
  project, version = $1, $2
else
  raise 'need versioned directory'
end

spec = Gem::Specification.new do |s|
  s.name = project
  s.version = version
  s.date = Date.today.to_s
  s.summary = `head -n 1 README.txt`.strip
  s.email = "carlosjhr64@gmail.com"
  s.homepage = "https://sites.google.com/site/gtk2applib/home/gtk2applib-applications/gtk2bookmarks"
  s.description = `head -n 5 README.txt | tail -n 3`
  s.has_rdoc = false
  s.authors = ['carlosjhr64@gmail.com']

  files = []
  # Rbs
  Find.find('.'){|fn|
    if fn=~/\.rb$/ then
puts fn
      files.push(fn)
    end
  }

  Find.find('./pngs'){|fn|
    if fn=~/\.png$/ then
puts fn
      files.push(fn)
    end
  }

  files.push('README.txt')

  s.files = files

  executables = []
  Find.find('./bin'){|fn|
    if fn=~/\/gtk2\w+$/ then
puts fn
      executables.push(fn.sub(/^.*\//,''))
    end
  }
  s.executables = executables
  s.default_executable = project

  s.add_dependency('gtk2applib', '~> 15.3')
  s.requirements << 'gtk2'
  s.requirements << 'nokogiri'
  s.requirements << 'hpricot'

  # s.rubyforge_project = project # no longer on rubyforge
end
