#!/usr/bin/perl -w
# version 1.0
package Indra::LLSD;

use strict;
use XML::DOM;
#use Test::More qw(no_plan);

sub Parsefile($)
{
    my ($filename) = @_;

    # try to parse the xml file
    my $parser = new XML::DOM::Parser;
    my $doc;
    eval
    {
        $doc = $parser->parsefile($filename);
    };
    if ($@)
    {
        #print "Unable to parse XML String. Returning undefined LLSD. \n";
        return undef;
    }
    _parse_doc($doc);
}

sub Parse($)
{
    my ($xml) = @_;

    # try to parse the xml file
    my $parser = new XML::DOM::Parser;
    my $doc;
    eval
    {
        $doc = $parser->parse($xml);
    };
    if ($@)
    {
        #print "Unable to parse XML file. Returning undefined LLSD. \n";
        return undef;
    }
    _parse_doc($doc);
}

sub Create($)
{
    my ($data) = @_;
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse('<llsd/>');

    my $root_node = $doc->getElementsByTagName("llsd");
    my $node = _create_xml_node($data, $doc);
    if (defined $node)
    {
        $root_node->[0]->insertBefore($node);
    }
    return $doc->toString();
}

sub _create_xml_node($$)
{
    my ($data, $doc) = @_;

    # check for undefined type
    if (!defined $data)
    {
        return $doc->createElement("undef");
    }

    # check for array type
    eval
    {
        my @test = @{$data}
    };
    if (!$@)
    {
        return _create_array_node($data, $doc);
    }

    # check for hash type
    eval
    {
        my $test = $data->{'test'};
    };
    if (!$@)
    {
        return _create_hash_node($data, $doc);
    }

    # check for scalar
    if (defined $data)
    {
        # assume $data is scalar if it's defined
        my $node = $doc->createElement("string");
        $node->insertBefore($doc->createTextNode("$data"));
        return $node;
    }

    return undef;
}

sub _create_hash_node($$)
{
    my ($data, $doc) = @_;
    my $map_node = $doc->createElement("map");

    my @keys = keys %{$data};
    my $key;
    while($key = shift @keys)
    {
        # key pair
        my $child = $doc->createElement("key");
        $child->insertBefore($doc->createTextNode($key));
        $map_node->insertBefore($child);

        # value pair
        $child = _create_xml_node($data->{$key}, $doc);
        if (defined $child)
        {
            $map_node->insertBefore($child);
        }
    }
    return $map_node;
}

sub _create_array_node($$)
{
    my ($data, $doc) = @_;
    my $array_node = $doc->createElement("array");

    my $element;
    while($element = shift @{$data})
    {
        my $child_node = _create_xml_node($element, $doc);
        if (defined $child_node)
        {
            $array_node->insertBefore($child_node);
        }
    }
    return $array_node;
}

sub _parse_doc($)
{
    my ($doc) = @_;

    # gather nodes
    my $node = $doc->getDocumentElement();
    if ($node->getNodeName() ne 'llsd')
    {
        print "XML file with root node " .
            $node->getNodeName() .
            " does not have root element llsd\n";
        return undef;
    }

    my @nodes = $node->getElementsByTagName('*', 0);
    if (@nodes == 0 || @nodes > 1)
    {
        print "LLSD can only contain one element, but requested node has " .
            @nodes . " elements.\n";
        return undef;
    }
    return _parse_llsd($nodes[0]);

    # Avoid memory leaks - cleanup circular references for garbage collection
    $doc->dispose();
}

