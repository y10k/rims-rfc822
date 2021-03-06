# -*- coding: utf-8 -*-

require 'pp' if $DEBUG
require 'rims/rfc822'
require 'test/unit'

module RIMS::Test
  class RFC822ParseTest < Test::Unit::TestCase
    def assert_strenc_equal(expected_enc, expected_str, expr_str)
      assert_equal([ Encoding.find(expected_enc), expected_str.dup.force_encoding(expected_enc) ],
                   [ expr_str.encoding,           expr_str                                      ])
    end
    private :assert_strenc_equal

    data('head_body_crlf' => [
	   "Content-Type: text/plain\r\n" +
	   "Subject: test\r\n" +
	   "\r\n" +
	   "HALO\r\n",

           "Content-Type: text/plain\r\n" +
           "Subject: test\r\n" +
           "\r\n",

           "HALO\r\n"
         ],
         'head_body_lf' => [
	   "Content-Type: text/plain\n" +
	   "Subject: test\n" +
	   "\n" +
	   "HALO\n",

           "Content-Type: text/plain\n" +
           "Subject: test\n" +
           "\n",

           "HALO\n"
         ],
         'head_body_cr' => [
	   "Content-Type: text/plain\r" +
	   "Subject: test\r" +
	   "\r" +
	   "HALO\r",

           "Content-Type: text/plain\r" +
           "Subject: test\r" +
           "\r",

           "HALO\r"
         ],
         'head_only' => [
	   "Content-Type: text/plain\r\n" +
	   "Subject: test\r\n" +
	   "\r\n",

	   "Content-Type: text/plain\r\n" +
	   "Subject: test\r\n" +
	   "\r\n",

           ''
         ],
         'body_only' => [
           "HALO\r\n",

           nil,

           "HALO\r\n"
         ])
    def test_split_message(data)
      message, expected_header, expected_body = data
      header, body = RIMS::RFC822::Parse.split_message(message.b)

      if (expected_header) then
        assert_strenc_equal('ascii-8bit', expected_header, header)
      else
        assert_nil(header)
      end

      if (expected_body) then
        assert_strenc_equal('ascii-8bit', expected_body, body)
      else
        assert_nil(body)
      end
    end

    data('empty' => [ '', [] ],
         'header' => [
           "Content-Type: text/plain; charset=utf-8\r\n" +
           "Subject: This is a test\r\n" +
           "\r\n",
           [ [ 'Content-Type', 'text/plain; charset=utf-8' ],
             [ 'Subject', 'This is a test' ]
           ]
         ],
         'header_lf' => [
           "Content-Type: text/plain; charset=utf-8\n" +
           "Subject: This is a test\n" +
           "\n",
           [ [ 'Content-Type', 'text/plain; charset=utf-8' ],
             [ 'Subject', 'This is a test' ]
           ]
         ],
         'header_cr' => [
           "Content-Type: text/plain; charset=utf-8\r" +
           "Subject: This is a test\r" +
           "\r",
           [ [ 'Content-Type', 'text/plain; charset=utf-8' ],
             [ 'Subject', 'This is a test' ]
           ]
         ],
         'header_no_last_empty_line' => [
           "Content-Type: text/plain; charset=utf-8\r\n" +
           "Subject: This is a test\r\n",
           [ [ 'Content-Type', 'text/plain; charset=utf-8' ],
             [ 'Subject', 'This is a test' ]
           ]
         ],
         'header_no_last_crlf' => [
           "Content-Type: text/plain; charset=utf-8\r\n" +
           "Subject: This is a test",
           [ [ 'Content-Type', 'text/plain; charset=utf-8' ],
             [ 'Subject', 'This is a test' ]
           ]
         ],
         'header_long_field' => [
           "Content-Type:\r\n" +
           " text/plain;\r\n" +
           " charset=utf-8\r\n" +
           "Subject: This\n" +
           " is a test\r\n" +
           "\r\n",
           [ [ 'Content-Type', "text/plain;\r\n charset=utf-8" ],
             [ 'Subject', "This\n is a test" ]
           ]
         ],
         'no_field_value'                   => [ 'test:', [ [ 'test', '' ] ] ],
         'ignore_illegal_format'            => [ 'foo', [] ],
         'ignore_too_many_field_dseparator' => [ 'foo:bar:baz', [ %w[ foo bar:baz ] ] ])
    def test_parse_header(data)
      header, expected_field_pair_list = data
      field_pair_list = RIMS::RFC822::Parse.parse_header(header.b)

      assert_equal(expected_field_pair_list.length, field_pair_list.length)
      expected_field_pair_list.zip(field_pair_list).zip do |expected_field_pair, field_pair|
        assert_equal(2, field_pair.length)
        assert_strenc_equal('ascii-8bit', expected_field_pair[0], field_pair[0])
        assert_strenc_equal('ascii-8bit', expected_field_pair[1], field_pair[1])
      end
    end

    data('raw:empty'                            => [ '',                        ''              ],
         'raw:string'                           => [ 'Hello world.',            'Hello world.'  ],
         'raw:escape_specials'                  => [ "\\\" \\( \\) \\\\",       "\" ( ) \\"     ],
         'quote:empty'                          => [ '""',                      ''              ],
         'quote:string'                         => [ '"Hello world."',          'Hello world.'  ],
         'quote:escape_specials'                => [ "\"foo \\\"bar\\\" baz\"", 'foo "bar" baz' ],
         'quote:comment'                        => [ '"foo (bar) baz"',         'foo (bar) baz' ],
         'comment:empty'                        => [ '()',                      ''              ],
         'comment:string'                       => [ '(Hello world.)',          ''              ],
         'comment:escape_specials'              => [ "( \" \\( \\) \\\\ )",     ''              ],
         'ignore_wrongs:escape_char'            => [ "\\",                      ''              ],
         'ignore_wrongs:quoted_str_not_ended'   => [ '"foo',                    'foo'           ],
         'ignore_wrongs:quoted_str_not_started' => [ 'foo"',                    'foo'           ],
         'ignore_wrongs:escape_char_in_quote'   => [ %Q'"foo\\',                'foo'           ],
         'ignore_wrongs:comment_not_ended'      => [ '(foo',                    ''              ],
         'ignore_wrongs:escape_char_in_comment' => [ '(foo',                    ''              ])
    def test_unquote_phrase(data)
      quoted_phrase, expected_unquoted_phrase = data
      assert_strenc_equal('ascii-8bit', expected_unquoted_phrase, RIMS::RFC822::Parse.unquote_phrase(quoted_phrase.b))
    end

    data('empty' => [
           '',
           {}
         ],
         'charset' => [
           ' charset=utf-8',
           { 'charset' => %w[ charset utf-8 ] }
         ],
         'upcases' => [
           ' CHARSET=utf-8',
           { 'charset' => %w[ CHARSET utf-8 ] }
         ],
         'ignore_spaces' => [
           ' charset =	utf-8 ',
           { 'charset' => %w[ charset utf-8 ] }
         ],
         'quoted' => [
           ' x-halo=" Hello world. "',
           { 'x-halo' => [ 'x-halo', ' Hello world. ' ] }
         ],
         'some_params' => [
           ' CHARSET=UTF-8; Foo = apple; Bar="banana"',
           { 'charset' => %w[ CHARSET UTF-8 ],
             'foo'     => %w[ Foo apple ],
             'bar'     => %w[ Bar banana ]
           }
         ],
         'no_spaces' => [
           'CHARSET=UTF-8;Foo=apple;Bar="banana"',
           { 'charset' => %w[ CHARSET UTF-8 ],
             'foo'     => %w[ Foo apple ],
             'bar'     => %w[ Bar banana ]
           }
         ],
         'extra_sep' => [
           ' CHARSET=UTF-8;; ; Foo = apple; Bar="banana";',
           { 'charset' => %w[ CHARSET UTF-8 ],
             'foo'     => %w[ Foo apple ],
             'bar'     => %w[ Bar banana ]
           }
         ],
         'boundary' => [
           ' boundary=----=_Part_1459890_1462677911.1383882437398',
           { 'boundary' => %w[ boundary ----=_Part_1459890_1462677911.1383882437398 ] }
         ],
         'multilines' => [
           "\r\n" +
           "	boundary=\"----=_Part_1459891_982342968.1383882437398\"",
           { 'boundary' => %w[ boundary ----=_Part_1459891_982342968.1383882437398 ] }
         ])
    def test_parse_parameters(data)
      parameters_txt, expected_params = data
      params = RIMS::RFC822::Parse.parse_parameters(parameters_txt.b)

      assert_equal(expected_params, params)
      for normalized_name, (name, value) in params
        assert_equal(Encoding::ASCII_8BIT, normalized_name.encoding, normalized_name)
        assert_equal(Encoding::ASCII_8BIT, name.encoding, name)
        assert_equal(Encoding::ASCII_8BIT, value.encoding, value)
      end
    end

    data('text' => [
           'text/plain',
           [ 'text', 'plain', {} ]
         ],
         'text_charset' => [
           'text/plain; charset=utf-8',
           [ 'text', 'plain',
             { 'charset' => %w[ charset utf-8 ] }
           ]
         ],
         'multipart_boundary' => [
           "multipart/alternative; \r\n" +
           "	boundary=----=_Part_1459891_982342968.1383882437398",
           [ 'multipart', 'alternative',
             { 'boundary' => %w[ boundary ----=_Part_1459891_982342968.1383882437398 ] }
           ]
         ],
         'empty' => [
           '',
           [ 'text', 'plain', {} ]
         ])
    def test_parse_content_type(data)
      header_field, expected_content_type = data
      content_type = RIMS::RFC822::Parse.parse_content_type(header_field.b)
      assert_equal(expected_content_type, content_type)

      main_type, sub_type, params = content_type
      assert_equal(Encoding::ASCII_8BIT, main_type.encoding, main_type)
      assert_equal(Encoding::ASCII_8BIT, sub_type.encoding, sub_type)
      for normalized_name, (name, value) in params
        assert_equal(Encoding::ASCII_8BIT, normalized_name.encoding, normalized_name)
        assert_equal(Encoding::ASCII_8BIT, name.encoding, name)
        assert_equal(Encoding::ASCII_8BIT, value.encoding, value)
      end
    end

    data('inline' => [
           'inline',
           [ 'inline', {} ]
         ],
         'filename' => [
           'attachment; filename=genome.jpeg',
           [ 'attachment',
             { 'filename' => %w[ filename genome.jpeg ] }
           ]
         ],
         'some_params' => [
           %Q'attachment; filename=genome.jpeg;\r\n' +
           %Q'  modification-date="Wed, 12 Feb 1997 16:29:51 -0500";',
           [ 'attachment',
             { 'filename'          => [ 'filename', 'genome.jpeg' ],
               'modification-date' => [ 'modification-date', 'Wed, 12 Feb 1997 16:29:51 -0500' ],
             }
           ]
         ],
         'empty' => [
           '',
           [ nil, {} ]
         ])
    def test_parse_content_disposition(data)
      header_field, expected_content_disposition = data
      content_disposition = RIMS::RFC822::Parse.parse_content_disposition(header_field.b)
      assert_equal(expected_content_disposition, content_disposition)

      type, params = content_disposition
      assert_equal(Encoding::ASCII_8BIT, type.encoding, type) if type
      for normalized_name, (name, value) in params
        assert_equal(Encoding::ASCII_8BIT, normalized_name.encoding, normalized_name)
        assert_equal(Encoding::ASCII_8BIT, name.encoding, name)
        assert_equal(Encoding::ASCII_8BIT, value.encoding, value)
      end
    end

    data('simple'        => [ 'da',       %w[ da ]    ],
         'multiple'      => [ 'mi, en',   %w[ mi en ] ],
         'ignore_spaces' => [ '  da ',    %w[ da ]    ],
         'no_spaces'     => [ 'mi,en',    %w[ mi en ] ],
         'extra_sep'     => [ 'mi,, en,', %w[ mi en ] ],
         'empty'         => [ '',           []        ])
    def test_parse_content_language(data)
      header_field, expected_tag_list = data
      tag_list = RIMS::RFC822::Parse.parse_content_language(header_field.b)
      assert_equal(expected_tag_list, tag_list)

      for tag in tag_list
        assert_equal(Encoding::ASCII_8BIT, tag.encoding, tag)
      end
    end

    def test_parse_multipart_body
      body_txt = <<-'MULTIPART'.b
