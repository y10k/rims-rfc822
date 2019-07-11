# -*- coding: utf-8; frozen_string_literal: true -*-

require 'rims/rfc822/version'
require 'time'

module RIMS
  module RFC822
    module Parse
      def split_message(msg_txt)
        header_txt, body_txt = msg_txt.lstrip.split(/\r?\n\r?\n/, 2)
        if ($&) then
          header_txt << $& if $&
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
              src_txt.sub!(/\A./, '') and dst_txt << $&
            else
              dst_txt << match_txt
            end
          when :quote
            case (match_txt)
            when '"'
              state = :raw
            when "\\"
              src_txt.sub!(/\A./, '') && dst_txt << $&
            else
              dst_txt << match_txt
            end
          when :comment
            case (match_txt)
            when ')'
              state = :raw
            when "\\"
              src_txt.sub!(/\A./, '')
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
        parameters_txt.scan(%r'(?<name>\S+?) \s* = \s* (?: (?<quoted_string>".*?") | (?<token>\S+?) ) \s* (?:;|\Z)'x) do
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
                (?<display_name>\S.*?) \s* : (?<group_list>.*?) ;
                \s*
                ,?
              }x, ''))
          then
            display_name = $~[:display_name]
            group_list = $~[:group_list]
            addr_list << Address.new( nil, nil, unquote_phrase(display_name), nil).freeze
            addr_list.concat(parse_mail_address_list(group_list))
            addr_list << Address.new(nil, nil, nil, nil).freeze
          elsif (src_txt.sub!(%r{
                   \A
                   \s*
                   (?<local_part>[^<>@",\s]+) \s* @ \s* (?<domain>[^<>@",\s]+)
                   \s*
                   ,?
                 }x, ''))
          then
            addr_list << Address.new(nil, nil, $~[:local_part].freeze, $~[:domain].freeze).freeze
          elsif (src_txt.sub!(%r{
                   \A
                   \s*
                   (?<display_name>\S.*?)
                   \s*
                   <
                     \s*
                     (?:
                       (?<route>@[^<>@",]* (?:, \s* @[^<>@",]*)*)
                       \s*
                       :
                     )?
                     \s*
                     (?<local_part>[^<>@",\s]+) \s* @ \s* (?<domain>[^<>@",\s]+)
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

    class Header
      include Enumerable

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
            key = name.downcase
            @field_table[key] = [] unless (@field_table.key? key)
            @field_table[key] << value
          end
          @field_table.each_value do |value_list|
            value_list.freeze
          end
          @field_table.freeze
          self
        end
      end
      private :setup_header

      def each
        setup_header
        return enum_for(:each) unless block_given?
        for name, value in @field_list
          yield(name, value)
        end
        self
      end

      def key?(name)
        setup_header
        @field_table.key? name.downcase
      end

      def [](name)
        setup_header
        if (value_list = @field_table[name.downcase]) then
          value_list[0]
        end
      end

      def fetch_upcase(name)
        setup_header
        if (value_list = @field_table[name.downcase]) then
          if (value = value_list[0]) then
            value.upcase
          end
        end
      end

      def field_value_list(name)
        setup_header
        @field_table[name.downcase]
      end
    end

    class Body
      def initialize(body_txt)
        @raw_source = body_txt
      end

      attr_reader :raw_source
    end

    CHARSET_ALIAS_TABLE = {}    # :nodoc:

    def add_charset_alias(name, encoding, charset_alias_table=CHARSET_ALIAS_TABLE)
      charset_alias_table[name.upcase] = encoding
      charset_alias_table
    end
    module_function :add_charset_alias

    def delete_charset_alias(name, charset_alias_table=CHARSET_ALIAS_TABLE)
      charset_alias_table.delete(name.upcase)
    end
    module_function :delete_charset_alias

    #add_charset_alias('euc-jp', Encoding::CP51932)
    add_charset_alias('euc-jp', Encoding::EUCJP_MS)
    #add_charset_alias('iso-2022-jp', Encoding::CP50220)
    add_charset_alias('iso-2022-jp', Encoding::CP50221)
    add_charset_alias('shift_jis', Encoding::WINDOWS_31J)

    class Message
      def initialize(msg_txt, charset_aliases: CHARSET_ALIAS_TABLE)
        @raw_source = msg_txt.dup.freeze
        @charset_alias_table = charset_aliases
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
        @body_text = nil
      end

      attr_reader :raw_source

      def setup_message
        if (@header.nil? || @body.nil?) then
          header_txt, body_txt = Parse.split_message(@raw_source)
          @header = Header.new(header_txt || '')
          @body = Body.new(body_txt || '')
          self
        end
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
        if (@content_type.nil?) then
          @content_type = Parse.parse_content_type(header['Content-Type'] || '')
          self
        end
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
        if (header.key? 'Content-Disposition') then
          if (@content_disposition.nil?) then
            @content_disposition = Parse.parse_content_disposition(header['Content-Disposition'])
            self
          end
        end
      end
      private :setup_content_type

      def content_disposition
        setup_content_disposition
        @content_disposition && @content_disposition[0]
      end

      def content_disposition_upcase
        if (type = content_disposition) then
          type.upcase
        end
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
        if (header.key? 'Content-Language') then
          if (@content_language.nil?) then
            @content_language = header.field_value_list('Content-Language').map{|tags_txt| Parse.parse_content_language(tags_txt) }.inject(:+)
            @content_language.freeze
            self
          end
        end
      end
      private :setup_content_language

      def content_language
        setup_content_language
        @content_language
      end

      def content_language_upcase
        if (tag_list = content_language) then
          tag_list.map{|tag| tag.upcase }
        end
      end

      def text?
        media_main_type_upcase == 'TEXT'
      end

      def multipart?
        media_main_type_upcase == 'MULTIPART'
      end

      def parts
        if (multipart?) then
          if (@parts.nil?) then
            if (boundary = self.boundary) then
              part_list = Parse.parse_multipart_body(boundary, body.raw_source)
              @parts = part_list.map{|msg_txt| Message.new(msg_txt) }
            else
              @parts = []
            end
            @parts.freeze
          end

          @parts
        end
      end

      def message?
        media_main_type_upcase == 'MESSAGE'
      end

      def message
        if (message?) then
          if (@message.nil?) then
            @message = Message.new(body.raw_source)
          end

          @message
        end
      end

      def date
        if (header.key? 'Date') then
          if (@date.nil?) then
            begin
              @date = Time.parse(header['Date'])
            rescue ArgumentError
              @date = Time.at(0)
            end
            @date.freeze
          end

          @date
        end
      end

      def mail_address_header_field(field_name)
        if (header.key? field_name) then
          ivar_name = '@' + field_name.downcase.gsub('-', '_')
          addr_list = instance_variable_get(ivar_name)
          if (addr_list.nil?) then
            addr_list = header.field_value_list(field_name).map{|addr_list_txt| Parse.parse_mail_address_list(addr_list_txt) }.inject(:+)
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

      def body_text
        unless (@body_text) then
          case (header.fetch_upcase('Content-Transfer-Encoding'))
          when 'BASE64'
            @body_text = body.raw_source.unpack1('m')
          when 'QUOTED-PRINTABLE'
            @body_text = body.raw_source.unpack1('M')
          else
            @body_text = body.raw_source.dup
          end

          if (name = charset) then
            unless (enc = @charset_alias_table[name.upcase]) then
              begin
                enc = Encoding.find(name)
              rescue ArgumentError
                raise EncodingError.new($!.to_s)
              end
            end
            @body_text.force_encoding(enc)
            @body_text.valid_encoding? or raise EncodingError, "message body text with invalid encoding - #{enc}"
          end
        end

        @body_text
      end
    end
  end
end

# Local Variables:
# mode: Ruby
# indent-tabs-mode: nil
# End:
