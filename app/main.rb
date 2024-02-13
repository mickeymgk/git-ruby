require 'zlib'
require 'digest'
require 'fileutils'
require 'time'
# You can use print statements as follows for debugging, they'll be visible when running tests.
# puts "Logs from your program will appear here!"

# Uncomment this block to pass the first stage

def write_object(object, type: "blob")
  content_to_write = format("%s %d\x00%s", type, object.bytesize, object)
  sha = Digest::SHA1.hexdigest(content_to_write)
  object_path = File.join(".git", "objects", sha[0..1], sha[2..])
  FileUtils.mkdir_p(File.dirname(object_path))
  FileUtils.rm_f(object_path) if File.exist?(object_path)
  File.write(object_path, Zlib::Deflate.deflate(content_to_write))
  sha
end

def write_tree(dir = ".")
  children = Dir.children(dir) - [".git", ".ruby-lsp"]
  tree_content = children.sort.map do |child|
    child_path = File.join(dir, child)
    stat = File.stat(child_path)
    if stat.directory?
      content = [write_tree(child_path)].pack("H*")
      object_mode = "40000"
    elsif stat.executable?
      content = [write_object(File.read(child_path))].pack("H*")
      object_mode = "100755"
    else
      content = [write_object(File.read(child_path))].pack("H*")
      object_mode = "100644"
    end
    format("%s %s\x00%s", object_mode, child, content)
  end.join("")
  write_object(tree_content, type: "tree")
end

command = ARGV[0]
case command
when "init"
  Dir.mkdir(".git")
  Dir.mkdir(".git/objects")
  Dir.mkdir(".git/refs")
  File.write(".git/HEAD", "ref: refs/heads/master\n")
  puts "Initialized git directory"
when "cat-file"
  object_hash = ARGV[2]
  path = ".git/objects/#{object_hash[0,2]}/#{object_hash[2,38]}"
  compressed = File.read(path)
  uncompressed = Zlib::Inflate.inflate(compressed)
  header, content = uncompressed.split("\0")
  print content
when "hash-object"
  file = ARGV[ARGV.length - 1]
  content = File.read(file)
  header = "blob #{content.bytesize}\0"
  sha1 = Digest::SHA1.hexdigest(header + content)
  puts sha1
  zlib_content = Zlib::Deflate.deflate(header + content)
  Dir.mkdir(".git/objects/#{sha1[0,2]}")
  File.write(".git/objects/#{sha1[0,2]}/#{sha1[2,38]}", "#{zlib_content}\n")
when "ls-tree"
  option = ARGV[1]
  tree_sha = ARGV[2]
  path = File.join(".git", "objects", tree_sha[0..1], tree_sha[2..-1])
  blob = IO.binread(path)
  uncompressed = Zlib::Inflate.inflate(blob)
  content = uncompressed.split("\0")
  content.each_with_index do |d, i|
    file = d.scan(/[a-zA-Z]+$/)
    puts file
  end
when "write-tree"
  puts write_tree('.')
when "commit-tree"
  tree_sha = ARGV[1]
  parent_commit_sha = nil
  message = nil

  i = 2
  while i < ARGV.length
    case ARGV[i]
    when "-p"
      parent_commit_sha = ARGV[i + 1]
      i += 2
    when "-m"
      message = ARGV[i + 1]
      i += 2
    else
      raise ArgumentError.new("Invalid argument: #{ARGV[i]}")
    end
  end

  author_name = "Your Name"
  author_email = "your.email@example.com"
  committer_name = "Your Name"
  committer_email = "your.email@example.com"
  timestamp = Time.now.to_i

  parent_info = parent_commit_sha ? "-p #{parent_commit_sha}" : ""
  message_info = "-m \"#{message}\""

  commit_content = "tree #{tree_sha}\n"
  commit_content += "parent #{parent_commit_sha}\n" if parent_commit_sha
  commit_content += "author #{author_name} <#{author_email}> #{timestamp} +0000\n"
  commit_content += "committer #{committer_name} <#{committer_email}> #{timestamp} +0000\n"
  commit_content += "\n#{message}\n"

  commit_sha = write_object(commit_content, type: "commit")
  puts commit_sha
when "clone"
  url = ARGV[1]
  directory = ARGV[2]
  system("git clone #{url} #{directory}")
else
  raise RuntimeError.new("Unknown command #{command}")
end
