# This allows WEBrick to handle pipe symbols in query parameters
URI::DEFAULT_PARSER =
    URI::Parser.new(UNRESERVED: URI::REGEXP::PATTERN::UNRESERVED + '|')