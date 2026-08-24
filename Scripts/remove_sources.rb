#!/usr/bin/env ruby
# Removes Swift source files from the Xcode project: drops the
# PBXFileReference and every build-phase entry that points at it.
#
#   ruby Scripts/remove_sources.rb Mozaic/Moodboard/renderBoard.swift
#
# Args: <file paths...>
# Idempotent: a file the project doesn't reference is skipped.
# Does not touch the file on disk -- delete it separately.
require "xcodeproj"

files = ARGV
abort "usage: remove_sources.rb <files...>" if files.empty?

project = Xcodeproj::Project.open("Mozaic.xcodeproj")

removed = []
files.each do |path|
  basename = File.basename(path)
  refs = project.files.select { |f| f.display_name == basename }

  if refs.empty?
    puts "  = #{basename} (not in project)"
    next
  end

  refs.each(&:remove_from_project)
  removed << basename
end

project.save
puts removed.empty? ? "no changes" : "removed: #{removed.join(', ')}"
