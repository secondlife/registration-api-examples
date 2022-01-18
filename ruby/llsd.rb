# VERSION 1.3

require "rexml/document"
require "date"
require "net/http"
require "net/https"


class LLSDSerializationError < StandardError
end

# Class for parsing and generating llsd xml
class LLSD
  LLSD_ELEMENT = "llsd"

  BOOLEAN_ELEMENT = "boolean"
  INTEGER_ELEMENT = "integer"
  REAL_ELEMENT = "real"
  UUID_ELEMENT = "uuid"
  STRING_ELEMENT = "string"
  BINARY_ELEMENT = "binary"
  DATE_ELEMENT = "date"
  URI_ELEMENT = "uri"
  KEY_ELEMENT = "key"
  UNDEF_ELEMENT = "undef"

  ARRAY_ELEMENT = "array"
  MAP_ELEMENT = "map"

  # HTTP HELPER FUNCTIONS

  def self.http(url_string, obj=nil)
    self.parse(self.http_raw(url_string, obj))
  end

  def self.http_raw (url_string, obj=nil)
    if obj
      do_http_helper url_string, LLSD.to_xml(obj)
    else
      do_http_helper(url_string)
    end
  end

  #  {'Content-Type' => 'llsd/xml'}
  def self.post_xml (url_string, xml_string)
    self.do_http_helper(url_string, xml_string)
  end

  # , {'Content-Type' => 'application/x-www-form-urlencoded'}
  def self.post_urlencoded_data (url_string, url_encoded_data)
    self.do_http_helper(url_string, url_encoded_data)
  end



  #~ def self.http_helper (url_string, method = 'get', xml_string = nil)
    #~ uri = URI.parse(url_string)

    #~ response = Net::HTTP.start(uri.host, uri.port) do |http|
      #~ if method == 'post'
        #~ http.post uri.path, xml_string
      #~ elsif method == 'get'
        #~ http.get uri.path
      #~ end
    #~ end

    #~ response.body
  #~ end

  # PARSING AND ENCODING FUNCTIONS

  def self.to_xml(obj)
    llsd_element = REXML::Element.new LLSD_ELEMENT
    llsd_element.add_element(serialize_ruby_obj(obj))

    doc = REXML::Document.new
    doc << llsd_element
    doc.to_s
  end

  def self.parse(xml_string)
    # turn message into dom element
    doc = REXML::Document.new xml_string

    # get the first element inside the llsd element
    # if there is more than one element then return nil

    # return parse dom element on first element
    parse_dom_element doc.root.elements[1]
  end

  private

  def self.do_http_helper(url_string, string_to_post = nil)
    uri = URI.parse(url_string)
    response = nil

    connection = Net::HTTP.new(uri.host, uri.port)
    connection.use_ssl = true if uri.scheme == "https"
    connection.verify_mode = OpenSSL::SSL::VERIFY_NONE

    connection.start do |http|
      if string_to_post
        response = http.post uri.path, string_to_post
      else
        response = http.get uri.path
      end
    end

    response.body
  end


  def self.serialize_ruby_obj(obj)
    # if its a container (hash or map)

    case obj
      when Hash
        map_element = REXML::Element.new(MAP_ELEMENT)
        obj.each do |key, value|
          key_element = REXML::Element.new(KEY_ELEMENT)
          key_element.text = key.to_s
          value_element = serialize_ruby_obj value

          map_element.add_element key_element
          map_element.add_element value_element
        end

        map_element


      when Array
        array_element = REXML::Element.new(ARRAY_ELEMENT)
        obj.each { |o| array_element.add_element(serialize_ruby_obj(o)) }
        array_element

      when Fixnum, Integer
        integer_element = REXML::Element.new(INTEGER_ELEMENT)
        integer_element.text = obj.to_s
        integer_element

      when TrueClass, FalseClass
        boolean_element = REXML::Element.new(BOOLEAN_ELEMENT)

        if obj
          boolean_element.text = "true"
        else
          boolean_element.text = "false"
        end

        boolean_element

      when Float
        real_element = REXML::Element.new(REAL_ELEMENT)
        real_element.text = obj.to_s
        real_element

      when Date
        date_element = REXML::Element.new(DATE_ELEMENT)
        date_element.text = obj.to_s
        date_element

      when String
        if !obj.empty?
          string_element = REXML::Element.new(STRING_ELEMENT)
          string_element.text = obj.to_s
          string_element
        else
          STRING_ELEMENT
        end

      when NilClass
        UNDEF_ELEMENT

      else
        raise LLSDSerializationError.new("#{obj.class.to_s} class cannot be serialized into llsd xml - please serialize into a string first")
    end
  end

  def self.parse_dom_element(element)
    # pseudocode:

    #   if it is a container
    #     if its an array
    #       collect parse_dom_element applied to each child into an array
    #     else (its a map)
    #       collect parse_dom_element applied to each child into an hash
    #   else (its an atomic element)
    #     then extract the value to a native type
    #
    #   return the value

    case element.name
      when ARRAY_ELEMENT
        element_value = []
        element.elements.each {|child| element_value << (parse_dom_element child) }

      when MAP_ELEMENT
        element_value = {}
        element.elements.each do |child|
          if child.name == "key"
            element_value[child.text] = parse_dom_element child.next_element
          end
        end

      else
        element_value = convert_to_native_type(element.name, element.text, element.attributes)
    end

    element_value
  end

  def self.convert_to_native_type(element_type, unconverted_value, attributes)
    case element_type
      when INTEGER_ELEMENT
        unconverted_value.to_i


      when REAL_ELEMENT
        unconverted_value.to_f


      when BOOLEAN_ELEMENT
        if unconverted_value == "false" or unconverted_value.nil? # <boolean />
          false
        else
          true
        end


      when STRING_ELEMENT
        if unconverted_value.nil? # <string />
          ""
        else
          unconverted_value
        end


      when DATE_ELEMENT
        if unconverted_value.nil?
          DateTime.strptime("1970-01-01T00:00:00Z")
        else
          DateTime.strptime(unconverted_value)
        end


      when UUID_ELEMENT
        if unconverted_value.nil?
          '00000000-0000-0000-0000-000000000000'
        else
          unconverted_value
        end


      else
        unconverted_value
    end
  end
