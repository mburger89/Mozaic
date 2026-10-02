#!/usr/bin/env ruby
# Adds Swift source files to an Xcode target's compile phase.
#
#   ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/SmokeTests.swift
#
# Args: <target> <group path, slash separated> <file paths...>
# Idempotent: a file already in the target is skipped.
require "xcodeproj"

target_name, group_path, *files = ARGV
abort "usage: add_sources.rb <target> <group> <files...>" if files.empty?

project = Xcodeproj::Project.open("Mozaic.xcodeproj")
target  = project.targets.find { |t| t.name == target_name }
abort "no such target: #{target_name}" unless target

# Walk/create the group chain, e.g. "Mozaic/Document"
group = project.main_group
group_path.split("/").each do |name|
  group = group.find_subpath(name, true).tap { |g| g.set_source_tree("<group>") }
end

added = []
files.each do |path|
  abort "missing file: #{path}" unless File.exist?(path)
  basename = File.basename(path)

  existing = group.files.find { |f| f.display_name == basename }
  ref = existing || group.new_reference(File.expand_path(path))

  if target.source_build_phase.files_references.include?(ref)
    puts "  = #{basename} (already in #{target_name})"
    next
  end
  target.add_file_references([ref])
  added << basename
end

project.save
puts added.empty? ? "no changes" : "added to #{target_name}: #{added.join(', ')}"