------=_Part_1459890_1462677911.1383882437398
Content-Type: multipart/alternative; 
	boundary="----=_Part_1459891_982342968.1383882437398"

------=_Part_1459891_982342968.1383882437398
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
------=_Part_1459891_982342968.1383882437398
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=

------=_Part_1459891_982342968.1383882437398--

------=_Part_1459890_1462677911.1383882437398--
      MULTIPART

      part_list = RIMS::RFC822::Parse.parse_multipart_body('----=_Part_1459890_1462677911.1383882437398'.b, body_txt)
      assert_equal(1, part_list.length)
      assert_strenc_equal('ascii-8bit', <<-'PART', part_list[0])
Content-Type: multipart/alternative; 
	boundary="----=_Part_1459891_982342968.1383882437398"

------=_Part_1459891_982342968.1383882437398
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
------=_Part_1459891_982342968.1383882437398
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=

------=_Part_1459891_982342968.1383882437398--
      PART

      header_txt, body_txt = RIMS::RFC822::Parse.split_message(part_list[0])
      type_txt = RIMS::RFC822::Parse.parse_header(header_txt).find{|n, v| n == 'Content-Type' }[1]
      boundary = RIMS::RFC822::Parse.parse_content_type(type_txt)[2]['boundary'][1]

      part_list = RIMS::RFC822::Parse.parse_multipart_body(boundary, body_txt)
      assert_equal(2, part_list.length)
      assert_strenc_equal('ascii-8bit', <<-'PART1'.chomp, part_list[0])
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
      PART1
      assert_strenc_equal('ascii-8bit', <<-'PART2', part_list[1])
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=
      PART2
    end

    def test_parse_multipart_body_bad_format
      assert_equal(%w[ foo bar baz ], RIMS::RFC822::Parse.parse_multipart_body('sep', <<-EOF))
