task :default => :index_repositories

task :index_repositories do
  index = FileList['repos/*','ats/*']
  index.each do |i|
    ruby "lib/index.rb", i, File.basename(i)
  end
end
