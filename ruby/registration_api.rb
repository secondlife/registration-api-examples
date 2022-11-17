# frozen_string_literal: true

require 'llsd'

# This ruby example shows how to use the Registration API. The example goes as follows:

# 0 - get capability urls
# 1 - get error codes
# 2 - get the available last names
# 3 - check to see of a username + last name combo is taken
# 4 - register the user with this username + last name combo

get_capabilities_url = 'https://cap.secondlife.com/get_reg_capabilities'

# grab command line args
if ARGV.length == 3
  first_name = ARGV[0]
  last_name = ARGV[1]
  password = ARGV[2]
else
  puts 'Please pass in your second life first name, last name, and password as arguments. For example:'
  puts 'ruby registration_api.rb joe linden 1234'

  exit
end

# 0 - Get Capability URLS #################################################################
puts "========== Getting capabilities ===========\n"

post_body = "first_name=#{first_name}&last_name=#{last_name}&password=#{password}" # create a url-encoded string to POST
response_xml = LLSD.post_urlencoded_data get_capabilities_url, post_body # POST the capability url to get capabilities

puts 'xml response:' # Print out response xml
puts response_xml

puts "\n"

capability_urls = LLSD.parse(response_xml) # Parse the xml

capability_urls.each { |k, v| puts "#{k} => #{v}" } # print out capabilities

# 1 - Print out error codes ###############################################################
puts "\n\n========== Get Error Codes Example ===========\n"

if capability_urls['get_error_codes']
  response_xml = LLSD.http_raw capability_urls['get_error_codes'] # GET the capability url for getting error codes

  puts 'xml response:' # Print out response xml
  puts response_xml

  error_codes = LLSD.parse(response_xml) # Parse the xml

  error_codes.each { |error| puts "#{error[0]} => #{error[1]}" } # print out all error codes
else
  puts "Get_error_codes capability not granted to #{first_name} #{last_name}. Now Exiting Prematurely ..."
end

# 2 - Get Last Names Example ##############################################################
puts "\n\n========== Get Last Names Example ===========\n"
if capability_urls['get_last_names']
  response_xml = LLSD.http_raw capability_urls['get_last_names'] # GET the capability url for getting last names and ids

  puts 'xml response:' # Print out response xml
  puts response_xml

  last_names = LLSD.parse(response_xml) # Parse the xml

  last_names.each { |k, v| puts "#{k} => #{v}" } # print out last names

  # 3 - Check Name Example ##################################################################
  print "\n\n========== Check Name Example ===========\n"
  if capability_urls['check_name']
    random_username = "tester#{Kernel.rand(10_000)}" # Generate a random username
    valid_last_name_id = last_names.keys.first # Get the first valid last name id
    params_hash = { 'username' => random_username, 'last_name_id' => valid_last_name_id } # put it in a hash

    xml_to_post = LLSD.to_xml(params_hash) # convert it to llsd xml

    response_xml = LLSD.post_xml(capability_urls['check_name'], xml_to_post)

    puts 'posted xml:' # Print out response xml
    puts xml_to_post

    puts 'xml response:' # Print out response xml
    puts response_xml

    is_name_available = LLSD.parse(response_xml) # Parse the xml

    puts "Result (is name available?): #{is_name_available}" # Print the result

    # 4 - Create User Example #################################################################
    puts "\n\n========== Create User Example ===========\n"
    if is_name_available && capability_urls['create_user']
      # fill in the rest of the hash we started in example 2 with valid data
      params_hash['email'] = "#{random_username}@ben.com"
      params_hash['password'] = '123123abc'
      params_hash['dob'] = '1980-01-01'

      xml_to_post = LLSD.to_xml(params_hash) # convert it to llsd xml

      response_xml = LLSD.post_xml(capability_urls['create_user'], xml_to_post)

      puts 'posted xml:' # Print out response xml
      puts xml_to_post

      puts 'xml response:' # Print out response xml
      puts response_xml

      result_hash = LLSD.parse(response_xml) # Parse the xml

      puts "New agent id: #{result_hash['agent_id']}" # Print the result

      # ALL DONE!!
    else
      puts "Create_user capability not granted to #{first_name} #{last_name}. Now Exiting Prematurely ..."
    end
  else
    puts "Check_name capability not granted to #{first_name} #{last_name}. Now Exiting Prematurely ..."
  end
else
  puts "Get_last_names capability not granted to #{first_name} #{last_name}. Now Exiting Prematurely..."
end
