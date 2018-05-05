<?php
    /*
     * Ajax-based JQuery utility to tail a web logfile.
     * @author	Gyula Annár <annargy@geo.hu>
     */
    session_start();
    // Hardwired path to prevent abuse.
    $path=$_SERVER['DOCUMENT_ROOT']."/log/";
    // Same (probably symlinked as) filename, .log extension.
    $filename=basename($_SERVER['SCRIPT_NAME'], ".php") . '.log';
    $file = $path.$filename;
    // Ajax call from JS, getting log lines.
    if (isset($_REQUEST['ajax'])) {
	$handle = fopen($file, 'r');
	// Continue from position saved previously.
	if (isset($_SESSION[$filename.'.offset'])) {
    	    $data = stream_get_contents($handle, 4096, $_SESSION[$filename.'.offset']);
	    echo nl2br($data);
        }
	// EOF on first run also (does not show old lines).
	fseek($handle, 0, SEEK_END);
	// Save position.
	$_SESSION[$filename.'.offset'] = ftell($handle);
	exit();
    }
    // Non-Ajax call, shows logger UI.
?>

<!doctype html>
<html>
<head>
    <meta charset="UTF-8">
    <title><?php echo $filename; ?></title>
    <style type="text/css">
	body {
	    font-family:Courier;
	    color: #dddddd;
	    background: #000000;
	    border: 0px double #CCCCCC;
	    padding: 5px;
	}
    </style>
    <script src="jquery.min.js"></script>
    <script>
    // Poll the logfile
    $(function() {
	setInterval( function() {
	    $.ajax({
		type: "GET",
		url: <?php echo '"'.$_SERVER['SCRIPT_NAME'].'"'; ?>,
		data: "ajax=true",
		async: false,
		success: function(response){
        	    // append
		    $('#tail').append(response);
    		    // then scroll
    		    $('html, body').animate({ scrollTop: $(document).height() }, 1200);
		    }
	    });
	},1000);
    });
    </script>
</head>
<body>
    <div id="tail"><?=$file;?>:<br /></div>
</body>
</html>
