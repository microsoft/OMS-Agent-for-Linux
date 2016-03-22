require 'cgi'
fileName = ARGV[0]
xmlStr = File.read(fileName)
xmlUnescaped = CGI::unescapeHTML(xmlStr)
puts CGI::pretty(xmlUnescaped)