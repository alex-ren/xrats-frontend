require 'rubygems'
require 'rsolr'

path = ARGV[0]

repo = ARGV[1]

if !Dir.exists? ARGV[0]
  puts "Usage: path/to/dir repo"
  exit
end

solr = RSolr.connect url: "http://localhost:8983/solr"

to_process = `find -L #{path} -regextype posix-extended -regex '.*\.(cats|dats|sats|hats)'`.split("\n") if path

to_process.each do |filename|
  puts filename
  begin
    contents = File.open(filename.chomp,"r").read
  rescue Errno::ENOENT
    next #skip it
  end
  type = (filename.match(/\.dats/)) ? "dats" : "sats"
  
  solr.add id: filename, filename: filename, code: contents, repository: repo
end

solr.commit
