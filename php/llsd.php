<?php
// VERSION 1.0
// Read the incoming LLSD post data, and decode it into native PHP objects
function llsd_parse_body()
{
    $doc = file_get_contents("php://input");
    return llsd_decode($doc);
}


// Do a simple get of an URL, return the LLSD doc as native PHP objects
function llsd_get($url)
{
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, FALSE);
    $doc = curl_exec($ch);

    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($code >= 400)
    {
        return NULL;
    }

    return llsd_decode($doc);
}


// Post a native PHP object as an LLSD document, return the resulting LLSD doc as native PHP objects,
function llsd_post($url, $node)
{
    $str = llsd_encode($node);
    return llsd_post_string($url, $str);
}


function llsd_put($url, $node)
{
    $str = llsd_encode($node);
    return llsd_put_string($url, $str);
}


function llsd_delete($url)
{
	$ch = curl_init($url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($ch, CURLOPT_POST, TRUE);
	curl_setopt($ch, CURLOPT_FAILONERROR, 1);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_CUSTOMREQUEST, "DELETE");
	curl_setopt($ch, CURLOPT_HTTPHEADER, Array("Content-Type: application/xml"));
	curl_setopt($ch, CURLOPT_POSTFIELDS, $str);
	$doc = curl_exec($ch);
	$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	curl_close($ch);
	return llsd_decode($doc);
}


function llsd_post_string($url, $str)
{
	$ch = curl_init($url);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, FALSE);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($ch, CURLOPT_POST, TRUE);
	curl_setopt($ch, CURLOPT_FAILONERROR, 1);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_HTTPHEADER, Array("Content-Type: application/xml"));
	curl_setopt($ch, CURLOPT_POSTFIELDS, $str);
	$doc = curl_exec($ch);
	$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	curl_close($ch);

	return llsd_decode($doc);
}

function llsd_put_string($url, $str)
{
    $tmp = tmpfile();

	// FIXME: Drops the string into a temporary file and uses CURL
	// to PUT it, blech.
	fwrite($tmp, $str);
	fseek($tmp, 0);
	$ch = curl_init($url);
	curl_setopt($ch, CURLOPT_RETURNTRANSFER, TRUE);
	curl_setopt($ch, CURLOPT_PUT, TRUE);
	curl_setopt($ch, CURLOPT_INFILE, $tmp);
	curl_setopt($ch, CURLOPT_INFILESIZE, strlen($str));
	curl_setopt($ch, CURLOPT_FAILONERROR, 1);
	curl_setopt($ch, CURLOPT_FOLLOWLOCATION, 1);
	curl_setopt($ch, CURLOPT_HTTPHEADER, Array("Content-Type: application/xml","Transfer-Encoding: chunked"));
	$doc = curl_exec($ch);
	$code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
	curl_close($ch);
	fclose($tmp);
	return llsd_decode($doc);
}

// Encode a native PHP object into an LLSD representation
function llsd_encode(&$node)
{
    $doc = domxml_new_doc("1.0");
    $llsd_element = $doc->create_element("llsd");
    $doc->append_child($llsd_element);
    $llsd_element->append_child(llsd_encode_node($doc, $node));
    return $doc->dump_mem();
}


// Takes in an llsd document, returns a native PHP object
function llsd_decode($str)
{
    // error_log($str);
    // Generate the DOM tree from the text document
    $error = array();
    if (!$dom = domxml_open_mem($str, DOMXML_LOAD_PARSING, $error))
    {
        // Probably should generate something with errors, but just bail for now
        return NULL;
    }

    $dom_root = $dom->document_element();
    if (!$dom_root)
    {
        return NULL;
    }

    $child = $dom_root;
    // Iterate through all of the children looking for
    // the LLSD node.
    // $child = $dom_root->first_child();
    while ($child)
    {

        if (!($child->is_blank_node()))
        {
            switch ($child->node_type())
            {

            case XML_TEXT_NODE:
                // Skip text not enclosed in the LLSD tag
                break;
            case XML_ELEMENT_NODE:
                // Now fill in cur_key or cur_value depending on the node
                if ('llsd' == $child->node_name())
                {
                    // We've found the root node of the LLSD tree, now have at it.
                    return llsd_parse_root($child);
                }
            default:
                break;
            }
        }
        $child = $child->next_sibling();
    }

    // No valid LLSD node, return an empty object.
    return array();
}


//
// Implementation details below here, you shouldn't need to use any of this functionality
//


// Generates the DOM tree for a particular branch
function llsd_encode_node(&$doc, &$node)
{
    if (is_array($node))
    {
        // Figure out if it's a map or array,
        // Assume anything with sequential integer keys starting at 0 is an array
        $keys = array_keys($node);
        $is_array = true;
        $cur_key = 0;
        foreach ($keys as $key)
        {
            if (is_int($key))
            {
                if (!$cur_key == $key)
                {
                    $is_array = false;
                    break;
                }
                $cur_key++;
            }
            else
            {
                $is_array = false;
                break;
            }
        }
        if ($is_array)
        {
            return llsd_encode_array($doc, $node);
        }
        else
        {
            return llsd_encode_map($doc, $node);
        }
    }
    else if (is_int($node))
    {
        return llsd_encode_integer($doc, $node);
    }
    else if (is_float($node))
    {
        return llsd_encode_real($doc, $node);
    }
    else
    {
        // Default to string for everything else
        return llsd_encode_string($doc, $node);
    }
}

