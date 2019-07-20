# -*- coding: utf-8; frozen_string_literal: true -*-

require 'forwardable'
require 'rims/rfc822/version'
require 'time'

module RIMS
  module RFC822
    module Parse
      def split_message(msg_txt)
        header_txt, body_txt = msg_txt.lstrip.split(/\r?\n\r?\n/, 2)
        if ($&) then
          header_txt << $&
        else
          body_txt = header_txt
          header_txt = nil
        end

        [ header_txt.freeze, body_txt.freeze ].freeze
      end
      module_function :split_message

      def parse_header(header_txt)
        field_pair_list = header_txt.scan(%r{
          ^
          ((?#name) \S+? )
          \s* : \s*
          (
             (?#value)
             .*? (?: \n|\z)
             (?: ^\s .*? (?: \n|\z) )*
          )
        }x)

        for name, value in field_pair_list
          value.strip!
          name.freeze
          value.freeze
        end

        field_pair_list.freeze
      end
      module_function :parse_header

      def unquote_phrase(phrase_txt)
        state = :raw
        src_txt = phrase_txt.dup
        dst_txt = ''.encode(phrase_txt.encoding)

        while (src_txt.sub!(/\A (?: " | \( | \) | \\ | [^"\(\)\\]+ )/x, ''))
          match_txt = $&
          case (state)
          when :raw
            case (match_txt)
            when '"'
              state = :quote
            when '('
              state = :comment
            when "\\"
              unless (src_txt.empty?) then
                dst_txt << src_txt[0]
                src_txt[0] = ''
              end
            else
              dst_txt << match_txt
            end
          when :quote
            case (match_txt)
            when '"'
              state = :raw
            when "\\"
              unless (src_txt.empty?) then
                dst_txt << src_txt[0]
                src_txt[0] = ''
              end
            else
              dst_txt << match_txt
            end
          when :comment
            case (match_txt)
            when ')'
              state = :raw
            when "\\"
              src_txt[0] = ''
            else
              # ignore comment text.
            end
          else
            raise "internal error - unknown state: #{state}"
          end
        end

        dst_txt.freeze
      end
      module_function :unquote_phrase

      def parse_parameters(parameters_txt)
        params = {}
        parameters_txt.scan(%r{
          (?<name> \S+? )
          \s* = \s*
          (?:
            (?<quoted_string> ".*?" ) |
            (?<token> \S+? )
          )
          \s*
          (?: ; | \Z )
        }x) do
          name = $~[:name]
          if ($~[:quoted_string]) then
            quoted_value = $~[:quoted_string]
            value = unquote_phrase(quoted_value)
          else
            value = $~[:token]
          end
          params[name.downcase.freeze] = [ name.freeze, value.freeze ].freeze
        end

        params.freeze
      end
      module_function :parse_parameters

      def split_parameters(type_params_txt)
        type, params_txt = type_params_txt.split(';', 2)
        if (type) then
          type.strip!
          type.freeze
          if (params_txt) then
            params = parse_parameters(params_txt)
          else
            params = {}.freeze
          end
          [ type, params ].freeze
        else
          [ nil, {}.freeze ].freeze
        end
      end
      module_function :split_parameters

      def parse_content_type(type_txt)
        media_type_txt, params = split_parameters(type_txt)
        if (media_type_txt) then
          main_type, sub_type = media_type_txt.split('/', 2)
          if (main_type) then
            main_type.strip!
            main_type.freeze
            if (sub_type) then
              sub_type.strip!
              sub_type.freeze
              if (! main_type.empty? && ! sub_type.empty?) then
                return [ main_type, sub_type, params ].freeze
              end
            end
          end
        end

        [ 'application'.dup.force_encoding(type_txt.encoding).freeze,
          'octet-stream'.dup.force_encoding(type_txt.encoding).freeze,
          params
        ].freeze
      end
      module_function :parse_content_type

      def parse_content_disposition(disposition_txt)
        split_parameters(disposition_txt)
      end
      module_function :parse_content_disposition

      def parse_content_language(language_tags_txt)
        tag_list = language_tags_txt.split(',')
        for tag in tag_list
          tag.strip!
          tag.freeze
        end
        tag_list.reject!(&:empty?)

        tag_list.freeze
      end
      module_function :parse_content_language

      def parse_multipart_body(boundary, body_txt)
        delim = '--' + boundary
        term = delim + '--'
        body_txt2, _body_epilogue_txt = body_txt.split(term, 2)
        if (body_txt2) then
          _body_preamble_txt, body_parts_txt = body_txt2.split(delim, 2)
          if (body_parts_txt) then
            part_list = body_parts_txt.split(delim, -1)
            for part_txt in part_list
              part_txt.lstrip!
              part_txt.chomp!("\n")
              part_txt.chomp!("\r")
              part_txt.freeze
            end
            return part_list.freeze
          end
        end

        [].freeze
      end
      module_function :parse_multipart_body

      Address = Struct.new(:display_name, :route, :local_part, :domain)
      class Address
        # compatible for Net::MAP::Address
        alias name display_name
        alias mailbox local_part
        alias host domain
      end

      def parse_mail_address_list(address_list_txt)
        addr_list = []
        src_txt = address_list_txt.dup

        while (true)
          if (src_txt.sub!(%r{
                \A
                \s*
                (?<display_name> \S.*? ) \s* : (?<group_list> .*? ) ;
                \s*
                ,?
              }x, ''))
          then
            display_name = $~[:display_name]
            group_list = $~[:group_list]
            addr_list << Address.new(nil, nil, unquote_phrase(display_name), nil).freeze
            addr_list.concat(parse_mail_address_list(group_list))
            addr_list << Address.new(nil, nil, nil, nil).freeze
          elsif (src_txt.sub!(%r{
                   \A
                   \s*
                   (?<local_part> [^<>@",\s]+ )
                   \s* @ \s*
                   (?<domain> [^<>@",\s]+ )
                   \s*
                   ,?
                 }x, ''))
          then
            addr_list << Address.new(nil, nil, $~[:local_part].freeze, $~[:domain].freeze).freeze
          elsif (src_txt.sub!(%r{
                   \A
                   \s*
                   (?<display_name> \S.*? )
                   \s*
                   <
                     \s*
                     (?:
                       (?<route>
                         @[^<>@",]*
                         (?:
                           , \s*
                           @[^<>@",]*
                         )*
                       )
                       \s*
                       :
                     )?
                     \s*
                     (?<local_part> [^<>@",\s]+ )
                     \s* @ \s*
                     (?<domain> [^<>@",\s]+ )
                     \s*
                   >
                   \s*
                   ,?
                 }x, ''))
          then
            display_name = $~[:display_name]
            route = $~[:route]
            local_part = $~[:local_part]
            domain = $~[:domain]
            addr_list << Address.new(unquote_phrase(display_name), route.freeze, local_part.freeze, domain.freeze).freeze
          else
            break
          end
        end

        addr_list.freeze
      end
      module_function :parse_mail_address_list
    end

    # for backward compatibility
    include Parse
    module_function :split_message
    module_function :parse_header
    module_function :unquote_phrase
    module_function :parse_parameters
    module_function :split_parameters
    module_function :parse_content_type
    module_function :parse_content_disposition
    module_function :parse_content_language
    module_function :parse_multipart_body
    module_function :parse_mail_address_list

    class CharsetAliases
      def initialize
        @alias_table = {}
      end

      # API methods

      def [](name)
        @alias_table[name.upcase]
      end

      def add_alias(name, encoding)
        @alias_table[name.upcase] = encoding
        self
      end

      def delete_alias(name)
        @alias_table.delete(name.upcase)
      end

      # minimal methods like `Hash'

      extend Forwardable
      include Enumerable

      def_delegators :@alias_table, :empty?, :size, :keys
      alias length size

      def key?(name)
        @alias_table.key? name.upcase
      end

      alias has_key? key?
      alias include? key?
      alias member? key?

      def each_key
        return enum_for(:each_key) unless block_given?
        @alias_table.each_key do |name|
          yield(name)
        end
        self
      end

      def each_pair
        return enum_for(:each_pair) unless block_given?
        @alias_table.each_pair do |name, encoding|
          yield(name, encoding)
        end
        self
      end

      alias each each_pair
    end

    DEFAULT_CHARSET_ALIASES = CharsetAliases.new
    #DEFAULT_CHARSET_ALIASES.add_alias('euc-jp', Encoding::CP51932)
    DEFAULT_CHARSET_ALIASES.add_alias('euc-jp', Encoding::EUCJP_MS)
    #DEFAULT_CHARSET_ALIASES.add_alias('iso-2022-jp', Encoding::CP50220)
    DEFAULT_CHARSET_ALIASES.add_alias('iso-2022-jp', Encoding::CP50221)
    DEFAULT_CHARSET_ALIASES.add_alias('shift_jis', Encoding::WINDOWS_31J)

    module CharsetText
      def self.find_string_encoding(name)
        begin
          Encoding.find(name)
        rescue ArgumentError
          raise EncodingError.new($!.to_s)
        end
      end

      def get_mime_charset_text(binary_string, charset, transfer_encoding=nil, charset_aliases: DEFAULT_CHARSET_ALIASES)
        case (transfer_encoding&.upcase)
        when 'BASE64'
          text = binary_string.unpack1('m')
        when 'QUOTED-PRINTABLE'
          text = binary_string.unpack1('M')
        else
          text = binary_string.dup
        end

        if (charset) then
          if (charset.is_a? Encoding) then
            enc = charset
          else
            enc = charset_aliases[charset] ||
                  CharsetText.find_string_encoding(charset) # raise `EncodingError' when wrong charset due to document
          end
          text.force_encoding(enc)
          text.valid_encoding? or raise EncodingError, "invalid encoding - #{enc}"
        end

        text.freeze
      end
      module_function :get_mime_charset_text

      ENCODED_WORD_TRANSFER_ENCODING_TABLE = { # :nodoc:
        'B' => 'BASE64',
        'Q' => 'QUOTED-PRINTABLE'
      }.freeze

      def decode_mime_encoded_words(encoded_string, decode_charset=nil, charset_aliases: DEFAULT_CHARSET_ALIASES, charset_convert_options: {})
        src = encoded_string
        dst = ''.dup

        if (decode_charset) then
          if (decode_charset.is_a? Encoding) then
            decode_charset_encoding = decode_charset
          else
            decode_charset_encoding = charset_aliases[decode_charset] ||
                                      Encoding.find(decode_charset) # raise `ArgumentError' when wrong charset due to library user
          end
          dst.force_encoding(decode_charset_encoding)
        else
          dst.force_encoding(encoded_string.encoding)
        end

        while (src =~ %r{
                 =\? [^\s?]+ \? [BQ] \? [^\s?]+ \?=
                 (?:
                   \s+
                   =\? [^\s?]+ \? [BQ] \? [^\s?]+ \?=
                 )*
               }ix)

          src = $'
          foreword = $`
          encoded_word_list = $&.split(/\s+/, -1)

          unless (foreword.empty?) then
            if (dst.encoding.dummy?) then
              # run the slow `String#encode' only when really needed
              # because of a premise that the strings other than
              # encoded words are ASCII only.
              foreword.encode!(dst.encoding, charset_convert_options)
            end
            dst << foreword
          end

          for encoded_word in encoded_word_list
            _, charset, encoding, encoded_text, _ = encoded_word.split('?', 5)
            encoding.upcase!
            encoded_text.tr!('_', ' ') if (encoding == 'Q')
            transfer_encoding = ENCODED_WORD_TRANSFER_ENCODING_TABLE[encoding] or raise "internal error - unknown encoding: #{encoding}"
            decoded_text = get_mime_charset_text(encoded_text, charset, transfer_encoding, charset_aliases: charset_aliases)

            if (decode_charset_encoding) then
              if (decoded_text.encoding != decode_charset_encoding) then
                # `decoded_text' is frozen
                decoded_text = decoded_text.encode(decode_charset_encoding, charset_convert_options)
              end
            elsif (dst.ascii_only?) then
              if (decoded_text.encoding.dummy?) then
                dst.encode!(decoded_text.encoding, charset_convert_options)
              end
            else
              if (decoded_text.encoding != dst.encoding) then
                # `decoded_text' is frozen
                decoded_text = decoded_text.encode(dst.encoding, charset_convert_options)
              end
            end
            dst << decoded_text
          end
        end

        unless (src.empty?) then
          if (dst.encoding.dummy?) then
            # run the slow `String#encode' only when really needed
            # because of a premise that the strings other than encoded
            # words are ASCII only.
            src = src.encode(dst.encoding, charset_convert_options) # `src' may be frozen
          end
          dst << src
        end

        dst.freeze
      end
      module_function :decode_mime_encoded_words
    end

    class Header
      def initialize(header_txt)
        @raw_source = header_txt
        @field_list = nil
        @field_table = nil
      end

      attr_reader :raw_source

      def setup_header
        if (@field_list.nil? || @field_table.nil?) then
          @field_list = Parse.parse_header(@raw_source)
          @field_table = {}
          for name, value in @field_list
            key = name.downcase.freeze
            @field_table[key] = [] unless (@field_table.key? key)
            @field_table[key] << value
          end
          @field_table.each_value do |value_list|
            value_list.freeze
          end
          @field_table.freeze
        end

        nil
      end
      private :setup_header

      # API methods

      def [](name)
        setup_header
        if (value_list = @field_table[name.downcase]) then
          value_list[0]
        end
      end

      def fetch_upcase(name)
        setup_header
        if (value_list = @field_table[name.downcase]) then
          value_list[0].upcase
        end
      end

      def field_value_list(name)
        setup_header
        @field_table[name.downcase]
      end

      # minimal methods like `Hash'

      include Enumerable

      def empty?
        setup_header
        @field_list.empty?
      end

      def key?(name)
        setup_header
        @field_table.key? name.downcase
      end

      # aliases like `Hash'
      alias has_key? key?
      alias include? key?
      alias member? key?

      def keys
        setup_header
        @field_table.keys
      end

      def each_key
        setup_header
        return enum_for(:each_key) unless block_given?
        @field_table.each_key do |key|
          yield(key)
        end
        self
      end

      def each_pair
        setup_header
        return enum_for(:each_pair) unless block_given?
        for name, value in @field_list
          yield(name, value)
        end
        self
      end

      alias each each_pair
    end

    class Body
      def initialize(body_txt)
        @raw_source = body_txt
      end

      attr_reader :raw_source
    end

    class Message
      def initialize(msg_txt, charset_aliases: DEFAULT_CHARSET_ALIASES)
        @raw_source = msg_txt.dup.freeze
        @charset_aliases = charset_aliases
        @header = nil
        @body = nil
        @content_type = nil
        @content_disposition = nil
        @content_language = nil
        @parts = nil
        @message = nil
        @date = nil
        @from = nil
        @sender = nil
        @reply_to = nil
        @to = nil
        @cc = nil
        @bcc = nil
        @mime_decoded_header_cache = nil
        @mime_decoded_header_field_value_list_cache = nil
        @mime_decoded_header_text_cache = nil
        @mime_charset_body_text_cache = nil
      end

      attr_reader :raw_source

      def setup_message
        if (@header.nil? || @body.nil?) then
          header_txt, body_txt = Parse.split_message(@raw_source)
          @header = Header.new(header_txt || '')
          @body = Body.new(body_txt || '')
        end

        nil
      end
      private :setup_message

      def header
        setup_message
        @header
      end

      def body
        setup_message
        @body
      end

      def setup_content_type
        @content_type ||= Parse.parse_content_type(header['Content-Type'] || '')
        nil
      end
      private :setup_content_type

      def media_main_type
        setup_content_type
        @content_type[0]
      end

      def media_sub_type
        setup_content_type
        @content_type[1]
      end

      alias media_subtype media_sub_type

      def content_type
        "#{media_main_type}/#{media_sub_type}"
      end

      def media_main_type_upcase
        # not return `nil'
        media_main_type.upcase
      end

      def media_sub_type_upcase
        # not return `nil'
        media_sub_type.upcase
      end

      alias media_subtype_upcase media_sub_type_upcase

      def content_type_upcase
        # not return `nil'
        content_type.upcase
      end

      def content_type_parameter(name)
        setup_content_type
        if (name_value_pair = @content_type[2][name.downcase]) then
          name_value_pair[1]
        end
      end

      def content_type_parameter_list
        setup_content_type
        @content_type[2].values
      end

      alias content_type_parameters content_type_parameter_list

      def charset
        content_type_parameter('charset')
      end

      def boundary
        content_type_parameter('boundary')
      end

      def setup_content_disposition
        if (@content_disposition.nil?) then
          if (header.key? 'Content-Disposition') then
            @content_disposition = Parse.parse_content_disposition(header['Content-Disposition'])
          end
        end

        nil
      end
      private :setup_content_type

      def content_disposition
        setup_content_disposition
        @content_disposition && @content_disposition[0]
      end

      def content_disposition_upcase
        content_disposition&.upcase
      end

      def content_disposition_parameter(name)
        setup_content_disposition
        if (@content_disposition) then
          if (name_value_pair = @content_disposition[1][name.downcase]) then
            name_value_pair[1]
          end
        end
      end

      def content_disposition_parameter_list
        setup_content_type
        @content_disposition && @content_disposition[1].values
      end

      alias content_disposition_parameters content_disposition_parameter_list

      def setup_content_language
        if (@content_language.nil?) then
          if (header.key? 'Content-Language') then
            @content_language = header.field_value_list('Content-Language').map{|tags_txt| Parse.parse_content_language(tags_txt) }
            @content_language.flatten!
            @content_language.freeze
          end
        end

        nil
      end
      private :setup_content_language

      def content_language
        setup_content_language
        @content_language
      end

      def content_language_upcase
        content_language&.map{|tag| tag.upcase }
      end

      def text?
        media_main_type_upcase == 'TEXT'
      end

      def multipart?
        media_main_type_upcase == 'MULTIPART'
      end

      def parts
        if (@parts.nil?) then
          if (multipart?) then
            if (boundary = self.boundary) then
              part_list = Parse.parse_multipart_body(boundary, body.raw_source)
              @parts = part_list.map{|msg_txt| Message.new(msg_txt) }
            else
              @parts = []
            end
            @parts.freeze
          end
        end

        @parts
      end

      def message?
        media_main_type_upcase == 'MESSAGE'
      end

      def message
        if (@message.nil?) then
          if (message?) then
            @message = Message.new(body.raw_source)
          end
        end

        @message
      end

      def date
        if (@date.nil?) then
          if (header.key? 'Date') then
            begin
              @date = Time.parse(header['Date'])
            rescue ArgumentError
              @date = Time.at(0)
            end
            @date.freeze
          end
        end

        @date
      end

      def mail_address_header_field(field_name)
        if (header.key? field_name) then
          ivar_name = '@' + field_name.downcase.tr('-', '_')
          addr_list = instance_variable_get(ivar_name)
          if (addr_list.nil?) then
            addr_list = header.field_value_list(field_name).map{|addr_list_txt| Parse.parse_mail_address_list(addr_list_txt) }
            addr_list.flatten!
            addr_list.freeze
            instance_variable_set(ivar_name, addr_list)
          end

          addr_list
        end
      end
      private :mail_address_header_field

      def from
        mail_address_header_field('from')
      end

      def sender
        mail_address_header_field('sender')
      end

      def reply_to
        mail_address_header_field('reply-to')
      end

      def to
        mail_address_header_field('to')
      end

      def cc
        mail_address_header_field('cc')
      end

      def bcc
        mail_address_header_field('bcc')
      end

      def make_charset_key(charset)
        if (charset.is_a? Encoding) then
          charset
        else
          charset.downcase.freeze
        end
      end
      private :make_charset_key

      def mime_decoded_header(name, decode_charset=nil, charset_convert_options: {})
        cache_key = [
          name.downcase.freeze,
          (decode_charset) ? make_charset_key(decode_charset) : :default
        ].freeze
        @mime_decoded_header_cache ||= {}
        @mime_decoded_header_cache[cache_key] ||= CharsetText.decode_mime_encoded_words(header[name],
                                                                                        decode_charset,
                                                                                        charset_aliases: @charset_aliases,
                                                                                        charset_convert_options: charset_convert_options)
      end

      def mime_decoded_header_field_value_list(name, decode_charset=nil, charset_convert_options: {})
        cache_key = [
          name.downcase.freeze,
          (decode_charset) ? make_charset_key(decode_charset) : :default
        ].freeze
        @mime_decoded_header_field_value_list_cache ||= {}
        @mime_decoded_header_field_value_list_cache[cache_key] ||= header.field_value_list(name).map{|field_value|
          CharsetText.decode_mime_encoded_words(field_value,
                                                decode_charset,
                                                charset_aliases: @charset_aliases,
                                                charset_convert_options: charset_convert_options)
        }.freeze
      end

      def mime_decoded_header_text(decode_charset=nil, charset_convert_options: {})
        cache_key = (decode_charset) ? make_charset_key(decode_charset) : :default
        @mime_decoded_header_text_cache ||= {}
        @mime_decoded_header_text_cache[cache_key] ||= CharsetText.decode_mime_encoded_words(header.raw_source,
                                                                                             decode_charset,
                                                                                             charset_aliases: @charset_aliases,
                                                                                             charset_convert_options: charset_convert_options)
      end

      def mime_charset_body_text(charset=nil)
        @mime_charset_body_text_cache ||= {}
        unless (charset) then
          unless (@mime_charset_body_text_cache.key? :default) then
            charset = (text?) ? self.charset : Encoding::ASCII_8BIT
            @mime_charset_body_text_cache[:default] = CharsetText.get_mime_charset_text(body.raw_source,
                                                                                        charset,
                                                                                        header['Content-Transfer-Encoding'],
                                                                                        charset_aliases: @charset_aliases)
          end
          @mime_charset_body_text_cache[:default]
        else
          cache_key = make_charset_key(charset)
          @mime_charset_body_text_cache[cache_key] ||= CharsetText.get_mime_charset_text(body.raw_source,
                                                                                         charset,
                                                                                         header['Content-Transfer-Encoding'],
                                                                                         charset_aliases: @charset_aliases)
        end
      end

      def mime_binary_body_string
        mime_charset_body_text(Encoding::ASCII_8BIT)
      end
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
