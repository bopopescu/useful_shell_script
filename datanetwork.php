<?php 

session_start(); 

if(!(isset($_SESSION['user']))) {  header("Location: index.html"); exit; } 

?>

<html>
<head>

<script type="text/javascript">
  function SendControlMessage(msg)
  {
      parent.socket.send(msg);
  }
  
  function imagesSelected(myFiles)
  {
	  for (var i = 0, f; f = myFiles[i]; i++)
	  {
              //uploadAndSubmit(f);
              SendControlMessage('control:play;1.png;1;2');
         }
}

function imagesShared(myFiles)
{
	  
	  for (var i = 0, f; f = myFiles[i]; i++)
	  {
               /*var imageReader = new FileReader();
	       imageReader.onload = (function(aFile)
	       {
		       return function(e)
		       {
			       var span = document.createElement('span');
			       span.innerHTML = ['<img class="images" draggable="true" ondragstart="dragStart(event)" src="1/',aFile.name,'" title="', aFile.name, '"/>'].join('');
			       console.log("Insert span---\n");
			       document.getElementById('thumbs').insertBefore(span, null);
                       };
	       })(f);

	       imageReader.readAsDataURL(f);*/
	       
	       var span = document.createElement('span');
	       span.innerHTML = ['<img class="images" width="100" height="100" draggable="true" ondragstart="dragStart(event)" src="1/',f.name,'" title="', f.name, '"/>'].join('');
	       console.log("Insert span---\n");
	       document.getElementById('thumbs').insertBefore(span, null);

               uploadAndSubmit(f);
         }
}

function dragStart(e)
{ 	
    e.dataTransfer.setData("imagename", e.target.getAttribute("title"));  
}  

function dragOver(e)
{
    e.preventDefault();
    return false;
}  

function dropIt(e)
{
   e.preventDefault();
   e.stopPropagation();  
   var URL = e.dataTransfer.getData("imagename");
   //imagesSelected(e.dataTransfer.files);    
   SendControlMessage("control:play;"+URL+";1;2");
}  

function uploadAndSubmit(file)
{ 
    if (file != null && file != undefined)
    { 
        var reader = new FileReader(); 
		  
	reader.onloadstart = function()
        { 
        } 
	reader.onprogress = function(p)
        { 
  	} 
        reader.onload = function()
        { 
        } 	
	reader.onloadend = function() 
        { 
		if (reader.error)
	       	{ 
		     console.log(reader.error); 
		}
	       	else
	       	{ 
		     var xhr = new XMLHttpRequest(); 
		     xhr.open("POST",  "file_upload.php", true); 
		     xhr.overrideMimeType("application/octet-stream"); 

                     xhr.setRequestHeader("X-File-Name", file.name);
                     xhr.setRequestHeader("X-User-Id", "1");
		  
                     if(!XMLHttpRequest.prototype.sendAsBinary)
                     {
                         XMLHttpRequest.prototype.sendAsBinary = function(datastr) 
                         {
                            function byteValue(x) {
                               return x.charCodeAt(0) & 0xff;
                            }
                         var ords = Array.prototype.map.call(datastr, byteValue);
                         var ui8a = new Uint8Array(ords);
                         this.send(ui8a.buffer);
                       }
                    }

                     xhr.sendAsBinary(reader.result); 
		     xhr.onreadystatechange = function()
	             { 
			     if (xhr.readyState == 4)
			     { 
				     if (xhr.status == 200)
				     { 
		                         console.log("upload complete"); 
		                         console.log("response: " + xhr.responseText); 
	                             } 
	                     } 
                     } 
               } 
	} 		                                         
	                                             
        reader.readAsBinaryString(file); 
    } 
    else
    { 
	alert ("Please drag a file to upload.");
    } 
} 

	        /*var iFrame = parent.document.getElementById("content");
                var doc = iFrame.contentWindow?iFrame.contentWindow.document:iFrame.contentDocument;
                doc.getElementById("VCtrl").addEventListener("pause", function ()
                {
                    SendControlMessage("control:pause;1.png;1");
                }, false);

                doc.getElementById("VCtrl").addEventListener("playing", function ()
                {
                    SendControlMessage("control:paly;1.png;1");
                }, false);
*/
 

</script>

</head>
<body>
	    <p><h2>192.168.18.129---MyCloud<h2></p>
            <hr>
	    <br>

<div>
<center>
<table cellspacing=0 cellpadding=5>
<tr>
<th>Remote device</th>
<td align="left" height="105" ondragenter="return false" ondragover="dragOver(event)" ondrop="dropIt(event)"><img id = "Dev" class="images" src="dev.png" draggable="false">
</td>
</tr>
</table>
</center>
</div>

<div id="ImgVideo" align="center">
 <table>
  <tr>
   <td>
    <img id="ImgDisplay" class="images" src="" width="500" height="400">
   </td>
   <td>
    <video id="VCtrl" autoplay width="500" height="410" src="" type='video/mp4; codecs="avc1.42E01E, mp4a.40.2"'>
    </video>
   </td>
  </tr>
 </table>
</div>

<br>
<p>Choose images to share:</p>
<p> <input type="file" multiple="true" onchange="imagesShared(this.files)" /></p>
<hr>

<table width="500" cellspacing=0 cellpadding=5>
<tr>
<td align="left" width="500" height="105">
<output id="thumbs"></output> 
</td>
</tr>
</table>

</body>
</html>

