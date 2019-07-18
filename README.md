RIMS::RFC822
============

Fast parser for a RFC822 formatted message.
This gem is a component of RIMS (Ruby IMap Server), but can be used
independently of RIMS.

Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'rims-rfc822'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rims-rfc822

Usage
-----

```ruby
require 'rims/rfc822'

msg = RIMS::RFC822::Message.new(your_rfc822_text)

p msg.header
p msg.body

# header fields
p msg.header[name]
p msg.header.fetch_upcase(name)
p msg.header.field_value_list(name)
p msg.header.empty?
p msg.header.key? name
p msg.header.keys
msg.header.each_key do |name|
  p name
end
msg.header.each_pair do |name, value|
  p [ name, value ]
end

# source text attributes
p msg.raw_source
p msg.header.raw_source
p msg.body.raw_source

# type attributes
p msg.media_main_type
p msg.media_sub_type
p msg.media_subtype # alias of media_sub_type
p msg.content_type
p msg.content_type_parameter(name)
p msg.content_type_parameter_list
p msg.charset
p msg.boundary
p msg.content_disposition
p msg.content_disposition_parameter(name)
p msg.content_disposition_parameter_list
p msg.content_language

# header attributes
p msg.date
p msg.from
p msg.sender
p msg.reply_to
p msg.to
p msg.cc
p msg.bcc

# body structure attributes
p msg.text?
p msg.multipart?
p msg.message?
p msg.parts
p msg.message

# MIME header and body attributes
p msg.mime_decoded_header(name)
p msg.mime_decoded_header(name, decode_charset)
p msg.mime_decoded_header_field_value_list(name)
p msg.mime_decoded_header_field_value_list(name, decode_charset)
p msg.mime_decoded_header_text
p msg.mime_decoded_header_text(decode_charset)
p msg.mime_charset_body_text
p msg.mime_charset_body_text(charset)
p msg.mime_binary_body_string
```

Contributing
------------

Bug reports and pull requests are welcome on GitHub at <https://github.com/y10k/rims-rfc822>.

License
-------

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
