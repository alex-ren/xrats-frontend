require 'sinatra'

require 'yaml'
require 'json'
require 'open4'
require 'fileutils'
require 'securerandom'
require 'rsolr'

$app_config = YAML.load_file("config/app.yml")[ENV['RACK_ENV']]
$repos = YAML.load_file("config/repos.yml")["repos"]
$ats = YAML.load_file("config/ats.yml")["versions"]

class Dir
  #Check if a file is a child of some directory
  def contains? file
    begin
      rdir  = File.realpath self.path
      rfile = File.realpath file
    rescue Errno::ENOENT
      return false
    end
    
    rfile =~ /^#{rdir}/
  end
end

helpers do
  include Rack::Utils
  
  def render_flags flags
    flags.join(" ") unless flags.nil?
  end
  
  def ats_editor flags
    flags[:runtime_flags] ||= []
    flags[:compile_flags] ||= []
    flags[:arch] ||= "x86_64"
    flags[:filename] ||= "foo"
    flags[:canned] ||= ""
    flags[:download] ||= false
    flags[:title] ||= nil
    haml :editor, locals: flags
  end
  
  def add_javascript file
    @javascripts ||= []
    @javascripts.push file
  end
end

def get_new_hashcode
  SecureRandom.urlsafe_base64(8)
end

def save_session hashcode, data
  raise Sinatra::NotFound unless hashcode =~ /^[A-Za-z0-9\-_]+$/
  
  File.open("data/sessions/#{hashcode}", "w+") do |session|
    session.puts(data.to_json)
  end
end

def retrieve_session hashcode
  sessions = Dir.new("data/sessions")
  filename = "#{sessions.path}/#{hashcode}"
  
  if File.exists?(filename) && sessions.contains?(filename)
    File.open(filename,"r") do |session|
      return JSON.parse(session.read)
    end
  end
  Hash.new
end

def replace_pattern str, pattern, replace
  while str.match(pattern) do
    str.gsub!(pattern,replace)
  end
end

def lxr_send_file path, browser=true
  text = File.open(path,"r").read
  if browser
    haml :regular_file, locals:{text:text,title:"ATS LXR - "+path}
  else
    #Let nginx send the file
    response.headers['Content-Type'] = "text/plain"
    cache_control :public, max_age:"3600"
    response.headers['X-Accel-Redirect'] = "/protected/#{path}"
  end
end

def listing_of_directory directory
  raise Sinatra::NotFound if not File.directory?(directory)
  @directory = Dir.new(directory)
  @entries = @directory.entries
  @entries.select! do |f|
    not [".", "..", ".git", ".svn"].include? f
  end
  @entries.sort! do |a, b|
    adir = File.directory? @directory.to_path+"/" + a
    bdir = File.directory? @directory.to_path+"/" + b
    (adir == bdir) ? (a.casecmp(b)) : (adir && !bdir) ? -1 : 1
  end
  haml :directory_listing, locals: {title: "ATS LXR - "+@directory.to_path}
end

def xref_of_file path, base
  raise Sinatra::NotFound if not File.exists?(path)
  file_folder = File.dirname(path)
  atsopt_path = $app_config[:atshome] + "/bin/atsopt"
  cmd = $app_config[:patshome] + "/utils/atsyntax/pats2xhtml" #For ATS2
  flags = []
  if path.match(/\.dats/)
    flags.push "--dynamic"
  end
  if path.match(/\.sats/)
    flags.push "--static"
  end
  if File.exists? file_folder + "/.ats2"
    ENV["PATSHOME"] = $app_config[:patshome]
    input = File.open(path).read()
    res = ""
    flags.unshift "--embed"
    status = Open4::popen4(cmd+" "+flags.join(" ")) do |pid, stdin, stdout, stderr|
      stdin.puts(input)
      stdin.close
      res = stdout.read
    end
    res
  else
    `#{atsopt_path} --posmark_xref -IATS #{base} -IATS #{ENV["ATSHOME"]} -IATS #{file_folder} #{flag} #{path}`
  end
end