end

# if ran as a script, run unit tests
if __FILE__ == $0
  require 'test/unit'
  require 'webrick'

  class LLSDUnitTest < Test::Unit::TestCase
    def setup
      # LLSD = LLSD.new
    end

    #~ def teardown
    #~ end

    def test_map
      map_xml = <<EOF
      <llsd>
      <map>
       <key>foo</key>
       <string>bar</string>
      </map>
      </llsd>
EOF

      map_within_map_xml = <<EOF
      <llsd>
      <map>
       <key>doo</key>
       <map>
         <key>goo</key>
         <string>poo</string>
       </map>
       <key>foo</key>
       <string>bar</string>
      </map>
      </llsd>
EOF

      blank_map_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <map />
      </llsd>
EOF

      ruby_map = {"foo" => "bar"}
      ruby_map_within_map = {"foo" => "bar", "doo" => {"goo" => "poo"}}

      assert_equal ruby_map, LLSD.parse(map_xml)
      assert_equal ruby_map_within_map, LLSD.parse(map_within_map_xml)
      assert_equal({}, LLSD.parse(blank_map_xml))

      assert_equal strip(map_xml), LLSD.to_xml(ruby_map)
      assert_equal strip(map_within_map_xml), LLSD.to_xml(ruby_map_within_map)
    end

    def test_array
      array_xml = <<EOF
      <llsd>
      <array>
        <string>foo</string>
        <string>bar</string>
      </array>
      </llsd>
EOF

      array_within_array_xml = <<EOF
      <llsd>
      <array>
        <string>foo</string>
        <string>bar</string>
        <array>
          <string>foo</string>
          <string>bar</string>
        </array>
      </array>
      </llsd>
EOF

      blank_array_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <array />
      </llsd>
EOF

      ruby_array = ["foo", "bar"]
      ruby_array_within_array = ["foo", "bar",["foo", "bar"]]

      assert_equal ruby_array,  LLSD.parse(array_xml)
      assert_equal ruby_array_within_array,  LLSD.parse(array_within_array_xml)
      assert_equal([], LLSD.parse(blank_array_xml))

      assert_equal strip(array_xml), LLSD.to_xml(ruby_array)
      assert_equal strip(array_within_array_xml), LLSD.to_xml(ruby_array_within_array)
    end

    def test_string
      normal_xml = <<EOF
      <llsd>
      <string>foo</string>
      </llsd>
EOF

      blank_xml = <<EOF
      <llsd>
      <string />
      </llsd>
EOF

      assert_equal "foo", LLSD.parse(normal_xml)
      assert_equal "", LLSD.parse(blank_xml)

      assert_equal strip(normal_xml), LLSD.to_xml("foo")
      assert_equal strip(blank_xml), LLSD.to_xml("")
    end

    def test_integer
      pos_int_xml = <<EOF
      <llsd>
      <integer>289343</integer>
      </llsd>
EOF

      neg_int_xml = <<EOF
      <llsd>
      <integer>-289343</integer>
      </llsd>
EOF

      blank_int_xml = <<EOF
      <llsd>
      <integer />
      </llsd>
EOF

      ruby_pos_int = 289343
      ruby_neg_int = -289343

      assert_equal ruby_pos_int, LLSD.parse(pos_int_xml)
      assert_equal ruby_neg_int, LLSD.parse(neg_int_xml)
      assert_equal 0, LLSD.parse(blank_int_xml)

      assert_equal strip(pos_int_xml), LLSD.to_xml(ruby_pos_int)
      assert_equal strip(neg_int_xml), LLSD.to_xml(ruby_neg_int)
    end

    def test_real
      pos_real_xml = <<EOF
      <llsd>
      <real>2983287453.38483</real>
      </llsd>