--sep
foo
--sep
bar
--sep
baz
      EOF

      assert_equal([], RIMS::RFC822::Parse.parse_multipart_body('sep', <<-EOF))
--sep--
      EOF

      assert_equal([], RIMS::RFC822::Parse.parse_multipart_body('sep', 'detarame'))
      assert_equal([], RIMS::RFC822::Parse.parse_multipart_body('sep', ''))
    end

    data('local_part@domain:empty' => [
           '',
           []
         ],
         'local_part@domain:normal' => [
           'toki@freedom.ne.jp',
           [ RIMS::RFC822::Address.new(nil,  nil, 'toki', 'freedom.ne.jp') ]
         ],
         'local_part@domain:ignore_spaces' => [
           ' toki@freedom.ne.jp ',
           [ RIMS::RFC822::Address.new(nil,  nil, 'toki', 'freedom.ne.jp') ]
         ],
         'display_name:normal' => [
           'TOKI Yoshinori <toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('TOKI Yoshinori', nil, 'toki', 'freedom.ne.jp') ]
         ],
         'display_name:quoted' => [
           '"TOKI Yoshinori" <toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('TOKI Yoshinori', nil, 'toki', 'freedom.ne.jp') ]
         ],
         'display_name:ignore_comment' => [
           'TOKI(土岐) Yoshinori <toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('TOKI Yoshinori', nil, 'toki', 'freedom.ne.jp') ]
         ],
         'display_name:escape_spcial' => [
           'TOKI\,Yoshinori <toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('TOKI,Yoshinori', nil, 'toki', 'freedom.ne.jp') ]
         ],
         'display_name:quoted_specials' => [
           '"toki@freedom.ne.jp" <toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('toki@freedom.ne.jp', nil, 'toki', 'freedom.ne.jp') ]
         ],
         'route' => [
           'TOKI Yoshinori <@mail.freedom.ne.jp,@smtp.gmail.com:toki@freedom.ne.jp>',
           [ RIMS::RFC822::Address.new('TOKI Yoshinori', '@mail.freedom.ne.jp,@smtp.gmail.com', 'toki', 'freedom.ne.jp') ]
         ],
         'list:normal' => [
           'toki: toki@freedom.ne.jp, TOKI Yoshinori <toki@freedom.ne.jp>, TOKI Yoshinori <@mail.freedom.ne.jp,@smtp.gmail.com:toki@freedom.ne.jp>;',
           [ RIMS::RFC822::Address.new(nil, nil, 'toki', nil),
             RIMS::RFC822::Address.new(nil, nil, 'toki', 'freedom.ne.jp'),
             RIMS::RFC822::Address.new('TOKI Yoshinori', nil, 'toki', 'freedom.ne.jp'),
             RIMS::RFC822::Address.new('TOKI Yoshinori', '@mail.freedom.ne.jp,@smtp.gmail.com', 'toki', 'freedom.ne.jp'),
             RIMS::RFC822::Address.new(nil, nil, nil, nil)
           ]
         ],
         'list:multiline' => [
           "toki@freedom.ne.jp,\n" +
           "  TOKI Yoshinori <toki@freedom.ne.jp>\n" +
           "  , Yoshinori Toki <toki@freedom.ne.jp>  ",
           [ RIMS::RFC822::Address.new(nil, nil, 'toki', 'freedom.ne.jp'),
             RIMS::RFC822::Address.new('TOKI Yoshinori', nil, 'toki', 'freedom.ne.jp'),
             RIMS::RFC822::Address.new('Yoshinori Toki', nil, 'toki', 'freedom.ne.jp')
           ]
         ])
    def test_parse_mail_address_list(data)
      address_list_txt, expected_address_list = data
      address_list = RIMS::RFC822::Parse.parse_mail_address_list(address_list_txt.b)

      assert_equal(expected_address_list, address_list)
      address_list.each_with_index do |addr, i|
        for name, value in addr.to_h
          if (value) then
            assert_equal(Encoding::ASCII_8BIT, value.encoding, "address_list[#{i}].#{name}: #{value}")
          end
        end
      end
    end
  end

  class RFC822CharsetAliasesTest < Test::Unit::TestCase
    def setup
      @aliases = RIMS::RFC822::CharsetAliases.new
    end

    def add_aliases
      @aliases.add_alias('euc-jp', Encoding::EUCJP_MS)
      @aliases.add_alias('iso-2022-jp', Encoding::CP50221)
      @aliases.add_alias('shift_jis', Encoding::WINDOWS_31J)
      nil
    end
    private :add_aliases

    def test_empty
      assert_nil(@aliases['euc-jp'])
      assert_equal(true, @aliases.empty?)
      assert_equal(0, @aliases.size)
      assert_equal(false, (@aliases.key? 'euc-jp'))
      assert_equal([], @aliases.keys)
      assert_equal([], @aliases.each_key.to_a)
      assert_equal([], @aliases.each_pair.to_a)
      assert_equal([], @aliases.each.to_a)
      assert_equal([], @aliases.to_a)
    end

    def test_values
      add_aliases
      assert_equal(Encoding::EUCJP_MS,    @aliases['euc-jp'])
      assert_equal(Encoding::CP50221,     @aliases['iso-2022-jp'])
      assert_equal(Encoding::WINDOWS_31J, @aliases['shift_jis'])
      assert_equal(false, @aliases.empty?)
      assert_equal(3, @aliases.size)
      assert_equal(true, (@aliases.key? 'euc-jp'))
      assert_equal(true, (@aliases.key? 'iso-2022-jp'))
      assert_equal(true, (@aliases.key? 'shift_jis'))
      assert_equal(%w[ EUC-JP ISO-2022-JP SHIFT_JIS ], @aliases.keys)
      assert_equal(%w[ EUC-JP ISO-2022-JP SHIFT_JIS ], @aliases.each_key.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ],
                     [ 'SHIFT_JIS',   Encoding::WINDOWS_31J ]
                   ],
                   @aliases.each_pair.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ],
                     [ 'SHIFT_JIS',   Encoding::WINDOWS_31J ]
                   ],
                   @aliases.each.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ],
                     [ 'SHIFT_JIS',   Encoding::WINDOWS_31J ]
                   ],
                   @aliases.to_a)
    end

    data('downcase'  => 'shift_jis',
         'camelcase' => 'Shift_JIS',
         'upcase'    => 'SHIFT_JIS')
    def test_ignore_case(data)
      charset = data
      add_aliases
      assert_equal(Encoding::WINDOWS_31J, @aliases[charset])
    end

    data('downcase'  => 'shift_jis',
         'camelcase' => 'Shift_JIS',
         'upcase'    => 'SHIFT_JIS')
    def test_delete_alias(data)
      charset = data
      add_aliases
      assert_equal(Encoding::WINDOWS_31J, @aliases.delete_alias(charset))
      assert_equal(Encoding::EUCJP_MS, @aliases['euc-jp'])
      assert_equal(Encoding::CP50221,  @aliases['iso-2022-jp'])
      assert_nil(@aliases['shift_jis'])
      assert_equal(false, @aliases.empty?)
      assert_equal(2, @aliases.size)
      assert_equal(true,  (@aliases.key? 'euc-jp'))
      assert_equal(true,  (@aliases.key? 'iso-2022-jp'))
      assert_equal(false, (@aliases.key? 'shift_jis'))
      assert_equal(%w[ EUC-JP ISO-2022-JP ], @aliases.keys)
      assert_equal(%w[ EUC-JP ISO-2022-JP ], @aliases.each_key.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ]
                   ],
                   @aliases.each_pair.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ]
                   ],
                   @aliases.each.to_a)
      assert_equal([ [ 'EUC-JP',      Encoding::EUCJP_MS ],
                     [ 'ISO-2022-JP', Encoding::CP50221 ]
                   ],
                   @aliases.to_a)
    end
  end

  class RFC822CharsetTextTest < Test::Unit::TestCase
    data('no_charset' => [ "Hello world.\r\n".b, "Hello world.\r\n" ],
         'utf-8' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n", 'utf-8'
         ],
         'utf-8:ignore_case' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n", 'UTF-8'
         ],
         'utf-8:encoding' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n", Encoding::UTF_8
         ],
         'base64' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "44GT44KT44Gr44Gh44GvDQo=\n", 'utf-8', 'base64'
         ],
         'base64:ignore_case' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "44GT44KT44Gr44Gh44GvDQo=\n", 'utf-8', 'BASE64'
         ],
         'base64:ignore_invalid_encoding' => [
           '',
           "\u3053\u3093\u306B\u3061\u306F\r\n", 'utf-8', 'base64'
         ],
         'quoted-printable' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF\r\n", 'utf-8', 'quoted-printable'
         ],
         'quoted-printable:ignore_case' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF\r\n", 'utf-8', 'QUOTED-PRINTABLE'
         ],
         'quoted-printable:ignore_invalid_encoding' => [
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n", 'utf-8', 'quoted-printable'
         ])
    def test_get_mime_charset_text(data)
      expected_text, binary_string, charset, transfer_encoding = data
      text = RIMS::RFC822::CharsetText.get_mime_charset_text(binary_string.b.freeze, charset, transfer_encoding)
      assert_equal(expected_text.encoding, text.encoding)
      assert_equal(expected_text, text)
    end

    def test_get_mime_charset_text_unknown_charset_error
      error = assert_raise(EncodingError) {
        RIMS::RFC822::CharsetText.get_mime_charset_text("Hello world.\r\n".b.freeze, 'x-nothing')
      }
      assert_match(/unknown/, error.message)
      assert_match(/x-nothing/, error.message)
    end

    def test_get_mime_charset_text_invalid_encoding_error
      error = assert_raise(EncodingError) {
        RIMS::RFC822::CharsetText.get_mime_charset_text("\xA4\xB3\xA4\xF3\xA4\xCB\xA4\xC1\xA4\xCF\r\n".b.freeze, 'utf-8')
      }
      assert_match(/invalid encoding/, error.message)
      assert_match(/#{Regexp.quote(Encoding::UTF_8.to_s)}/, error.message)
    end

    data('euc-jp'      => 'euc-jp',
         'iso-2022-jp' => 'iso-2022-jp',
         'shift_jis'   => 'Shift_JIS')
    def test_get_mime_charset_text_charset_alias(data)
      charset = data
      replaced_encoding = RIMS::RFC822::DEFAULT_CHARSET_ALIASES[charset] or flunk

      platform_dependent_character = "\u2460"
      assert_raise(Encoding::UndefinedConversionError) { platform_dependent_character.encode(charset) }

      text = RIMS::RFC822::CharsetText.get_mime_charset_text(platform_dependent_character.encode(replaced_encoding).b.freeze, charset)
      assert_equal(replaced_encoding, text.encoding)
      assert_equal(platform_dependent_character, text.encode('utf-8'))
    end

    iso_2022_jp_alias = RIMS::RFC822::DEFAULT_CHARSET_ALIASES['iso-2022-jp']
    no_aliases = RIMS::RFC822::CharsetAliases.new
    data('empty' => [
           ''.b,
           ''
         ],
         'plain_text' => [
           'Hello world.'.b,
           'Hello world.'
         ],
         'B-encoding' => [
           "\u3053\u3093\u306B\u3061\u306F".encode(iso_2022_jp_alias),
           '=?ISO-2022-JP?B?GyRCJDMkcyRLJEEkTxsoQg==?='
         ],
         'B-encoding:ignore_case' => [
           "\u3053\u3093\u306B\u3061\u306F".encode(iso_2022_jp_alias),
           '=?iso-2022-jp?b?GyRCJDMkcyRLJEEkTxsoQg==?='
         ],
         'Q-encoding' => [
           "Hello \u3053\u3093\u306B\u3061\u306F",
           '=?UTF-8?Q?Hello_=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF?='
         ],
         'Q-encoding:ignore_case' => [
           "Hello \u3053\u3093\u306B\u3061\u306F",
           '=?utf-8?q?Hello_=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF?='
         ],
         'encoded_word_with_plain_text' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?UTF-8?B?44GT44KT44Gr44Gh44Gv?= world."
         ],
         'encoded_word_with_plain_text:dummy_encoding' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.".encode(iso_2022_jp_alias),
           "Hello =?ISO-2022-JP?B?GyRCJDMkcyRLJEEkTxsoQg==?= world."
         ],
         'ignore_white_space_between_encoded_words' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?UTF-8?Q?=E3=81=93=E3=82=93?= \r\n    =?UTF-8?Q?=E3=81=AB=E3=81=A1=E3=81=AF?= world."
         ],
         'ignore_white_space_between_encoded_words:dummy_encoding' => [
           [ 'Hello ', "\u3053\u3093", "\u306B\u3061\u306F", ' world.' ].map{|s| s.encode(iso_2022_jp_alias) }.join(''),
           "Hello =?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= \r\n    =?ISO-2022-JP?B?GyRCJEskQSRPGyhC?= world."
         ],
         'multi_charset_encoded_words' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?UTF-8?Q?=E3=81=93=E3=82=93?= =?ISO-2022-JP?B?GyRCJEskQSRPGyhC?= world."
         ],
         'multi_charset_encoded_words:dummy_encoding' => [
           [ 'Hello ', "\u3053\u3093", "\u306B\u3061\u306F", ' world.' ].map{|s| s.encode(iso_2022_jp_alias) }.join(''),
           "Hello =?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?UTF-8?Q?=E3=81=AB=E3=81=A1=E3=81=AF?= world."
         ],
         'decode_charset' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?ISO-2022-JP?B?GyRCJEskQSRPGyhC?= world.", 'utf-8'
         ],
         'decode_charset:encoding_object' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?ISO-2022-JP?B?GyRCJEskQSRPGyhC?= world.", Encoding::UTF_8
         ],
         'decode_charset:alias_charset' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.".encode(iso_2022_jp_alias),
           "Hello =?UTF-8?B?44GT44KT44Gr44Gh44Gv?= world.", 'iso-2022-jp'
         ],
         'decode_charset:no_conversion' => [
           "Hello \u3053\u3093\u306B\u3061\u306F world.",
           "Hello =?UTF-8?Q?=E3=81=93=E3=82=93?= =?UTF-8?Q?=E3=81=AB=E3=81=A1=E3=81=AF?= world.", 'utf-8'
         ],
         'decode_charset:plain_text' => [
           'Hello world.',
           'Hello world.', 'utf-8'
         ],
         'decode_charset:plain_text_dummy_encoding' => [
           'Hello world.'.b,    # the reason: <dummy encoding empty string> + <ascii-8bit string> => <ascii-8bit string>
           'Hello world.', 'iso-2022-jp'
         ],
         'charset_convert_options' => [
           "A ? B".encode('iso-2022-jp'),
           "A =?UTF-8?B?4pGg?= B", 'iso-2022-jp', charset_aliases: no_aliases, charset_convert_options: { undef: :replace }
         ])
    def test_decode_mime_encoded_words(data)
      expected_text, encoded_string, *opt_args = data
      if (opt_args.last.is_a? Hash) then
        opt_kw_args = opt_args.pop
      else
        opt_kw_args = {}
      end
      text = RIMS::RFC822::CharsetText.decode_mime_encoded_words(encoded_string.b.freeze, *opt_args, **opt_kw_args)
      assert_equal(expected_text.encoding, text.encoding)
      assert_equal(expected_text, text)
    end

    def test_decode_mime_encoded_words_unknown_decode_charset_error
      error = assert_raise(ArgumentError) {
        RIMS::RFC822::CharsetText.decode_mime_encoded_words('Hello world.'.b.freeze, 'x-nothing')
      }
      assert_match(/unknown/, error.message)
      assert_match(/x-nothing/, error.message)
    end

    def test_decode_mime_encoded_words_invalid_encding_error
      error = assert_raise(EncodingError) {
        RIMS::RFC822::CharsetText.decode_mime_encoded_words('=?UTF-8?B?pLOk86TLpMGkzw==?='.b.freeze)
      }
      assert_match(/invalid encoding/, error.message)
      assert_match(/#{Regexp.quote(Encoding::UTF_8.to_s)}/, error.message)
    end
  end

  class RFC822HeaderTest < Test::Unit::TestCase
    def setup
      @header = RIMS::RFC822::Header.new("foo: apple\r\n" +
                                         "bar: Bob\r\n" +
                                         "Foo: banana\r\n" +
                                         "FOO: orange\r\n" +
                                         "\r\n")
      pp @header if $DEBUG
    end

    def teardown
      pp @header if $DEBUG
    end

    def test_fetch
      assert_equal('apple', @header['foo'])
      assert_equal('apple', @header['Foo'])
      assert_equal('apple', @header['FOO'])

      assert_equal('Bob', @header['bar'])
      assert_equal('Bob', @header['Bar'])
      assert_equal('Bob', @header['BAR'])

      assert_nil(@header['baz'])
      assert_nil(@header['Baz'])
      assert_nil(@header['BAZ'])
    end

    def test_fetch_upcase
      assert_equal('APPLE', @header.fetch_upcase('foo'))
      assert_equal('APPLE', @header.fetch_upcase('Foo'))
      assert_equal('APPLE', @header.fetch_upcase('FOO'))

      assert_equal('BOB', @header.fetch_upcase('bar'))
      assert_equal('BOB', @header.fetch_upcase('Bar'))
      assert_equal('BOB', @header.fetch_upcase('BAR'))

      assert_nil(@header.fetch_upcase('baz'))
      assert_nil(@header.fetch_upcase('Baz'))
      assert_nil(@header.fetch_upcase('BAZ'))
    end

    def test_field_value_list
      assert_equal(%w[ apple banana orange ], @header.field_value_list('foo'))
      assert_equal(%w[ apple banana orange ], @header.field_value_list('Foo'))
      assert_equal(%w[ apple banana orange ], @header.field_value_list('FOO'))

      assert_equal(%w[ Bob ], @header.field_value_list('bar'))
      assert_equal(%w[ Bob ], @header.field_value_list('Bar'))
      assert_equal(%w[ Bob ], @header.field_value_list('BAR'))

      assert_nil(@header.field_value_list('baz'))
      assert_nil(@header.field_value_list('Baz'))
      assert_nil(@header.field_value_list('BAZ'))
    end

    def test_empty?
      assert_equal(false, @header.empty?)
      assert_equal(true, RIMS::RFC822::Header.new('').empty?)
    end

    def test_key?
      assert_equal(true, (@header.key? 'foo'))
      assert_equal(true, (@header.key? 'Foo'))
      assert_equal(true, (@header.key? 'FOO'))

      assert_equal(true, (@header.key? 'bar'))
      assert_equal(true, (@header.key? 'Bar'))
      assert_equal(true, (@header.key? 'BAR'))

      assert_equal(false, (@header.key? 'baz'))
      assert_equal(false, (@header.key? 'Baz'))
      assert_equal(false, (@header.key? 'BAZ'))
    end

    def test_keys
      assert_equal(%w[ foo bar ], @header.keys)
    end

    def test_each_key
      assert_equal(%w[ foo bar ], @header.each_key.to_a)
    end

    def test_each_pair
      assert_equal([ %w[ foo apple ], %w[ bar Bob ], %w[ Foo banana ], %w[ FOO orange ] ],
                   @header.each_pair.to_a)
    end
  end

  class RFC822MessageTest < Test::Unit::TestCase
    def setup_message(headers={},
                      content_type: 'text/plain; charset=utf-8',
                      subject: 'test',
                      body: "Hello world.\r\n")
      src = headers.map{|n, v| "#{n}: #{v}\r\n" }.join('')
      src << "Content-Type: #{content_type}\r\n" if content_type
      src << "Subject: #{subject}\r\n" if subject
      src << "\r\n"
      src << body if body
      pp [ src.encoding, src ] if $DEBUG
      @msg = RIMS::RFC822::Message.new(src)
      pp @msg if $DEBUG
    end

    def teardown
      pp @msg if $DEBUG
    end

    def test_header
      setup_message
      assert_equal("Content-Type: text/plain; charset=utf-8\r\n" +
                   "Subject: test\r\n" +
                   "\r\n",
                   @msg.header.raw_source)
    end

    def test_body
      setup_message
      assert_equal("Hello world.\r\n", @msg.body.raw_source)
    end

    def test_media_main_type
      setup_message
      assert_equal('text', @msg.media_main_type)
      assert_equal('TEXT', @msg.media_main_type_upcase)
    end

    def test_media_sub_type
      setup_message
      assert_equal('plain', @msg.media_sub_type)
      assert_equal('PLAIN', @msg.media_sub_type_upcase)
    end

    def test_content_type
      setup_message
      assert_equal('text/plain', @msg.content_type)
      assert_equal('TEXT/PLAIN', @msg.content_type_upcase)
    end

    def test_content_type_parameter
      setup_message(content_type: 'text/plain; charset=utf-8; foo=apple; Bar=Banana')
      assert_equal('utf-8', @msg.content_type_parameter('charset'))
      assert_equal('apple', @msg.content_type_parameter('foo'))
      assert_equal('Banana', @msg.content_type_parameter('bar'))
      assert_nil(@msg.content_type_parameter('baz'))
      assert_equal([ %w[ charset utf-8 ], %w[ foo apple ], %w[ Bar Banana ] ], @msg.content_type_parameter_list)
    end

    def test_content_type_no_header
      setup_message(content_type: nil)
      assert_equal('text/plain', @msg.content_type)
      assert_nil(@msg.content_type_parameter('charset'))
      assert_equal([], @msg.content_type_parameter_list)
    end

    def test_charset
      setup_message
      assert_equal('utf-8', @msg.charset)
    end

    def test_charset_no_value
      setup_message(content_type: 'text/plain')
      assert_nil(@msg.charset)
    end

    def test_boundary
      setup_message(content_type: "multipart/alternative; \r\n	boundary=\"----=_Part_1459891_982342968.1383882437398\"")
      assert_equal('----=_Part_1459891_982342968.1383882437398', @msg.boundary)
    end

    def test_boundary_no_value
      setup_message
      assert_nil(@msg.boundary)
    end

    def test_content_disposition
      setup_message({ 'Content-Disposition' => 'inline' })
      assert_equal('inline', @msg.content_disposition)
      assert_equal('INLINE', @msg.content_disposition_upcase)
    end

    def test_content_disposition_parameter
      setup_message({ 'Content-Disposition' => 'attachment; filename=genome.jpeg; Modification-Date="Wed, 12 Feb 1997 16:29:51 -0500"' })
      assert_equal('genome.jpeg', @msg.content_disposition_parameter('filename'))
      assert_equal('Wed, 12 Feb 1997 16:29:51 -0500', @msg.content_disposition_parameter('modification-date'))
      assert_nil(@msg.content_disposition_parameter('size'))
      assert_equal([ [ 'filename', 'genome.jpeg' ],
                     [ 'Modification-Date', 'Wed, 12 Feb 1997 16:29:51 -0500' ]
                   ],
                   @msg.content_disposition_parameter_list)
    end

    def test_content_disposition_no_header
      setup_message
      assert_nil(@msg.content_disposition)
      assert_nil(@msg.content_disposition_upcase)
      assert_nil(@msg.content_disposition_parameter('filename'))
      assert_nil(@msg.content_disposition_parameter_list)
    end

    def test_content_language
      setup_message({ 'Content-Language' => 'mi, En' })
      assert_equal(%w[ mi En ], @msg.content_language)
      assert_equal(%w[ MI EN ], @msg.content_language_upcase)
    end

    def test_content_language_no_header
      setup_message
      assert_nil(@msg.content_language)
      assert_nil(@msg.content_language_upcase)
    end

    def test_text?
      setup_message
      assert_equal(true, @msg.text?)
    end

    def test_not_text?
      setup_message(content_type: 'application/octet-stream')
      assert_equal(false, @msg.text?)
    end

    def test_multipart?
      setup_message(content_type: 'multipart/mixed')
      assert_equal(true, @msg.multipart?)
    end

    def test_not_multipart?
      setup_message
      assert_equal(false, @msg.multipart?)
    end

    def test_parts
      setup_message(content_type: 'multipart/mixed; boundary="----=_Part_1459890_1462677911.1383882437398"', body: <<-'EOF')
------=_Part_1459890_1462677911.1383882437398
Content-Type: multipart/alternative; 
	boundary="----=_Part_1459891_982342968.1383882437398"

------=_Part_1459891_982342968.1383882437398
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
------=_Part_1459891_982342968.1383882437398
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=

------=_Part_1459891_982342968.1383882437398--

------=_Part_1459890_1462677911.1383882437398--
      EOF

      assert_equal(1, @msg.parts.length)
      assert_equal(<<-'EOF', @msg.parts[0].raw_source)
Content-Type: multipart/alternative; 
	boundary="----=_Part_1459891_982342968.1383882437398"

------=_Part_1459891_982342968.1383882437398
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
------=_Part_1459891_982342968.1383882437398
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=

------=_Part_1459891_982342968.1383882437398--
      EOF

      assert_equal(2, @msg.parts[0].parts.length)
      assert_equal(<<-'EOF'.chomp, @msg.parts[0].parts[0].raw_source)
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: base64

Cgo9PT09PT09PT09CkFNQVpPTi5DTy5KUAo9PT09PT09PT09CkFtYXpvbi5jby5qcOOBp+WVhuWT
rpvjgavpgIHkv6HjgZXjgozjgb7jgZfjgZ86IHRva2lAZnJlZWRvbS5uZS5qcAoKCg==
      EOF
      assert_equal(<<-'EOF', @msg.parts[0].parts[1].raw_source)
Content-Type: text/html; charset=UTF-8
Content-Transfer-Encoding: quoted-printable

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=
      EOF
    end

    def test_parts_not_multipart
      setup_message
      assert_nil(@msg.parts)
    end

    def test_parts_no_boundary
      setup_message(content_type: 'multipart/mixed')
      assert_equal([], @msg.parts)
    end

    def test_message?
      setup_message(content_type: 'message/rfc822')
      assert_equal(true, @msg.message?)
    end

    def test_not_message?
      setup_message
      assert_equal(false, @msg.message?)
    end

    def test_message
      setup_message(content_type: 'message/rfc822', body: <<-'EOF')
To: bar@nonet.com
From: foo@nonet.com
Subject: inner multipart
MIME-Version: 1.0
Date: Fri, 8 Nov 2013 19:31:03 +0900
Content-Type: multipart/mixed; boundary="1383.905529.351298"

--1383.905529.351298
Content-Type: text/plain; charset=us-ascii

Hello world.
--1383.905529.351298
Content-Type: application/octet-stream

9876543210
--1383.905529.351298--
      EOF

      assert_equal(<<-'EOF', @msg.message.raw_source)
To: bar@nonet.com
From: foo@nonet.com
Subject: inner multipart
MIME-Version: 1.0
Date: Fri, 8 Nov 2013 19:31:03 +0900
Content-Type: multipart/mixed; boundary="1383.905529.351298"

--1383.905529.351298
Content-Type: text/plain; charset=us-ascii

Hello world.
--1383.905529.351298
Content-Type: application/octet-stream

9876543210
--1383.905529.351298--
      EOF
      assert_equal(true, @msg.message.multipart?)
      assert_equal(2, @msg.message.parts.length)
      assert_equal('text/plain', @msg.message.parts[0].content_type)
      assert_equal('us-ascii', @msg.message.parts[0].charset)
      assert_equal('Hello world.', @msg.message.parts[0].body.raw_source)
      assert_equal('application/octet-stream', @msg.message.parts[1].content_type)
      assert_equal('9876543210', @msg.message.parts[1].body.raw_source)
    end

    def test_message_no_msg
      setup_message
      assert_nil(@msg.message)
    end

    def test_date
      setup_message({ 'Date' => 'Fri, 8 Nov 2013 03:47:17 +0000' })
      assert_equal(Time.utc(2013, 11, 8, 3, 47, 17), @msg.date)
    end

    def test_date_no_value
      setup_message
      assert_nil(@msg.date)
    end

    def test_date_bad_format
      setup_message({ 'Date' => 'no_date' })
      assert_equal(Time.at(0), @msg.date)
    end

    def test_mail_address_header_field
      setup_message({ 'From'     => 'Foo <foo@mail.example.com>',
                      'Sender'   => 'Bar <bar@mail.example.com>',
                      'Reply-To' => 'Baz <baz@mail.example.com>',
                      'To'       => 'Alice <alice@mail.example.com>',
                      'Cc'       => 'Bob <bob@mail.example.com>',
                      'Bcc'      => 'Kate <kate@mail.example.com>'
                    })

      assert_equal([ [ 'Foo', nil, 'foo', 'mail.example.com' ] ], @msg.from.map(&:to_a))
      assert_equal([ [ 'Bar', nil, 'bar', 'mail.example.com' ] ], @msg.sender.map(&:to_a))
      assert_equal([ [ 'Baz', nil, 'baz', 'mail.example.com' ] ], @msg.reply_to.map(&:to_a))
      assert_equal([ [ 'Alice', nil, 'alice', 'mail.example.com' ] ], @msg.to.map(&:to_a))
      assert_equal([ [ 'Bob', nil, 'bob', 'mail.example.com' ] ], @msg.cc.map(&:to_a))
      assert_equal([ [ 'Kate', nil, 'kate', 'mail.example.com' ] ], @msg.bcc.map(&:to_a))
    end

    def test_mail_address_header_field_multi_header_field
      setup_message([ [ 'From', 'Foo <foo@mail.example.com>, Bar <bar@mail.example.com>' ],
                      [ 'from', 'Baz <baz@mail.example.com>' ]
                    ])
      assert_equal([ [ 'Foo', nil, 'foo', 'mail.example.com' ],
                     [ 'Bar', nil, 'bar', 'mail.example.com' ],
                     [ 'Baz', nil, 'baz', 'mail.example.com' ]
                   ],
                   @msg.from.map(&:to_a))
    end

    def test_mail_address_header_field_no_value
      setup_message
      assert_nil(@msg.from)
    end

    def test_mail_address_header_field_bad_format
      setup_message({ 'From' => 'no_mail_address' })
      assert_equal([], @msg.from)
    end

    data('base64'           => '=?UTF-8?B?44GT44KT44Gr44Gh44Gv?=',
         'quoted-printable' => '=?UTF-8?Q?=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF?=')
    def test_mime_decoded_header(data)
      subject = data
      setup_message(subject: subject)
      assert_equal(Encoding::UTF_8, @msg.mime_decoded_header('Subject').encoding)
      assert_equal("\u3053\u3093\u306B\u3061\u306F", @msg.mime_decoded_header('Subject'))
    end

    def test_mime_decoded_header_decode_charset
      setup_message(subject: '=?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?EUC-JP?Q?=A4=CB=A4=C1=A4=CF?=')
      assert_equal(Encoding::UTF_8, @msg.mime_decoded_header('Subject', 'utf-8').encoding)
      assert_equal("\u3053\u3093\u306B\u3061\u306F", @msg.mime_decoded_header('Subject', 'utf-8'))
    end

    data('base64'           => '=?UTF-8?B?44GT44KT44Gr44Gh44Gv?=',
         'quoted-printable' => '=?UTF-8?Q?=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF?=')
    def test_mime_decoded_header_field_value_list(data)
      subject = data
      setup_message(subject: subject)
      assert_equal([ Encoding::UTF_8 ], @msg.mime_decoded_header_field_value_list('Subject').map(&:encoding))
      assert_equal([ "\u3053\u3093\u306B\u3061\u306F" ], @msg.mime_decoded_header_field_value_list('Subject'))
    end

    def test_mime_decoded_header_field_value_list_decode_charset
      setup_message(subject: '=?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?EUC-JP?Q?=A4=CB=A4=C1=A4=CF?=')
      assert_equal([ Encoding::UTF_8 ], @msg.mime_decoded_header_field_value_list('Subject', 'utf-8').map(&:encoding))
      assert_equal([ "\u3053\u3093\u306B\u3061\u306F" ], @msg.mime_decoded_header_field_value_list('Subject', 'utf-8'))
    end

    data('base64'           => '=?UTF-8?B?44GT44KT44Gr44Gh44Gv?=',
         'quoted-printable' => '=?UTF-8?Q?=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF?=')
    def test_mime_decoded_header_text(data)
      subject = data
      setup_message(subject: subject)
      assert_equal(Encoding::UTF_8, @msg.mime_decoded_header_text.encoding)
      assert_equal("Content-Type: text/plain; charset=utf-8\r\n" +
                   "Subject: \u3053\u3093\u306B\u3061\u306F\r\n" +
                   "\r\n",
                   @msg.mime_decoded_header_text)
    end

    def test_mime_decoded_header_text_decode_charset
      setup_message(subject: '=?ISO-2022-JP?B?GyRCJDMkcxsoQg==?= =?EUC-JP?Q?=A4=CB=A4=C1=A4=CF?=')
      assert_equal(Encoding::UTF_8, @msg.mime_decoded_header_text('utf-8').encoding)
      assert_equal("Content-Type: text/plain; charset=utf-8\r\n" +
                   "Subject: \u3053\u3093\u306B\u3061\u306F\r\n" +
                   "\r\n",
                   @msg.mime_decoded_header_text('utf-8'))
    end

    data('plain_text' => [
            {},
           'text/plain; charset=utf-8',
           "\u3053\u3093\u306B\u3061\u306F\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n"
         ],
         'base64' => [
           { 'Content-Transfer-Encoding' => 'base64' },
           'text/plain; charset=utf-8',
           "44GT44KT44Gr44Gh44GvDQo=\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n"
         ],
         'quoted-printable' => [
           { 'Content-Transfer-Encoding' => 'quoted-printable' },
           'text/plain; charset=utf-8',
           "=E3=81=93=E3=82=93=E3=81=AB=E3=81=A1=E3=81=AF\r\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n"
         ],
         'force_charset' => [
           { 'Content-Transfer-Encoding' => 'base64' },
           'text/plain', # no charset
           "GyRCJDMkcyRLJEEkTxsoQg0K\n",
           "\u3053\u3093\u306B\u3061\u306F\r\n".encode(Encoding::ISO_2022_JP),
           Encoding::ISO_2022_JP
         ],
         'not_text' => [
           {},
           'application/octet-stream',
           'foo',
           'foo'.b
         ],
         'not_text:ignore_charset' => [
           {},
           'application/octet-stream; charset=utf-8',
           'foo',
           'foo'.b
         ])
    def test_mime_charset_body_text(data)
      header, content_type, body, expected_text, *optional = data
      setup_message(header,
                    content_type: content_type,
                    body: body)

      assert_equal(expected_text.encoding, @msg.mime_charset_body_text(*optional).encoding)
      assert_equal(expected_text, @msg.mime_charset_body_text(*optional))

      assert_equal(Encoding::ASCII_8BIT, @msg.mime_binary_body_string.encoding)
      assert_equal(expected_text.b, @msg.mime_binary_body_string)
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
