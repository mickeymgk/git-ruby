require zlib
require 'digest'
# You can use print statements as follows for debugging, they'll be visible when running tests.
# puts "Logs from your program will appear here!"

# Uncomment this block to pass the first stage

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
else
  raise RuntimeError.new("Unknown command #{command}")
end
