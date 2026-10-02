#!/usr/bin/env ruby
# Repoints a Swift source file's PBXFileReference after the file has been
# renamed on disk (with `git mv`), so the project keeps compiling it.
#
#   git mv Mozaic/inspector/bottomBar.swift Mozaic/inspector/BottomBar.swift
#   ruby Scripts/rename_source.rb Mozaic/inspector/bottomBar.swift Mozaic/inspector/BottomBar.swift
#
# Args: <old path> <new path>
# The new path must already exist on disk; the old one must not.
require "xcodeproj"

old_path, new_path = ARGV
abort "usage: rename_source.rb <old path> <new path>" unless new_path
abort "missing file: #{new_path}" unless File.exist?(new_path)

project = Xcodeproj::Project.open("Mozaic.xcodeproj")
old_name = File.basename(old_path)
refs = project.files.select { |f| f.display_name == old_name }
abort "no reference to #{old_name} in the project" if refs.empty?

refs.each { |ref| ref.set_path(File.expand_path(new_path)) }

project.save
puts "renamed #{old_name} -> #{File.basename(new_path)} (#{refs.count} reference(s))"
