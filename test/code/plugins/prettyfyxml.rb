# Small utility to help debug the change tracking inventory xml
# Input : The file path to the inventory XML
# Output : Prints the formatted xml to stdout
# Ex usage : ruby test/code/plugins/prettyfyxml.rb ../test/code/plugins/Inventory.xml > test/code/plugins/Inventory-pretty.xml

require 'cgi'
fileName = ARGV[0]
xmlStr = File.read(fileName)
xmlUnescaped = CGI::unescapeHTML(xmlStr)
puts CGI::pretty(xmlUnescaped)
