#!/usr/bin/env ruby

require 'ebnf'

grammar = EBNF.parse(File.open('./turtle.ebnf'))

File.open(File.join("turtle.ebnfsxp"), 'w') do |file|
  file.write(grammar.to_sxp)
end

File.open(File.join("turtle.bnf"), 'w') do |file|
  file.write(grammar.make_bnf)
end

tables = grammar.build_tables
puts tables
