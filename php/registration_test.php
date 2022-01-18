<?php
require_once('llsd.php');

// FILL THESE IN WITH YOUR OWN CAPABILITY URLS
define('URI_CREATE_USER', '?????????');
define('URI_GET_LAST_NAMES', '?????????');
define('URI_CHECK_NAME', '?????????');

if ($_SERVER['REQUEST_METHOD'] == 'POST')
{
    if (is_name_available($_POST['username'], $_POST['last_name_id']))
    {
        $user = array
        (
            'username'     => $_POST['username'],
            'last_name_id' => (int)$_POST['last_name_id'],
            'email'        => $_POST['email'],
            'password'     => $_POST['password'],
            'dob'          => $_POST['dob_year'].'-'.$_POST['dob_month'].'-'.$_POST['dob_day']
        );

        $result = llsd_post(URI_CREATE_USER, $user);
        print $result['agent_id'];
    }
    else
    {
        print 'SL name not available.';
    }
}
?>

<h3>Create Second Life Account</h3>

<form action="<?php print $_SERVER['PHP_SELF']; ?>" method="post">

<table border="0" cellpadding="3" cellspacing="0">
<tr>
  <td>First name:</td>
  <td><input type="text" name="username" size="25" maxlength="31" value="" /></td>
</tr>
<tr>
  <td>Last name:</td>
  <td>
  <select name="last_name_id">
  <?php
  $last_names = llsd_get(URI_GET_LAST_NAMES);
  foreach ($last_names as $last_name_id => $name)
  {
      print '<option value="'.$last_name_id.'">'.$name.'</option>';
  }
  ?>
  </select>
  </td>
</tr>
<tr>
    <td>Password:</td>
    <td><input type="password" name="password" size="20" value="" /></td>
</tr>
<tr>
    <td>Email:</td>
    <td><input type="text" name="email" size="35" value="" /></td>
</tr>
<tr>
    <td>Date of brith:</td>
    <td>
    <select name="dob_day">
    <?php
    $days = get_days();
    foreach ($days as $key => $value) { print '<option value="'.$key.'" '.$selected.'>'.$value.'</option>'; }
    ?>
    </select>

    <select name="dob_month">
    <?php
    $months = get_months();
    foreach ($months as $key => $value) { print '<option value="'.$key.'" '.$selected.'>'.$value.'</option>'; }
    ?>
    </select>

    <select name="dob_year">
    <?php
    $years = get_years();
    foreach ($years as $key => $value) { print '<option value="'.$key.'" '.$selected.'>'.$value.'</option>'; }
    ?>
    </select>
    </td>
</tr>
<tr>
    <td></td>
    <td><input type="submit" value="Create SL Account" /></td>
</table>

</form>

<?php
function get_months()
{
    $months = array();
    for ($i = 1; $i <= 12; $i++)
    {
        $key = date('n', mktime(0, 0, 0, $i, 1, 2000));
        $value = date('M.', mktime(0, 0, 0, $i, 1, 2000));
        $months[sprintf("%02d", $key)] = $value;
    }
    return $months;
}

function get_years()
{
    $today = getdate();
    $max_year = $today['year'] - 90;
    $min_year = $today['year'] - 13;

    $years = array();
    for ($i = $min_year; $i >= $max_year; $i--)
    {
        $years[$i] = $i;
    }
    return $years;
}

function get_days()
{
    $days = array();
    for ($i = 1; $i <= 31; $i++)
    {
        $days[sprintf("%02d", $i)] = sprintf("%02d", $i);
    }
    return $days;
}

function is_name_available($username, $last_name_id)
{
    $params = array('username' => $username, 'last_name_id' => (int)$last_name_id);
    if (llsd_post(URI_CHECK_NAME, $params) == 'true')
    {
        return true;
    }
    return false;
}
?>