sub _parse_llsd($)
{
    my ($node) = @_;

    # we have an xml element for representation.  Check types and format
    my $type = $node->getNodeName();
    if ($type eq 'array')
    {
        return _parse_llsd_array($node->getElementsByTagName('*', 0));
    }
    elsif ($type eq 'map')
    {
        return _parse_llsd_map($node->getElementsByTagName('*', 0));
    }
    else
    {
        # scalar from this point forward
        my $children_list = $node->getChildNodes();

        if (($children_list->getLength() == 0) &&
            ($type eq 'undef'))
        {
            return undef;
        }
        elsif ($children_list->getLength() != 1)
        {
            #print "Invalid # of nodes for scalar: " . $children_list->getLength() . "\n";
            return undef;
        }
        my $value = $children_list->[0]->getNodeValue();

        if ($type eq 'boolean')
        {
            if (!defined $value)
            {
                #print "Invalid format for Boolean LLSD\n";
                return undef;
            }
            elsif ($value eq 'true' || $value eq '1')
            {
                return 'true';
            }
            elsif ($value eq 'false' || $value eq '0')
            {
                return undef;
            }
            else
            {
                #print "Invalid format for Boolean LLSD: " . $value . "\n";
                return undef;
            }
        }
        elsif ($type eq 'integer')
        {
            if (!defined $value)
            {
                #print "Invalid format for Integer LLSD\n";
                return 0;
            }
            elsif ($value =~ /^-?\d+$/)
            {
                return $value + 0;
            }
            else
            {
                #print "Invalid format for Integer LLSD: " . $value . "\n";
                return 0;
            }
        }
        elsif ($type eq 'real')
        {
            if (!defined $value)
            {
                #print "Invalid format for Real LLSD\n";
                return 0.0;
            }
            elsif ($value =~ /^-?\d+(\.\d+)?$/ ||
                   $value =~ /^-?\.\d+$/)
            {
                return $value;
            }
            else
            {
                #print "Invalid format for Real LLSD: " . $value . "\n";
                return 0.0;
            }
        }
        elsif ($type eq 'uuid')
        {
            if (!defined $value)
            {
                #print "Invalid format for UUID LLSD\n";
                return '00000000-0000-0000-0000-000000000000';
            }
            elsif ($value =~ /^[a-z0-9]{8}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{4}-[a-z0-9]{12}$/)
            {
                return $value;
            }
            else
            {
                # print "Invalid format for UUID LLSD: " . $value . "\n";
                return '00000000-0000-0000-0000-000000000000';
            }
        }
        elsif ($type eq 'date')
        {
            if (!defined $value)
            {
                # print "Invalid format for Date LLSD\n";
                return ''; #FIXME
            }
            elsif ($value =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/)
            {
                return $value;
            }
            else
            {
                # print "Invalid format for Date LLSD: " . $value . "\n";
                return ''; #FIXME
            }
        }
        elsif ($type eq 'string')
        {
            if (defined $value)
            {
                return $value;
            }
            else
            {
                print "Invalid format for String LLSD\n";
                return '';
            }
        }
        elsif ($type eq 'uri')
        {
            if (defined $value)
            {
                return $value;
            }
            else
            {
                print "Invalid format for URI LLSD\n";
                return '';
            }
        }
        else
        {
            print "Invalid Type Given for LLSD";
            print " " . $type if (defined $type);
            print "\n";
            return undef;
        }
    }
}

sub _parse_llsd_array($)
{
    my (@children) = @_;
    my @return_value;
    my $child;
    while ($child = shift @children)
    {
        my $value = _parse_llsd($child);
        if (defined $value)
        {
            push @return_value, $value;
        }
    }
    return \@return_value;
}

sub _parse_llsd_map($)
{
    my (@children) = @_;
    my %return_value;

    # every other tag type should be "key" or an LLSD value
    my $tag_type = 'key';
    my $hash_name = undef;
    my $child;
    while ($child = shift @children)
    {
        if ($tag_type eq 'key' &&
            $child->getNodeName() eq 'key')
        {
            $tag_type = 'value';
            $hash_name = $child->getFirstChild->getNodeValue();
        }
        elsif ($tag_type eq 'value')
        {
            my $value = _parse_llsd($child);
            if (defined $hash_name &&
                defined $value)
            {
                $tag_type = 'key';
                $return_value{$hash_name} = $value;
                $hash_name = undef;
            }
        }
    }
    return \%return_value;
}

sub unit_test_xml($$)
{
    my ($given_xml, $expected_result) = @_;

    # convert given xml into formatted for comparisons later
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse($expected_result);
    my $formatted_xml = $doc->toString();

    # use LLSD library to parse given xml
    my $llsd = Indra::LLSD::Parse($given_xml);

    # use LLSD library to create the xml from the parsed llsd
    my $translated_result_xml = Indra::LLSD::Create($llsd);

    # compare the results to see if they match
    if ($translated_result_xml eq $formatted_xml)
    {
        return "true";
    }
    else
    {
        print "\n\n**************GIVEN XML: \n" . $given_xml . "\n";
        print "Formatted XML: \n" . $formatted_xml . "\n";
        print "Result XML: \n" . $translated_result_xml . "\n";
        return undef;
    }
}

