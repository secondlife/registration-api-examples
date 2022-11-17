import random
import sys
import urllib.error
import urllib.parse
import urllib.request

import llsd


# This python example shows how to use the Registration API. The example goes as follows:

# 0 - get capability urls
# 1 - get error codes
# 2 - get the available last names
# 3 - check to see of a username + last name combo is taken
# 4 - register the user with this username + last name combo

get_capabilities_url = "https://cap.secondlife.com/get_reg_capabilities"

# grab command line args
if len(sys.argv) == 4:
    first_name = sys.argv[1]
    last_name = sys.argv[2]
    password = sys.argv[3]
else:
    print(
        "Please pass in your second life first name, last name, and password as arguments. For example:"
    )
    print("ruby registration_api.rb registration mackay 1234")

    sys.exit()


# 0 - Get Capability URLS #################################################################
print("========== Getting capabilities ===========")

post_body = "first_name=%s&last_name=%s&password=%s" % (
    first_name,
    last_name,
    password,
)  # create a url-encoded string to POST
response_xml = urllib.request.urlopen(
    get_capabilities_url, post_body
).read()  # POST the capability url to get capabilities

print("xml response:")  # Print out response xml
print(response_xml)

capability_urls = llsd.parse(response_xml)  # Parse the xml

for id, name in list(capability_urls.items()):  # Print out capabilities
    print("%s => %s" % (id, name))


# 1 - Print out error codes ###############################################################
if "get_error_codes" in capability_urls:
    print("\n\n========== Get Error Codes Example ===========\n")

    response_xml = urllib.request.urlopen(
        capability_urls["get_error_codes"]
    ).read()  # GET the capability url for getting error codes

    print("xml response:")  # Print out response xml
    print(response_xml)

    error_codes = llsd.parse(response_xml)  # Parse the xml

    for error in error_codes:  # Print out capabilities
        print("%s => %s" % (error[0], error[1]))
else:
    print(
        "Get_error_codes capability not granted to %s %s. Now Exiting Prematurely ..."
        % (first_name, last_name)
    )


# 2 - Get Last Names Example ##############################################################
if "get_last_names" in capability_urls:
    print("\n\n========== Get Last Names Example ===========")

    response_xml = urllib.request.urlopen(
        capability_urls["get_last_names"]
    ).read()  # GET the capability url for getting last names and ids

    print("xml response:")  # Print out response xml
    print(response_xml)

    last_names = llsd.parse(response_xml)  # Parse the xml

    for id, name in list(last_names.items()):  # Print out last names
        print("%s => %s" % (id, name))

    # 3 - Check Name Example ##################################################################
    if "check_name" in capability_urls:
        print("\n\n========== Check Name Example ===========")

        random_username = "benny" + str(
            random.randrange(100, 10000)
        )  # Generate a random username
        valid_last_name_id = list(last_names.keys())[
            0
        ]  # Get the first valid last name id
        params_hash = {
            "username": random_username,
            "last_name_id": valid_last_name_id,
        }  # put it in a hash

        xml_to_post = llsd.toXML(params_hash)  # convert it to llsd xml

        response_xml = urllib.request.urlopen(
            capability_urls["check_name"], xml_to_post
        ).read()

        print("posted xml ")  # Print out response xml
        print(xml_to_post)

        print("xml response:")  # Print out response xml
        print(response_xml)

        is_name_available = llsd.parse(response_xml)  # Parse the xml

        print(
            "Result (is name available?): %s" % (is_name_available)
        )  # Print the result

        # 4 - Create User Example #################################################################
        if is_name_available and "create_user" in capability_urls:
            print("\n\n========== Create User Example ===========")

            # fill in the rest of the hash we started in example 2 with valid data
            params_hash["email"] = random_username + "@ben.com"
            params_hash["password"] = "123123abc"
            params_hash["dob"] = "1980-01-01"

            xml_to_post = llsd.toXML(params_hash)  # convert it to llsd xml

            response_xml = urllib.request.urlopen(
                capability_urls["create_user"], xml_to_post
            ).read()

            print("posted xml ")  # Print out response xml
            print(xml_to_post)

            print("xml response:")  # Print out response xml
            print(response_xml)

            result_hash = llsd.parse(response_xml)  # Parse the xml

            print("New agent id: %s" % (result_hash["agent_id"]))  # Print the result

            # ALL DONE!!
        else:
            print(
                "create_user capability not granted to %s %s. Now Exiting Prematurely ..."
                % (first_name, last_name)
            )

    else:
        print(
            "check_name capability not granted to %s %s. Now Exiting Prematurely ..."
            % (first_name, last_name)
        )

else:
    print(
        "get_last_names capability not granted to %s %s. Now Exiting Prematurely ..."
        % (first_name, last_name)
    )
