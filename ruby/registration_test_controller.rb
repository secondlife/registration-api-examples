require 'LLSD'

class RegistrationTestController < ApplicationController
  # FILL THESE IN WITH YOUR OWN CAPABILITY URLS
  CREATE_USER_URL = "???"
  GET_LAST_NAMES_URL = "???"
  CHECK_NAME_URL = "???"

  def test_create_user
    if request.get?
      @last_names_hash = LLSD.http GET_LAST_NAMES_URL
    elsif request.post?
      reg_hash = {}
      reg_hash['username'] = params[:username]
      reg_hash['last_name_id'] = params[:last_name_id].to_i
      reg_hash['password'] = params[:password]
      reg_hash['email'] = params[:email]
      reg_hash['start_region_name'] = params[:start_region_name] # if reg_hash['start_location']

      date_hash = params[:date]
      reg_hash['dob'] = "#{date_hash[:year].to_i}-#{date_hash[:month].to_i}-#{date_hash[:day].to_i}"

      # @headers["Content-Type"] = "text/xml"

      render_text (LLSD.http_raw CREATE_USER_URL, reg_hash)
    end
  end

  def test_check_name
    if request.get?
      @last_names_hash = LLSD.http GET_LAST_NAMES_URL
    elsif request.post?
      reg_hash = {}
      reg_hash['username'] = params[:username]
      reg_hash['last_name_id'] = params[:last_name_id].to_i

      render_text (LLSD.http_raw CHECK_NAME_URL, reg_hash)
    end
  end
end
