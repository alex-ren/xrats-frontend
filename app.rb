require 'sinatra'
require 'yaml'

$repos = YAML.load_file("config/repos.yml")["repos"]
$ats = YAML.load_file("config/ats.yml")["versions"]

def replace_pattern str, pattern, replace
  while str.match(pattern) do
    str.gsub!(pattern,replace)
  end
end

def lxr_send_file path, browser=true
  text = File.open(path,"r").read
  if browser
    haml :regular_file, locals:{text:text,title:path}
  else
    #Let nginx send the file
    response.headers['X-Accel-Redirect'] = "#{path}"
    nil
  end
end

def listing_of_directory directory
  raise Sinatra::NotFound if not File.directory?(directory)
  @directory = Dir.new(directory)
  @entries = @directory.entries
  @entries.sort!
  haml :directory_listing
end

def xref_of_file path, base
  raise Sinatra::NotFound if not File.exists?(path)
  file_folder = File.dirname(path)
  atsopt_path = "/opt/ats/bin/atsopt"
  flag = ""
  if path.match(/\.dats/)
    flag = "--dynamic"
  end
  if path.match(/\.sats/)
    flag = "--static"
  end
  atsopt = IO.popen("#{atsopt_path} --posmark_xref -IATS #{base} -IATS #{file_folder} #{flag} #{path}")
  atsopt.readlines.join("")
end

def make_xref folder,repo,path
  ats_home = ""
  base = ""
  case folder
  when "repos"
    $repos.each do |name,attr|
      if name == repo
        ats_home= attr["ats"]
        break
      end
    end
    base = "repos/#{repo}"
  when "ats"
    ats_home = repo
    base = "ats/#{ats_home}"
  else
    raise Sinatra::NotFound
  end
  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{ats_home}"
  output = xref_of_file "#{folder}/#{repo}/#{path}", base
  replace_pattern(output,/a href\=\"#{Dir.pwd}\/ats\/#{ats_home}\/(.*)\"/,"a href=\"/ats/#{ats_home}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,"a href=\"/repos/\\1\"")
  output
end

get %r{^/(ats|repos)??/?$} do 
  haml :index
end

get %r{^/(download/)?(ats|repos)/(.*?)/(.*)} do |dflag,folder,repo,path|
  @rel_path = "#{folder}/#{repo}/#{path}"
  puts @rel_path
  raise Sinatra::NotFound if not File.exists? @rel_path
  return lxr_send_file @rel_path, false if dflag
  return listing_of_directory(@rel_path) if File.directory? @rel_path
  if !path.match(/\.dats/) && !path.match(/\.sats/)
    return lxr_send_file @rel_path
  end
  src = make_xref folder,repo,path
  haml :ats_source, locals:{source:src,title:path}
end