def make_xref folder, repo, path
  ats_home = ""
  base = ""
  case folder
  when "repos"
    $repos.each do |name, attr|
      if name == repo
        ats_home= attr["ats"]
        break
      end
    end
    base = "repos/#{repo}"
  when "ats"
    @repos << repo if not @repos.include?(repo)
    ats_home = repo
    base = "ats/#{ats_home}"
  else
    raise Sinatra::NotFound
  end

  ENV["ATSHOME"] = "#{Dir.pwd}/ats/#{ats_home}"
  output = xref_of_file "#{folder}/#{repo}/#{path}", base
  
  replace_pattern(output,/a href=\"#{Dir.pwd}\/ats\/#{ats_home}\/(.*)\"/,
                  "a href=\"/ats/#{ats_home}/\\1\"")
  replace_pattern(output,/a href=\"#{Dir.pwd}\/repos\/(.*)\"/,
                  "a href=\"/repos/\\1\"")
  
  output
end

def atscc_jailed params
  res = ""
  input = params.to_json
  jailed_command = "lib/atscc-jailed"
  
  status = Open4::popen4(jailed_command) do |pid, stdin, stdout, stderr|
    stdin.puts(input)
    stdin.close
    res = stderr.read + stdout.read
  end
  
  res = escape_html res
  
  if status.to_i != 0
    res = "Killed" if res.empty?
  end
  
  range_err_replace = <<-eos
 <button class="syntax-error range-error" data-line-start="\\1" data-char-start="\\2"
         data-line-end="\\3" data-char-end="\\4">(\\1,\\2) to (\\3,\\4)</button>
eos
  point_err_replace = <<-eos
 <button class="syntax-error point-error" data-line="\\1" data-char="\\2">\
   line=\\1, offs=\\2 \
 </button>
eos

  formatted = res.split("\n")
  formatted.map! do |line|
    # patsopt throws errors in the prelude, we only want our errors.
    if line =~ /^(stdin|:|syntax error)/
      replace_pattern(line,/\(line=(\d+), offs=(\d+)\).*?\(line=(\d+), offs=(\d+)\)/,
                      range_err_replace)
      replace_pattern(line,/\(line=(\d+), offs=(\d+)\)/,
                      point_err_replace)
    end
    line
  end
  res = formatted.join("\n")
  
  [status.to_i, res]
end

def download_project params
  
  file = params["original_file"]
  
  lib = "clibs/#{params["arch"]}"
  
  basepath = $app_config[:chroot_path]+"/tmp/downloads"
  base = nil
  
  while true do 
    begin
      base = Dir.new basepath
      break;
    rescue Errno::ENOENT
      FileUtils.mkdir_p(basepath)
    end
  end
  
  dir = base.path+"/"+params["hashcode"]
  orig = "#{$app_config[:chroot_path]}/tmp/#{file}"
  src  = dir+"/"+params["filename"]+".c"
  liba = dir+"/ats"
  
  if !(File.exists?(orig+"_dats.c") && Dir.exists?(lib)        \
       && $app_config[:allowed_archs].include?(params["arch"]) \
       && params["filename"] =~ /^[a-zA-Z0-9\-_]+$/            \
       && ( !Dir.exists?(dir) || base.contains?(dir) ))
    raise Sinatra::NotFound
  end

  if Dir.exists? (dir)
    FileUtils.rm_r(dir)
  end
  
  FileUtils.mkdir_p(dir)
  FileUtils.cp(orig+"_dats.c", src)
  FileUtils.cp_r(lib+"/ats", liba)
  
  #Todo: Process a Makefile
  
  tar = "#{dir}/#{params["filename"]}.tar.gz"
  
  files = [tar, src, liba].map do |f|
    File.basename(f)
  end
  
  `tar -czf #{tar} --directory=#{dir} #{files.slice(1..2).join(" ")}`
  
  #nginx needs a path relative to tmp/downloads
  tar.gsub! /^#{$app_config[:chroot_path]}\/tmp\/downloads\//, ""
  
  response.headers['Content-Type'] = "application/x-gzip"
  response.headers['Content-Disposition'] = "attachment; filename=#{files[0]}"
  response.headers['X-Accel-Redirect'] = "/export/#{tar}"
end

def download_exe params
  tmp = "#{$app_config[:chroot_path]}/tmp/"
  orig = "#{tmp}/#{params["original_file"]}.hex"
  src = "#{tmp}/downloads/#{params["filename"]}.hex"
  
  FileUtils.mkdir_p(tmp)
  FileUtils.cp_r(orig, src)
  
  src.gsub! /^#{tmp}\/downloads\//, ""
  
  response.headers['Content-Type'] = "application/x-gzip"
  response.headers['Content-Disposition'] =
    "attachment; filename=#{params["filename"]}.hex"
  response.headers['X-Accel-Redirect'] = "/export/#{src}"
