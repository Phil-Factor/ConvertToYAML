
function ConvertTo-YAML
{
<#
 .SYNOPSIS
   creates a YAML description of the data in the object
 .DESCRIPTION
   This produces YAML from any object you pass to it. It isn't suitable for the huge objects produced by some of the cmdlets such as Get-Process, but fine for simple objects
 .EXAMPLE
   $array=@()
   $array+=Get-Process wi* |  Select-Object Handles,NPM,PM,WS,VM,CPU,Id,ProcessName 
   ConvertTo-YAML $array

 .PARAMETER Object 
   the object that you want scripted out
 .PARAMETER Depth
   The depth that you want your object scripted to
 .PARAMETER Nesting Level
   internal use only. required for formatting
#>
	
	[CmdletBinding()]
	param (
		[parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)][AllowNull()] $inputObject,
		[parameter(Position = 1, Mandatory = $false, ValueFromPipeline = $false)] [int] $depth = 16,
		[parameter(Position = 2, Mandatory = $false, ValueFromPipeline = $false)] [int] $NestingLevel = 0,
		[parameter(Position = 3, Mandatory = $false, ValueFromPipeline = $false)] [int] $XMLAsInnerXML = 0
	)
	
	BEGIN { }
	PROCESS
	{
		If ($inputObject -eq $Null) { $p += 'null'; return $p } # if it is null return null
		if ($NestingLevel -eq 0) { '---' }
		
		$padding = [string]'  ' * $NestingLevel # lets just create our left-padding for the block
		try
		{
			$Type = $inputObject.GetType().Name # we start by getting the object's type
			if ($Type -ieq 'Object[]') { $Type = "$($inputObject.GetType().BaseType.Name)" } #what it really is
			if ($depth -ilt $NestingLevel) { $Type = 'OutOfDepth' } #report the leaves in terms of object type
			elseif ($Type -ieq 'XmlDocument' -or $Type -ieq 'XmlElement')
			{
				if ($XMLAsInnerXML -ne 0) { $Type = 'InnerXML' }
				else
				{ $Type = 'XML' }
			} # convert to PS Alias
			# prevent these values being identified as an object
			if (@('boolean', 'byte', 'char', 'datetime', 'decimal', 'double', 'float', 'single', 'guid', 'int', 'int32',
			'int16', 'long', 'int64', 'OutOfDepth', 'RuntimeType', 'PSNoteProperty', 'regex', 'sbyte', 'string',
			'timespan', 'uint16', 'uint32', 'uint64', 'uri', 'version', 'void', 'xml', 'datatable', 'List`1',
			'SqlDataReader', 'datarow', 'ScriptBlock', 'type') -notcontains $type)
			{
				if ($Type -ieq 'OrderedDictionary') { $Type = 'HashTable' }
				elseif ($Type -ieq 'PSCustomObject') { $Type = 'PSObject' } #
				elseif ($inputObject -is "Array") { $Type = 'Array' } # whatever it thinks it is called
				elseif ($inputObject -is "HashTable") { $Type = 'HashTable' } # for our purposes it is a hashtable
				elseif (($inputObject | gm -membertype Properties |
				Select name | Where name -like 'Keys') -ne $null) { $Type = 'generic' } #use dot notation
				elseif (($inputObject | gm -membertype Properties | Select name).count -gt 1) { $Type = 'Object' }
			}
			write-verbose "$($padding)Type:='$Type', Object type:=$($inputObject.GetType().Name), BaseName:=$($inputObject.GetType().BaseType.Name) "
			
			switch ($Type)
			{
				'ScriptBlock'{ "{$($inputObject.ToString())}" }
				'InnerXML'        { "|`r`n" + ($inputObject.OuterXMl.Split("`r`n") | foreach{ "$padding$_`r`n" }) }
				'DateTime'   { $inputObject.ToString('s') } # s=SortableDateTimePattern (based on ISO 8601) using local time
				'Boolean' {
					"$(&{
						if ($inputObject -eq $true) { '`true' }
						Else { '`false' }
					})"
				}
				'string' {
					$String = "$inputObject"
					if ($string -match '[\r\n]' -or $string.Length -gt 80)
					{
						# right, we have to format it to YAML spec.
						">`r`n" # signal that we are going to use the readable 'newlines-folded' format
						$string.Split("`n") | foreach {
							$bits = @(); $length = $_.Length; $IndexIntoString = 0; $wrap = 80
							while ($length -gt $IndexIntoString + $Wrap)
							{
								$earliest = $_.Substring($IndexIntoString, $wrap).LastIndexOf(' ')
								$latest = $_.Substring($IndexIntoString + $wrap).IndexOf(' ')
								$BreakPoint = &{
									if ($earliest -gt ($wrap + $latest)) { $earliest }
									else { $wrap + $latest }
								}
								if ($earliest -lt (($BreakPoint * 10)/100)) { $BreakPoint = $wrap } # in case it is a string without spaces
								$padding + $_.Substring($IndexIntoString, $BreakPoint).Trim() + "`r`n"
								$IndexIntoString += $BreakPoint
							}
							if ($IndexIntoString -lt $length) { $padding + $_.Substring($IndexIntoString).Trim() + "`r`n" }
							else { "`r`n" }
						}
					}
					else { "'$($string -replace '''', '''''')'" }
				}
				'Char'     { "([int]$inputObject)" }
				{
					@('byte', 'decimal', 'double', 'float', 'single', 'int', 'int32', 'int16', `
					'long', 'int64', 'sbyte', 'uint16', 'uint32', 'uint64') -contains $_
				}
				{ "$inputObject" } # rendered as is without single quotes
				'PSNoteProperty' { "$(ConvertTo-YAML -inputObject $inputObject.Value -depth $depth -NestingLevel ($NestingLevel + 1))" }
				'Array'    { "$($inputObject | ForEach { "`r`n$padding- $(ConvertTo-YAML -inputObject $_ -depth $depth -NestingLevel ($NestingLevel + 1))" })" }
				'HashTable'{
					("$($inputObject.GetEnumerator() | ForEach {
						"`r`n$padding  $($_.Name): " +
						(ConvertTo-YAML -inputObject $_.Value -depth $depth -NestingLevel ($NestingLevel + 1))
					})")
				}
				'PSObject' { ("$($inputObject.PSObject.Properties | ForEach { "`r`n$padding $($_.Name): " + (ConvertTo-YAML -inputObject $_ -depth $depth -NestingLevel ($NestingLevel + 1)) })") }
				'generic'  { "$($inputObject.Keys | ForEach { "`r`n$padding  $($_):  $(ConvertTo-YAML -inputObject $inputObject.$_ -depth $depth -NestingLevel ($NestingLevel + 1))" })" }
				'Object'   { ("$($inputObject | Get-Member -membertype properties | Select-Object name | ForEach { "`r`n$padding $($_.name):   $(ConvertTo-YAML -inputObject $inputObject.$($_.name) -depth $NestingLevel -NestingLevel ($NestingLevel + 1))" })") }
				'XML'   { ("$($inputObject | Get-Member -membertype properties | where-object { @('xml', 'schema') -notcontains $_.name } | Select-Object name | ForEach { "`r`n$padding $($_.name):   $(ConvertTo-YAML -inputObject $inputObject.$($_.name) -depth $depth -NestingLevel ($NestingLevel + 1))" })") }
				'DataRow'   { ("$($inputObject | Get-Member -membertype properties | Select-Object name | ForEach { "`r`n$padding $($_.name):  $(ConvertTo-YAML -inputObject $inputObject.$($_.name) -depth $depth -NestingLevel ($NestingLevel + 1))" })") }
				#  'SqlDataReader'{$all = $inputObject.FieldCount; while ($inputObject.Read()) {for ($i = 0; $i -lt $all; $i++) {"`r`n$padding $($Reader.GetName($i)): $(ConvertTo-YAML -inputObject $($Reader.GetValue($i)) -depth $depth -NestingLevel ($NestingLevel+1))"}}
				default { "'$inputObject'" }
			}
		}
		catch
		{
			write-error "Error'$($_)' in script $($_.InvocationInfo.ScriptName) $($_.InvocationInfo.Line.Trim()) (line $($_.InvocationInfo.ScriptLineNumber)) char $($_.InvocationInfo.OffsetInLine) executing $($_.InvocationInfo.MyCommand) on $type object '$($inputObject)' Class: $($inputObject.GetType().Name) BaseClass: $($inputObject.GetType().BaseType.Name) "
		}
		finally { }
	}
	
	END { }
}

 