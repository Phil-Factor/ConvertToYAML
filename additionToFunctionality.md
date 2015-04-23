
# Converting XML files to YAML or PSON

The other day, I needed to convert a whole stack of XML files to YAML.  Actually , I would have settled for a conversion to JSON, but for some reason, the built-in cmdlet wouldn’t do it. I was trying to figure out a way of doing the YAML conversion when I suddenly remembered I’d actually already published a way of doing it, in ‘Getting Data Into and Out of PowerShell Objects’. With relief, I got the routine out and tried it. It didn’t work, because I’d chosen to display an XML value as an innerXML string. This is the behaviour you might want, but not in this case.

There are two different ways of rendering XML values. You can render the object represented by the XML or you can do it just as an InnerXML string. The former method allows us to convert XML files directly into YAML or PSON.  Useful?  Sure. It is easier to demo than explain. First  rendering it as an object…

``` PowerShell
$xml= [Xml] @'
 <emp id='12345' salary='60000'>
 <name>
  <first>William</first>
  <last>Murphy</last>
 </name>
 <spouse>
  <name>
   <first>Cecilia Bertha Matilda</first>
   <last>Murphy</last>
  </name>
 </spouse>
 <dept id='K55'>Finance</dept>
</emp>
'@
 ConvertTo-YAML $xml
```
…giving …
—
``` YAML
 emp:  
   dept:  
     #text:   'Finance'
     id:   'K55'
   id:   '12345'
   name:  
     first:   'William'
     last:   'Murphy'
   salary:   '60000'
   spouse:  
     name:  
       first:   'Cecilia Bertha Matilda'
       last:   'Murphy'
 ``` 

and the other way, simply giving it as an XML fragment, (note the parameter if you want that behaviour)  is.
 ``` PowerShell
xml= [Xml] @'
 <emp id='12345' salary='60000'>
 <name>
  <first>William</first>
  <last>Murphy</last>
 </name>
 <spouse>
  <name>
   <first>Cecilia Bertha Matilda</first>
   <last>Murphy</last>
  </name>
 </spouse>
 <dept id='K55'>Finance</dept>
</emp>
'@
 ConvertTo-YAML $xml -XMLAsInnerXML 1
``` 
… giving …
``` YAML
—
|
<emp id="12345" salary="60000"><name><first>William</first><last>Murphy</last></name><spouse><name><first>Cecilia Bertha matilda</first><last>Murphy</last></name></spouse><dept id="K55">Finan
ce</dept></emp>
 ``` 

It turned out that it was just as easy to handle the XML as an object as an XML document, and I’d already developed a way of doing a PowerShell object. After modifying the routine, and updating the article, I tried again. Nice. It worked a treat, and the YAML parser gulped it all in with no complaint. It wasn’t quick by any means with multi-megabyte XML files, but who cares when there are good videos to be watched? 