end

post '/:compiler/:action' do |compiler, action|
  
  save_session(params[:hashcode], params) if params[:hashcode]
  
  case action
  when "typecheck"
  when "compile"
  when "run"
  when "download"
    return download_project params
  when "download-exe"
    return download_exe params
  when "save"
    content_type :json
    return {status:0,output:"Saved Successfully!"}.to_json
  else
    raise Sinatra::NotFound
  end
  
  status, res = atscc_jailed params
  
  content_type :json
  {status: status, output: res}.to_json
end

get '/application.js' do
  coffee :application
end

get '/tour.js' do
  coffee :tour
end

get '/editor.js' do
  coffee :editor
end

get '/external.js' do
  coffee :external
end

get %r{^/(ats|repos)??/?$} do
  cache_control :public, max_age:"86400"
  haml :index
end

get "/code/:compiler" do |compiler|
  hash = get_new_hashcode
  redirect "/code/#{compiler}/#{hash}"
end

put "/code/:compiler" do |compiler|
  hash = get_new_hashcode
  save_session hash, params
  redirect "/code/#{compiler}/#{hash}"
end

get "/code/:compiler/:hash" do |compiler,hash|
  @session = retrieve_session hash
  actions = []
  canned = ""
  title = ""
  download_binary = false
  download_binary_label = ""

  case compiler
  when "ats"
    title = "ATS"
    canned = @session["input"] ||  open("config/helloworld.dats").read()
    actions = ["typecheck","compile","run","save"]
  when "avrats"
    title = "AVR ATS"
    canned = @session["input"] || open("config/blinkey.dats").read()
    actions = ["typecheck", "compile", "save"]
    @session["arch"] = "avr"
    download_binary = true
    download_binary_label = "Download Hex"
  when "patsopt"
    title = "ATS2"
    canned = @session["input"] || open("config/fibonacci.dats").read()
    actions = ["typecheck", "save"]
  else 
    raise Sinatra::NotFound
  end
  
  download = actions.include? "compile"

  haml :code, locals: {
    hash: hash,
    compiler: compiler,
    actions: actions,
    canned: canned,
    title: title,
    download: download,
    download_binary: download_binary,
    download_binary_label: download_binary_label,
    arch: @session["arch"] || "x86_64",
    runtime_flags: @session["runtime_flags"] || [],
    compile_flags: @session["compile_flags"] || [],
    filename: @session["filename"]
  }
end

get "/tour" do
  haml :tour
end

get "/search" do
  cache_control :public, max_age:"600"
  limit = 20

  solr = RSolr.connect url: "http://localhost:8983/solr"
  
  fq = params["indexes"].split(" ").map { |i| "repository:#{i}"} || []

  results = solr.get "select", params: {
    q: params["query"], fq: fq.join(" OR "), fl: "filename", 
    start: params["offset"], rows: limit, sort: "filename asc"
  }
  
  if results["responseHeader"]["status"] != 0
    raise Sinatra::NotFound
  end

  # $sphinx.offset = params["offset"] if params["offset"]
  # results = $sphinx.query(params["query"], params["indexes"])

  haml :search_results, layout: false, locals: {
    results: results, limit:limit
  }
end

get %r{^/(download/)?(ats|repos)/(.*?)/(.*)} do |dflag,folder,repo,path|
  cache_control :public, max_age:"600"
  @repos = [repo]
  match = $repos.select {|name,attr| name == repo}
  @repos << match[repo]["ats"] if !match.empty?
  @rel_path = [folder,repo,path].join("/")
  
  error = case folder
          when "ats"
            !($ats.include? repo)
          when "repos"
            match.empty?
          end
  
  base = Dir.new [folder,repo].join("/")
  
  if !( !error && File.exists?(@rel_path) \
        && base.contains?(@rel_path) )
    raise Sinatra::NotFound
  end
  
  return lxr_send_file @rel_path, false if dflag

  return listing_of_directory(@rel_path) if File.directory? @rel_path
  
  if !path.match(/\.(dats|sats)/)
    return lxr_send_file @rel_path
  end
  
  src = make_xref folder, repo, path
  haml :ats_source, locals:{ 
    source: src,
    title: path
  }
end