sub unit_test_llsd($$)
{
    my ($given_llsd, $expected_result) = @_;

    # convert given xml into formatted for comparisons later
    my $parser = new XML::DOM::Parser;
    my $doc = $parser->parse($expected_result);
    my $formatted_xml = $doc->toString();
    my $translated_result_xml = Indra::LLSD::Create($given_llsd);

    # compare the results to see if they match
    if ($translated_result_xml eq $formatted_xml)
    {
        return "true";
    }
    else
    {
        print "UNIT TEST FAILED:\n";
        print "Expected: \n\"" . $expected_result . "\"\n";
        print "Result XML: \n\"" . $translated_result_xml . "\"\n";
        return undef;
    }
}

#### begin unit tests here ####

# # map
# ok( unit_test_xml('<llsd>
# <map>
# <key>foo</key>
# <string>bar</string>
# </map>
# </llsd>', '<llsd><map><key>foo</key><string>bar</string></map></llsd>'),
# "Map within map");
#
# # map within map
# ok( unit_test_xml('<llsd>
# <map>
# <key>doo</key>
# <map>
# <key>goo</key>
# <string>poo</string>
# </map>
# <key>foo</key>
# <string>bar</string>
# </map>
# </llsd>', '<llsd><map><key>doo</key><map><key>goo</key><string>poo</string></map><key>foo</key><string>bar</string></map></llsd>'),
# "map within map");
#
# # blank map
# ok( unit_test_xml('<llsd>
# <map />
# </llsd>', '<llsd><map/></llsd>'),
# "blank map");
#
# # array
# ok( unit_test_xml('<llsd>
# <array>
# <string>foo</string>
# <string>bar</string>
# </array>
# </llsd>', '<llsd><array><string>foo</string><string>bar</string></array></llsd>'),
# "array");
#
# # array within array
# ok( unit_test_xml('<llsd>
# <array>
# <string>foo</string>
# <string>bar</string>
# <array>
# <string>foo</string>
# <string>bar</string>
# </array>
# </array>
# </llsd>', '<llsd><array><string>foo</string><string>bar</string><array><string>foo</string><string>bar</string></array></array></llsd>'),
# "array within array");
#
# # blank array
# ok( unit_test_xml('<llsd>
# <array />
# </llsd>', '<llsd><array/></llsd>'),
# "blank array");
#
# # string
# ok (unit_test_xml('<llsd>
# <string>foo</string>
# </llsd>', '<llsd><string>foo</string></llsd>'),
# "string");
#
# # integer
# ok (unit_test_xml('<llsd>
# <integer>289343</integer>
# </llsd>',
# '<llsd><string>289343</string></llsd>'),
# "integer");
#
# # negative integer
# ok( unit_test_xml('<llsd>
# <integer>-289343</integer>
# </llsd>',
# '<llsd><string>-289343</string></llsd>'),
# "negative integer");
#
# # blank integer
# ok( unit_test_xml('<llsd>
# <integer />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank integer");
#
# # real
# ok( unit_test_xml('<llsd>
# <real>2983287453.38483</real>
# </llsd>', '<llsd><string>2983287453.38483</string></llsd>'),
# "real");
#
# # negative real
# ok( unit_test_xml('<llsd>
# <real>-2983287453.38483</real>
# </llsd>', '<llsd><string>-2983287453.38483</string></llsd>'),
# "negative real");
#
# # blank real
# ok( unit_test_xml('<?xml version="1.0" encoding="UTF-8"?>
# <llsd>
# <real />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank real");
#
# # boolean
# ok( unit_test_xml('<llsd>
# <boolean>true</boolean>
# </llsd>', '<llsd><string>true</string></llsd>'),
# "boolean");
#
# # blank boolean
# ok( unit_test_xml('<llsd>
# <boolean />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank boolean");
#
# # date
# ok( unit_test_xml('<llsd>
# <date>2006-02-01T14:29:53Z</date>
# </llsd>', '<llsd><string>2006-02-01T14:29:53Z</string></llsd>'),
# "date");
#
# # blank date
# ok( unit_test_xml('<llsd>
# <date />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank date");
#
#
# # uuid
# ok( unit_test_xml('<?xml version="1.0" encoding="UTF-8"?>
# <llsd>
# <uuid>d7f4aeca-88f1-42a1-b385-b9db18abb255</uuid>
# </llsd>', '<llsd><string>d7f4aeca-88f1-42a1-b385-b9db18abb255</string></llsd>'),
# "uuid");
#
# # blank uuid
# ok( unit_test_xml('<?xml version="1.0" encoding="UTF-8"?>
# <llsd>
# <uuid />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank uuid");
#
# # uri
# ok( unit_test_xml('<?xml version="1.0" encoding="UTF-8"?>
# <llsd>
# <uri>http://sim956.agni.lindenlab.com:12035/runtime/agents</uri>
# </llsd>', '<llsd><string>http://sim956.agni.lindenlab.com:12035/runtime/agents</string></llsd>'),
# "uri");
#
# # blank uri
# ok( unit_test_xml('<?xml version="1.0" encoding="UTF-8"?>
# <llsd>
# <uri />
# </llsd>', '<llsd><undef/></llsd>'),
# "blank uri");
#
# # undefined
# ok( unit_test_xml('<llsd><undef /></llsd>', '<llsd><undef /></llsd>'),
# "undefined");
#
# # complex xml
# ok( unit_test_xml('<llsd>
# <Integer>
# <alpha>
# <bar>Surprise</bar>
# <junk>Here we go</junk>
# </alpha>
# <ref id="me" xxx="there"/>
# </integer>
# </llsd>', '<llsd><undef /></llsd>'),
# "complex xml");
#
#
# # another complex xml
# ok( unit_test_xml('<llsd><map><key>first</key><string>0</string><key>second</key><string>abcd</string><key>third</key><map><key>first</key><string>898989898</string></map></map></llsd>',
# '<llsd><map><key>first</key><string>0</string><key>second</key><string>abcd</string><key>third</key><map><key>first</key><string>898989898</string></map></map></llsd>'),
# "another complex xml");
#
# # string with one single quote (the scourge of web forms)
# ok( unit_test_xml('<llsd><string>Ain\'t this a good test?</string></llsd>','<llsd><string>Ain\'t this a good test?</string></llsd>'),"string with one single quote");
#
# # string with one double quote (the scourge of web forms)
# ok( unit_test_xml('<llsd><string>Ain"t this another good test?</string></llsd>','<llsd><string>Ain"t this another good test?</string></llsd>'),"string with one double quote");
#
# # SLURL with %20s as a uri
# ok( unit_test_xml('<llsd><uri>http://slurl.com/secondlife/Island%20for%20Unit%20Tests/128/128/40</uri></llsd>','<llsd><string>http://slurl.com/secondlife/Island%20for%20Unit%20Tests/128/128/40</string></llsd>'),"SLURL with %20s as a uri");
#
#
#
1;
#
#
# my $xml;
# my %hash;
# $hash{'help'} = "testing";
# $hash{'help1'} = "testing1";
# ok( unit_test_llsd(\%hash,'<llsd><map><key>help1</key><string>testing1</string><key>help</key><string>testing</string></map></llsd>'),
# "map llsd");
#
# my @array;
# push @array, "array test";
# push @array, "test 2";
# ok( unit_test_llsd(\@array,'<llsd><array><string>array test</string><string>test 2</string></array></llsd>'),
# "array llsd");
#
# my $scalar = 0;
# ok( unit_test_llsd($scalar,'<llsd><string>0</string></llsd>'),
# "scalar llsd");
#
# my %hash_of_hash;
# my %hash_element;
# $hash_of_hash{'first'} = 0;
# $hash_of_hash{'second'} = "abcd";
# $hash_of_hash{'third'} = \%hash_element;
# $hash_element{'first'} = 898989898;
# ok( unit_test_llsd(\%hash_of_hash,'<llsd><map><key>first</key><string>0</string><key>second</key><string>abcd</string><key>third</key><map><key>first</key><string>898989898</string></map></map></llsd>'),
# "hash of hash llsd");
