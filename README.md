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

# source text attributes
p msg.raw_source
p msg.header.raw_source
p msg.body.raw_source

# type attributes
p msg.media_main_type
p msg.media_sub_type
p msg.content_type
p msg.content_type_parameters
p msg.charset
p msg.boundary

# headear attributes
p msg.date
p msg.from
p msg.sender
p msg.reply_to
p msg.to
p msg.cc
p msg.bcc

# content attributes
p msg.text?
p msg.multipart?
p msg.message?
p msg.parts
p msg.message
```

Contributing
------------

Bug reports and pull requests are welcome on GitHub at <https://github.com/y10k/rims-rfc822>.

License
-------

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