function llsd_encode_array(&$doc, &$node)
{
    $map_element = $doc->create_element("array");

    $count = count($node);
    for ($i = 0; $i < $count; $i++)
    {
        $value_element = llsd_encode_node($doc, $node[$i]);
        $map_element->append_child($value_element);
    }
    return $map_element;
}

function llsd_encode_map(&$doc, &$node)
{
    $map_element = $doc->create_element("map");

    foreach ($node as $key => $value)
    {
        $key_element = $doc->create_element("key");
        $key_text = $doc->create_text_node(utf8_encode($key));
        $key_element->append_child($key_text);

        $value_element = llsd_encode_node($doc, $value);

        $map_element->append_child($key_element);
        $map_element->append_child($value_element);
    }
    return $map_element;
}

function llsd_encode_integer(&$doc, &$node)
{
    $element = $doc->create_element("integer");
    $text = $doc->create_text_node(utf8_encode($node));
    $element->append_child($text);
    return $element;
}

function llsd_encode_real(&$doc, &$node)
{
    $element = $doc->create_element("real");
    $text = $doc->create_text_node(utf8_encode($node));
    $element->append_child($text);
    return $element;
}

function llsd_encode_string(&$doc, &$node)
{
    $element = $doc->create_element("string");
    $text = $doc->create_text_node(utf8_encode($node));
    $element->append_child($text);
    return $element;
}



function llsd_parse_root($node)
{
    // Root can have only one "value".  Skip all text fields.
    // FIXME: We ignore "extra" values in the root node if there are more than one.
    // should we be more forceful and error out here?

    // Iterate through all of the children looking for
    // an xml element node
    $child = $node->first_child();
    while ($child)
    {
        if (!($child->is_blank_node()))
        {
            switch ($child->node_type())
            {
            case XML_TEXT_NODE:
                // Skip text
                // FIXME: Should only skip whitespace, should error out on non-whitespace?
                break;
            case XML_ELEMENT_NODE:
                // Now fill in cur_key or cur_value depending on the node
                return llsd_parse_value($child);
                break;
            default:
                break;
            }
        }
        $child = $child->next_sibling();
    }

    // No LLSD node found, return an empty array
    return array();
}

function llsd_parse_value($node)
{
    $cur_value = "";

    switch ($node->node_type())
    {
    case XML_ELEMENT_NODE:
        switch ($node->node_name())
        {
        case 'map':
            $cur_value = llsd_parse_map_contents($node);
            break;
        case 'array':
            $cur_value = llsd_parse_array_contents($node);
            break;
        case 'binary':
            // FIXME: Implement binary handler (pull out encoding, decode base64 binary?
            $cur_value = NULL;
        default:
            // Everything else is handled via the generic handler, which will default to
            // treating it as a string
            // $cur_value = llsd_parse_contents($node->node_name);
            $cur_value = llsd_parse_contents($node, $node->node_name());
            break;
        }
        break;
    case XML_TEXT_NODE:
        // Skip this, it's not a "value".  Should never happen, the caller should notice this.
        break;
    }
    return $cur_value;
}

//
// Parse the contents of an LLSD map from the DOM branch
//
function llsd_parse_map_contents($branch)
{
    $object = array();
    $objptr = &$object;


    $cur_key = '';
    $cur_value = '';
    // Iterate through all of the children.
    // The children need to alternate between keys and values
    $child = $branch->first_child();
    while ($child)
    {
        if (!($child->is_blank_node()))
        {
            switch ($child->node_type())
            {
            case XML_TEXT_NODE:
                // FIXME: Should verify that this is whitespace?
                break;
            case XML_ELEMENT_NODE:
                // Now fill in cur_key or cur_value depending on the node
                if ('key' == $child->node_name())
                {
                    $cur_key = llsd_parse_contents($child, 'string');
                }
                else // Switch based on different LLSD types
                {
                    $cur_value = llsd_parse_value($child);

                    // We've got a key/value pair, add it to the map.
                    $object[$cur_key] = $cur_value;
                    $cur_value = '';
                }
                break;
            }
        }
        $child = $child->next_sibling();
    }
    return $object;
}

//
// Parse an LLSD array from a DOM branch
//
function llsd_parse_array_contents($branch)
{
    $object = array();
    $objptr = &$object;


    $cur_key = '';
    $cur_value = '';
    // Iterate through all of the children.
    // The children need to alternate between keys and values
    $child = $branch->first_child();
    while ($child)
    {
        if (!($child->is_blank_node()))
        {
            switch ($child->node_type())
            {
            case XML_TEXT_NODE:
                // FIXME: Should verify that this is whitespace?
                break;
            case XML_ELEMENT_NODE:
                // We've got a key/value pair, add it to the map.
                $object[] = llsd_parse_value($child);
                $cur_value = '';
                break;
            }
        }
        $child = $child->next_sibling();
    }
    return $object;
}

// function llsd_parse_contents($branch, $type)
function llsd_parse_contents($branch, $type)
{
    $child = $branch->first_child();
    while ($child)
    {
        if (!($child->is_blank_node()))
        {
            switch ($child->node_type())
            {
            case XML_TEXT_NODE:
                switch ($type)
                {
                case 'integer':
                    return (int)$child->get_content();
                case 'real':
                    return (float)$child->get_content();
                case 'bool':
                    if ("true" == $child->get_content())
                    {
                        return true;
                    }
                    else
                    {
                        return false;
                    }
                default:
                    // Treat everything else as a string
                    return $child->get_content();
                }
            }
        }
        $child = $child->next_sibling();
    }
    return false;
}