EOF

      neg_real_xml = <<EOF
      <llsd>
      <real>-2983287453.38483</real>
      </llsd>
EOF

      blank_real_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <real />
      </llsd>
EOF
      ruby_pos_real = 2983287453.38483
      ruby_neg_real = -2983287453.38483

      assert_equal ruby_pos_real, LLSD.parse(pos_real_xml)
      assert_equal ruby_neg_real, LLSD.parse(neg_real_xml)
      assert_equal 0, LLSD.parse(blank_real_xml)

      assert_equal strip(pos_real_xml), LLSD.to_xml(ruby_pos_real)
      assert_equal strip(neg_real_xml), LLSD.to_xml(ruby_neg_real)
    end

    def test_boolean
      true_xml = <<EOF
      <llsd>
      <boolean>true</boolean>
      </llsd>
EOF

      false_xml = <<EOF
      <llsd>
      <boolean>false</boolean>
      </llsd>
EOF

      blank_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <boolean />
      </llsd>
EOF

      assert_equal true, LLSD.parse(true_xml)
      assert_equal false, LLSD.parse(false_xml)
      assert_equal false, LLSD.parse(blank_xml)

      assert_equal strip(true_xml), LLSD.to_xml(true)
      assert_equal strip(false_xml), LLSD.to_xml(false)
    end

    def test_date
      valid_date_xml = <<EOF
      <llsd>
      <date>2006-02-01T14:29:53Z</date>
      </llsd>
EOF

      blank_date_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <date />
      </llsd>
EOF

      ruby_valid_date = DateTime.strptime("2006-02-01T14:29:53Z")
      ruby_blank_date = DateTime.strptime("1970-01-01T00:00:00Z")

      assert_equal(ruby_valid_date, LLSD.parse(valid_date_xml))
      assert_equal(ruby_blank_date, LLSD.parse(blank_date_xml))

      assert_equal strip(valid_date_xml), LLSD.to_xml(ruby_valid_date)
    end

    # because the following types dont have "native" types in ruby, they convert to string

    def test_binary
      base64_binary_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <binary>dGhlIHF1aWNrIGJyb3duIGZveA==</binary>
      </llsd>
EOF

      # <binary /> should return blank binary blob... in ruby I guess this is just nil

      assert_equal "dGhlIHF1aWNrIGJyb3duIGZveA==", LLSD.parse(base64_binary_xml)
    end

    def test_uuid
      valid_uuid_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <uuid>d7f4aeca-88f1-42a1-b385-b9db18abb255</uuid>
      </llsd>
EOF

      blank_uuid_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <uuid />
      </llsd>
EOF

      assert_equal 'd7f4aeca-88f1-42a1-b385-b9db18abb255', LLSD.parse(valid_uuid_xml)
      assert_equal '00000000-0000-0000-0000-000000000000', LLSD.parse(blank_uuid_xml)
    end

    def test_uri
      valid_uri_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <uri>http://sim956.agni.lindenlab.com:12035/runtime/agents</uri>
      </llsd>
EOF

      blank_uri_xml = <<EOF
      <?xml version="1.0" encoding="UTF-8"?>
      <llsd>
      <uri />
      </llsd>
EOF

      # <uri /> should return an empty link, which in ruby I guess is just nil
      assert_equal 'http://sim956.agni.lindenlab.com:12035/runtime/agents', LLSD.parse(valid_uri_xml)
      assert_equal nil, LLSD.parse(blank_uri_xml)
    end

    def test_undefined
      undef_xml = <<EOF
      <llsd><undef /></llsd>
EOF

      assert_equal nil, LLSD.parse(undef_xml)
      assert_equal strip(undef_xml), LLSD.to_xml(nil)
    end

    def test_llsd_serialization_exception
      # make an object not supported by llsd
      ruby_range = Range.new 1,2

      # assert than an exception is raised
      assert_raise(LLSDSerializationError){ LLSD.to_xml(ruby_range) }
    end

    class EchoServlet < WEBrick::HTTPServlet::AbstractServlet
      def do_POST(request, response)
        response.body = request.body
      end
    end

    def test_http
      # start http server
      s = WEBrick::HTTPServer.new(:Port => 3000)
      s.mount("/echo", EchoServlet)
      # trap("INT"){ s.shutdown }
      Thread.new { s.start }

      # sleep(1)
      ruby_obj = {'foo' => 'bar', 'dog' => 'fog', 'a' => [1,2,3]}
      return_obj = LLSD.http "http://localhost:3000/echo", ruby_obj

      assert_equal ruby_obj, return_obj

      # stop http server
      s.shutdown
    end

    def strip(str)
      str.delete "\n "
    end
    #~ def test_fail
      #~ assert(false, 'Assertion was false.')
    #~ end
  end
end
