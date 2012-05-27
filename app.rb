require 'sinatra'

$repos = []
$repos << {name:"foo",home:"ats-0.2.7"}

def replace_pattern str, pattern, replace
  while str.match(pattern) do
    str.gsub!(pattern,replace)
  end
end

def listing_of_directory directory
  raise Sinatra::NotFound if not File.directory?(directory)
  @directory = Dir.new(directory)
  @entries = @directory.entries
  @entries.sort! 
  haml :directory_listing
end

def xref_of_file path
  #raise Sinatra::NotFound if not File.exists?(path)
  file_folder = File.dirname(path)
  atsopt_path = "/opt/ats/bin/atsopt"
  flag = ""
  if path.match(/\.dats/)
    flag = "--dynamic"
  end
  if path.match(/\.sats/)
    flag = "--static"
  end
  atsopt = IO.popen("#{atsopt_path} --posmark_xref -IATS #{file_folder} #{flag} #{path}")
  atsopt.readlines.join("")
end

def make_xref repo_name, path
  repo = $repos.select do |r|
    r[:name] == repo_name
  end
  raise Sinatra::NotFound if (repo = repo.first).nil?
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{repo[:home]}"
  absolute_path = "#{Dir.pwd}/repos/#{repo_name}/#{path}"
  return listing_of_directory(absolute_path) if File.directory? absolute_path

  output = xref_of_file absolute_path
  #Fix up all the links
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{repo[:home]}\/(.*)\"/,
                  "a href=\"/ats/#{repo[:home]}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,"a href=\"/\\1\"")
  output
end

def make_xref_ats_source home, path
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{home}"
  absolute_path = "#{Dir.pwd}/ats/#{home}/#{path}"
  return listing_of_directory(absolute_path) if File.directory? absolute_path
  output = xref_of_file "#{Dir.pwd}/ats/#{home}/#{path}"
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{home}\/(.*)\"/,
                  "a href=\"/ats/#{home}/\\1\"")
  output
end

get '/' do
  haml :index
end

get '/ats/:home/*' do |home, path|
  make_xref_ats_source home, path
end

get '/:repo/*' do  |repo,path|
  make_xref repo, path
end
