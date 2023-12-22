<#
  A bunch of functions ready to use to do Teams admin as if they're commandlets.
	Function Get-SCTeamsProfiles
	Function Set-SCTeamsProfiles -SCProfile ProfileObject
	Function New-SCTeamsProfile -ProfileName Some_Name -Domain MyDomain.local -PhoneNumberType DirectRouting -RoutingPolicy Global -DialOutPolicy DialoutCPCandPSTNDomestic -CallingLineIdentity SMOOR 03003037800 -Description "Some kind of profile details"
	Function New-SCTeamsUser -ProfileName BCP -LoginName John.Smith -PSTN +441234123123
	Function Remove-SCTeamsUserPSTN -ProfileName BCP -LoginName John.Smith
	Function Get-SCHuntGroups -FileName Output.csv
	Function Get-SCOperatorConnectUsers -FileName Output.csv
	Function Get-SCTeamsUser -ProfileName SCC -LoginName Nick.James
	Function Get-SCPhoneNumber -PSTN +441234123123
	Function Get-SCFreeUserNumber -NumberType OperatorConnect
	Function Test-SCTeamsProfile -ProfileName BCP

  
  You need to 'load' the functions by running ". .\SCTeamsProfiles.ps1" from where ever you've put the files
  and if you're clever you might put this in your powershell profile by running "notepad $profile" and adding
  ". .\SCTeamsProfiles.ps1" to the end of the file, amending the path to SCTeamsProfiles.ps1 and this is 
  called dot sourcing. 

  Also this uses .\TeamsProfiles.json as a way of storing configured profiles.

  Usefull automatic varibles are :-
		$Pwd            : Current directory
		$Home           : Windows profile directory 
		$Profile        : Where your powershell profile lives
		$PSVersionTable : What version of powershell you have
  
  
#>


Function Get-SCTeamsProfiles {
	
<#
Load the profiles from a JSON file and return the PSObject
#>
	
	# Build absolute file path
	$SCFilePath = ".\TeamsProfiles.json"
	$ProfilesPath = Join-Path -Path (Resolve-Path -Path (Split-Path -Parent $SCFilePath)).ProviderPath -ChildPath (Split-Path -Leaf $SCFilePath)
	
	# If file doesn't exist do some stuff
	If ( $False -eq (Test-Path -Path $ProfilesPath -PathType leaf)) { 
		
		# There must be a CR/LF between the @" symbol and the actual string/text
		# Spaces and further CR/LF matter?
		$JSONString = @"
[
[
{ "ProfileName":"Default",
  "Domain":"Your.domain",
  "PhoneNumberType":"DirectRouting",
  "RoutingPolicy":"Global",
  "DialOutPolicy":"DialoutCPCandPSTNDomestic",
  "CallingLineIdentity":"General 0300",
  "Description":"Default profile for staff"
}
]
]
"@
	# Build object from JSON
	$TeamsProfiles = $JSONString | ConvertFrom-Json
	# Write JSON file back Out with default profile
	Set-SCTeamsProfiles -SCProfile $TeamsProfiles
	
	}
	Else {
		$TeamsProfiles = get-content -raw $ProfilesPath | convertfrom-json
	}
	

	# Return object so can be piped
	$TeamsProfiles
}


Function Test-SCTeamsProfile {
<#
	Use this in validation scripts to check if a profile exists
	Example :-
		Param (
			[ValidateScript({Test-SCTeamsProfile -ProfileName $_}, ErrorMessage = "Invalid Profile! Run Get-SCTeamsProfiles to see a list of profiles")] [Parameter(Mandatory=$True)] [string[]] $ProfileName
		)
		
	https://powershell.one/powershell-internals/attributes/validation
#>
	
Param ( [String] $ProfileName)
	$TeamsProfiles = Get-SCTeamsProfiles

	# Get the profile passed from the ProfileName perameter
	$AProfile = $TeamsProfiles | Where-object "ProfileName" -eq $ProfileName
	
	if ($Null -ne $AProfile) {Return $True}
	Else {Return $False}
}

Function Get-SCTeamsUser { [CmdletBinding()]
<#
.Synopsis
	Gets the details of a Teams voice user.
	
   .Description 
	Gets the details and policies of a Teams user. 
	The TeamsProfile json file is used to 'build' the UPN/SIPAdress.
	
   .Parameter ProfileName
    The profile name used to select the required domain details.
   
   .Parameter LoginName
    Used to build the UPN/SIPAddress of the user usually first.lastname (john.smith) but could be intials+lastname (JASmith).
	
    .Example 
	Get-SCTeamsUser -ProfileName Sales -LoginName John.Smith

#>


	param (
	[ValidateScript({Test-SCTeamsProfile -ProfileName $_}, ErrorMessage = "Invalid Profile! Run Get-SCTeamsProfiles to see a list of profiles")] [Parameter(Mandatory=$True)] [string[]] $ProfileName, 
	[ValidateNotNullOrEmpty()] [Parameter(Mandatory=$True)] [string[]] $LoginName)

	$TeamsProfiles = Get-SCTeamsProfiles

	# Get the profile passed from the ProfileName perameter
	$AProfile = $TeamsProfiles | Where-object "ProfileName" -eq $ProfileName
	

	# Output the selected profile object to console
	Write-Verbose "Profile selected : $AProfile.ProfileName"
	
	# Build UPN of the user and display passed details, needing to trim the strings for some reason
	$SIPAddress = $LoginName.Trim() + "@" +$AProfile.Domain.Trim()
	Write-Verbose  "`e[93m Name : $LoginName | SIP Address : $SIPAddress`e[0m"
	
	# Get users current details and if there is an error exit gracefully 
	Try {
		Get-CsOnlineUser -Identity $SIPAddress | Format-List -Property lineuri, displayname, SipAddress, UserPrincipalName, Alias, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, DialPlan, HostedVoiceMail, HostedVoicemailPolicy, VoicePolicy, CallingLineIdentity, TenantDialPlan ,TeamsCallingPolicy, Company, Department
	}
	Catch {
		Write-Host "`e[1;5;41m`u{1F641} User not found `u{1F641}`e[0m"
		Write-Host "`a" #Beep
		Write-Host $_
	
	}
}


Function Set-SCTeamsProfiles {
	Param (
		[PSObject]$SCProfile
		)
<#
Allows you to save the profiles object to the JSON file. Used by New-SCTeamsProfile
#>

	# Build file path for JSON file	
	$SCFilePath = ".\TeamsProfiles.json"
	$ProfilesPath = Join-Path -Path (Resolve-Path -Path (Split-Path -Parent $SCFilePath)).ProviderPath -ChildPath (Split-Path -Leaf $SCFilePath)
	
	# Assume failure to write file as the result
	$WritingFileSuccessful = $False
	
	Try {
		Write-Host "Writing $SCFilePath"
		# Write profile object to JSON file. Check if file exists?
		$SCProfile | ConvertTo-Json | Set-Content -Path $ProfilesPath
		$WritingFileSuccessful = $True
	}
	Catch {
		Write-Host "Something went wrong writing profiles!"
		Write-Host "`a" # send a 'beep' sound to default audio device
		Write-Host $_
	}
	# Return result
	$WritingFileSuccessful
}


Function New-SCTeamsProfile {
	Param ( 
		[String]$ProfileName,
		[String]$Domain,
		[String]$PhoneNumberType,
		[String]$RoutingPolicy,
		[String]$DialOutPolicy,
		[String]$CallingLineIdentity,
		[String]$Description
	) 

<#
Add a new profile to the current profiles object and saves it to the JSON file
#>
	
<#
	Build JSON string to convert to json. Luckily you varibles are substituted in 
	the string if you use double quotes (nice ;)) 
#>
	$NewJson = @"
[
[
{ "ProfileName":"$ProfileName",
  "Domain":"$Domain",
  "PhoneNumberType":"$PhoneNumberType",
  "RoutingPolicy":"$RoutingPolicy",
  "DialOutPolicy":"$DialOutPolicy",
  "CallingLineIdentity":"$CallingLineIdentity",
  "Description":"$Description"
}
]
]
"@

	# Load exisitng JSON file
	$TeamsProfiles = Get-SCTeamsProfiles
	
	# Create object from built JSON string
	$NewjsonObj = $newJson | ConvertFrom-Json
	
	# Some fuckery combining both objects as literal and converting them to JSON and back again to make the new object
	$JsonObj = @($TeamsProfiles, $NewJsonObj) | ConvertTo-Json | ConvertFrom-Json  	
	
	# Write back to JSON file replacing content
	Set-SCTeamsProfiles -SCProfile $JsonObj

}

Function New-SCTeamsUser { [CmdletBinding()]

<# 
   .Synopsis
	Configure a user to have a phone number and required policies.
	
   .Description 
	Configure a user using a pre-configured profile of Teams features and policies defined in TeamsProfiles.json. 
	The json file can be manipulated to create multiple profiles independant of organisation using this commandlet.
	
   .Parameter ProfileName
    The organisation unit or profile name used to select the required features and policies
   
   .Parameter LoginName
    Used to build the UPN of the user normally first.lastname (john.smith) but could be intials+lastname (JASmith).
	
   .Parameter PSTN
    The phone number in +441234123123 format (E.164) 
	
   .Example 
	New-SCTeamsUser -ProfileName SDC -LoginName John.Smith -PSTN +441234123123

	New-SCTeamsUser | import-csv -Path ".\Users.csv"

	New-SCTeamsUser | ConvertFrom-JSON | Get-Content -Raw -Path ".\users.json"
	
   .Remark	
   Read TeamsProfiles.JSON file to see if its any good for redoing the profiling of new teams users.
		https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-7.3
   
   Requires PowerShell 7.x, that you've loaded the Teams Module and logged in. Thats what the '#Requires' keyword above does (like a compiler hint)
   
   The parameters passed are mandatory
   
   Using escape characters instead of -foregroud or -background as it seems more stable for Write-Host's 
		https://en.wikipedia.org/wiki/ANSI_escape_code
		https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_special_characters?view=powershell-7.3
		https://duffney.io/usingansiescapesequencespowershell/
   
   The object $AProfile contains (so far):-
		$AProfile.ProfileName
		$AProfile.Domain
		$AProfile.PhoneNumberType
		$AProfile.RoutingPolicy
		$AProfile.DialOutPolicy
		$AProfile.CallingLineIdentity
		$AProfile.Description
		
#>
[CmdletBinding()]
param (
	[ValidateScript({Test-SCTeamsProfile -ProfileName $_}, ErrorMessage = "Invalid Profile! Run Get-SCTeamsProfiles to see a list of profiles")] [Parameter(Mandatory=$True)] [string] $ProfileName, 
	[ValidateNotNullOrEmpty()] [Parameter(Mandatory=$True)] [string] $LoginName, 
	[ValidatePattern ("^\+(?:[0-9]?){6,14}[0-9]$")] [string] $PSTN
)

Begin { # Get Profiles and start transcript
		# Get profiles
		$TeamsProfiles = Get-SCTeamsProfiles
		Start-Transcript .\TeamsHistory.txt -Append -UseMinimalHeader
	} # Begin block

process { # Do some actual stuff
		# use this for later
		$decision = 0
		
		# Get the profile passed from the ProfileName perameter
		$AProfile = $TeamsProfiles | Where-object "ProfileName" -eq $ProfileName

		# Output the selected profile object to console
		$AProfile | Format-List

		# Build UPN of the user and display passed details, needing a bit of a trim the strings for some reason
		$SIPAddress = $LoginName.Trim() + "@" +$AProfile.Domain.Trim()
		Write-Host  "`e[93m Name : $LoginName | Phone Number : $PSTN | SIP Address : $SIPAddress`e[0m"
	
		# Get users current details and if there is an error exit gracefully 
		Try { # try to find the person
			Get-CsOnlineUser -Identity $SIPAddress | Format-Table -AutoSize -Property lineuri, displayname, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, Company, CallingLineIdentity
		}
		Catch { # Display any errors
		Write-Host "`e[1;5;41m`u{1F641} User not found? `u{1F641}`e[0m"
		Write-Host "`a" #Beep
		Write-Host $_
		$decision = 1
		
	}	
		
		# Check if user already has a phone number and ask if you want to continue with configuring user 
		$TestUser = get-CsOnlineUser -Identity $SIPAddress
		#$TestUser
	
		
		# check if user has a phone number and if the Get-CsOnlineUser failed
		If ($null -ne $TestUser.LineURI -and $decision -eq 0) {
			$title    = "Existing user!"
			$question = "Are you sure you want to proceed?"
		
			$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
			$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
			$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
		
			$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
		}
		# Check that the user was found and if user has a number you want to proceed 
		if ($decision -eq 0) {
			Write-Host "`e[1;42m ***Confirmed*** `e[0m"
			<#	The bit that actually does stuff is encapsulated in a try..catch code block so if an error happens 
				the code exits sort of gracefully! nb. I haven't a Finally as there isn't anything to clear up
	
				There is some weirdness with $PSTN looking like a array so forced the issue with $PSTN[0], maybe $PSTN[1] contains 
				a control/null character returned from the regex'd parameter ? 
			#>
			Try {
				Write-Host "Setting up user..."
				Set-CsPhoneNumberAssignment -Identity $SIPAddress -PhoneNumber $PSTN -PhoneNumberType $AProfile.PhoneNumberType
				Grant-CsCallingLineIdentity -Identity $SIPAddress -PolicyName $AProfile.CallingLineIdentity
				Grant-CsDialoutPolicy -Identity $SIPAddress -PolicyName $AProfile.DialOutPolicy
				If ($AProfile.RoutingPolicy -eq "Global") { Grant-CsOnlineVoiceRoutingPolicy -Identity $SIPAddress -PolicyName $Null }
				Else {Grant-CsOnlineVoiceRoutingPolicy -Identity $SIPAddress -PolicyName $AProfile.RoutingPolicy }
				
				# Display resulting user details
				Get-CsOnlineUser -Identity $SIPAddress |Format-List -Property lineuri, displayname, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, Company, CallingLineIdentity
			
			}
			Catch {
				Write-Host "`e[1;5;41m`u{1F641} Couldn't setup Teams Enterprise Voice for user `u{1F641}`e[0m"
				Write-Host "`a" # send a 'beep' sound to default audio device
				Write-Host $_
		}
	} # Decision not equals 0
	else { 
			Write-Host "`e[1;41m *** Aborted Process *** `e[0m"
	}
} # Process block

End { # Clear stuff up and stop Transcript
	Write-Host "End :-"
	Write-Host "--| Clear up stuff |--".padleft(30)
	Stop-Transcript
} # End block


} # End New-SCTeamsUser function


Function Remove-SCTeamsUserPSTN{ [CmdletBinding()]
	
<# 
   .Synopsis
	Removes PSTN ability from a Teams user.
	
   .Description 
	Removes all policies, the phone number and Enterprise Voice from a Teams user. 
	The TeamsProfile json file is used to 'build' the UPN/SIPAdress.
	
   .Parameter ProfileName
    The organisation unit or profile name used to select the required domain 
   
   .Parameter LoginName
    Used to build the UPN/SIPAddress of the user usually first.lastname (john.smith) but could be intials+lastname (JASmith).
	
    .Example 
	Remove-SCTeamsUserPSTN -ProfileName SDC -LoginName Brian.Derham
	
   .Remark	
   Read TeamsProfiles.JSON file to see if its any good for redoing the profiling of new teams users.
		https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/convertfrom-json?view=powershell-7.3
   
   Requires PowerShell 7.x, that you've loaded the Teams Module and logged in. Thats what the '#Requires' keyword above does (like a compiler hint)
   
   The parameters passed are mandatory
   
   Using escape characters instead of -foregroud or -background as it seems more stable for Write-Host's 
		https://en.wikipedia.org/wiki/ANSI_escape_code
		https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_special_characters?view=powershell-7.3
		https://duffney.io/usingansiescapesequencespowershell/
   
 		
#>
	param (
	[ValidateScript({Test-SCTeamsProfile -ProfileName $_}, ErrorMessage = "Invalid Profile! Run Get-SCTeamsProfiles to see a list of profiles")] [Parameter(Mandatory=$True)] [string[]] $ProfileName, 
	[ValidateNotNullOrEmpty()] [Parameter(Mandatory=$True)] [string[]] $LoginName)

	$TeamsProfiles = Get-SCTeamsProfiles

	# Get the profile passed from the ProfileName perameter
	$AProfile = $TeamsProfiles | Where-object "ProfileName" -eq $ProfileName
	
	# Output the selected profile object to console
	Write-Verbose "Profile selected : $AProfile.ProfileName"
	
	# Build UPN of the user and display passed details, needing to trim the strings for some reason
	$SIPAddress = $LoginName.Trim() + "@" +$AProfile.Domain.Trim()
	Write-Host  "`e[93m Name : $LoginName | Phone Number : $PSTN | SIP Address : $SIPAddress`e[0m"
	
	Start-Transcript .\TeamsHistory.txt -Append -UseMinimalHeader
	
	# Get users current details and if there is an error exit gracefully 
	Try {
		# If its going to fail it'll be here
		Get-CsOnlineUser -Identity $SIPAddress | Format-List -Property lineuri, UserPrincipalName, displayname, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, CallingLineIdentity, Company, Department

		$TestUser = Get-CsOnlineUser -Identity $SIPAddress 
		
		If ($TestUser.EnterpriseVoiceEnabled -ne $False) {
			# We know the user exists as we got some details
			$title    = "Selected User"
			$question = "Are you sure you want to proceed?"
			
			$choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
			$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
			$choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))
			
			# ******************** Needs Testing *********************
			# If you use -Force as a parameter it should just continue
			# ********************************************************
			$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
			if ($decision -eq 0) {
				Write-Host "`e[93m Please wait Removing PSTN from $LoginName `e[0m"
			
				Remove-CsPhoneNumberAssignment -Identity $SIPAddress -RemoveAll
				Grant-CsOnlineVoiceRoutingPolicy -Identity $SIPAddress -PolicyName $Null
				Grant-CsCallingLineIdentity -Identity $SIPAddress -PolicyName $Null
				Grant-CsDialoutPolicy -Identity $SIPAddress -PolicyName $Null
	
				Get-CsOnlineUser -Identity $SIPAddress | Format-List -Property lineuri, UserPrincipalName, displayname, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, CallingLineIdentity, Company, Department
			} 
			else {	Write-Host -ForegroundColor red "*** Aborted Process ***"}
		}
	}
	Catch {
		# Failled to get user details, most likely not exist, typo or similar 
		Write-Host "`e[1;5;41m`u{1F641} User not found `u{1F641}`e[0m"
		Write-Host "`a" #Beep
		Write-Host $_
	}	
		
	Stop-Transcript
	Write-Host "Finished."
}

Function Get-SCHuntGroups {
	<#
	.Synopsis
	Get a list of all hunt group phone numbers.
	
   .Description 
	Get a list of all auto-atendants and call queue phone numbers, either to the screen or saved to a csv file.
	
   .Parameter FileName
    Optional filename used for saving the list to a CSV file
   
   .Example 
	
   Saves a list of hunt groups to a csv file 

        Get-SCHuntGroups -FileName MyList.csv

	Display a list of hunt groups to your console

		Get-SCHuntGroups
	#>

	Param ($FileName)

	if ($Null -ne $FileName) {
		Get-CsOnlineApplicationInstance | Where-Object phonenumber -ne $null| sort-object phonenumber | Select-Object PhoneNumber, DisplayName, UserPrincipalName | Export-Csv $FileName
		} Else {
		Get-CsOnlineApplicationInstance | Where-Object phonenumber -ne $null| sort-object phonenumber | Format-Table -property DisplayName, PhoneNumber, UserPrincipalName
	}
}

Function Get-SCOperatorConnectUsers { [CmdletBinding()]
	Param ($FileName)
	
	
	# Currently only returns a single range so a workaround is to specify each range
	$AreaCodes=@("+441278435", "+441278436","+441278619")
	
	# Loop for each area code in list above
	foreach ($AreaCode in $AreaCodes){
		# -and $_.AssignedPstnTargetId -ne $null
		foreach ($PhoneNumber in Get-CsPhoneNumberAssignment -TelephoneNumberStartsWith $AreaCode| Where-Object {$_.NumberType -eq "OperatorConnect" } ){
				# If no user is assigned then add some details
				If ($null -ne $PhoneNumber.AssignedPstnTargetId) {
					$User.LineURI = $PhoneNumber.TelephoneNumber
					$User.LineURI = $User.LineURI
					$User.DisplayName = "Spare Line"
					$User.UserPrincipalName = "None"
				}
				Else {
					# Get user details instead of a GUID
					$User = get-csonlineuser -id $PhoneNumber.AssignedPstnTargetId | select-Object LineURI, AccountType, DisplayName, UserPrincipalName
					#Replace number with one without the prefix "Tel:"
					$User.LineURI = $PhoneNumber.TelephoneNumber
					
				}
				
				# $User | Add-Member -NotePropertyName PstnPartnerName -NotePropertyValue $PhoneNumber.PstnPartnerName
			if ($Null -ne $FileName) {
				
				# Pipe details to csv file
				$User | export-csv -append -force $FileName 
				
				# Show some pretty feedback so you know something is happening	
				$WindowSize = $Host.UI.RawUI.WindowSize
				
				$CurPos = $host.UI.RawUI.CursorPosition
				Write-host -nonewline -BackgroundColor green -ForegroundColor black $user.LineURI  $user.DisplayName  " ".padright($windowSize.Width-$user.displayname.length-15," ")
				
				$host.UI.RawUI.CursorPosition = $CurPos}
		
			else {
				$User #| format-table -hidetableheaders -autosize
			}
				
		}
	}
	Write-Host ""
	Write-Host "Done."
}

Function Get-SCPhoneNumber {
<#
.Synopsis
	Get the details of a phone number.
	
   .Description 
	Get extended details of a phone number whether its a user, auto attendant, call queue or conference number.
		
   .Parameter PSTN
    The phone number in +441234123123 format (E.164) 
	
   .Example 
   Get-SCPhoneNumber -PSTN +441234123123

       Phone Number Details
       ----------------------

       TelephoneNumber         : ++441234123123
       OperatorId              : 0dba58a4-00a1-4e4e-8aac-f34efc0bbdba
       NumberType              : OperatorConnect
       ActivationState         : Activated
       AssignedPstnTargetId    : 3d6abcc8-eeef-498d-9102-5ddfe1c6fc1b
       AssignmentCategory      : Primary
       Capability              : {UserAssignment}
       City                    : Bridgwater
       CivicAddressId          : ef3d6d5a-1872-4249-a80c-6a00fe534b6d
       IsoCountryCode          : GB
       IsoSubdivision          : All
       LocationId              : fe39d157-4ecd-4201-d587-412674c2c30e
       LocationUpdateSupported : False
       NetworkSiteId           :
       PortInOrderStatus       :
       PstnAssignmentStatus    : UserAssigned
       PstnPartnerId           : 81dc6b74-53e4-43ae-a8a1-578aabb79e04
       PstnPartnerName         : Gamma

        User Details
       --------------
       LineUri                  : tel:+441234123123
       UserPrincipalName        : John.Smith@homesinsedgemoor.org
       DisplayName              : John Smith
       EnterpriseVoiceEnabled   : True
       OnlineDialOutPolicy      : DialoutCPCandPSTNDomestic
       OnlineVoiceRoutingPolicy :
       CallingLineIdentity      : CompanyCLI
       Company                  : ACompany
       Department               :
#>

[CmdletBinding()]
param (	[ValidatePattern ("^\+(?:[0-9]?){6,14}[0-9]$")] [string] $PSTN )


	$Number = Get-CsPhoneNumberAssignment -TelephoneNumber "$PSTN"
	If ($Null -ne $Number.TelephoneNumber){
		Write-Host -foreground green " Phone Number Details"
		Write-Host -foreground green "----------------------"
		$Number 
		If ($Number.PstnAssignmentStatus -ne "Unassigned") {
			If ($Null -ne $Number.AssignedPstnTargetId ) {
				Write-Host -foreground green " User Details"
				Write-Host -foreground green -Nonewline "--------------"
				$User = Get-CsOnlineUser -id $Number.AssignedPstnTargetId 
				$User | Format-List -Property lineuri, UserPrincipalName, displayname, EnterpriseVoiceEnabled, OnlineDialOutPolicy, OnlineVoiceRoutingPolicy, CallingLineIdentity, Company, Department  
			}
			If ($Number.PstnAssignmentStatus -eq "VoiceApplicationAssigned"){
				Write-Host -foreground green " Online Application Details"
				Write-Host -foreground green "----------------------------"
				Get-CsOnlineApplicationInstance  -Identity $user.identity | Format-List
			}
			If ($Number.PstnAssignmentStatus -eq "ConferenceAssigned") {
				Write-Host -foreground green " Conference Details "
				Write-Host -foreground green "--------------------"
				Get-CsOnlineDialInConferencingServiceNumber | where-object number -eq $Number.TelephoneNumber.substring(1)
			}
	}
	}
	Else { Write-Host -foreground green "Number not found" }
	

}

Function Get-SCFreeUserNumber { [CmdletBinding()]
<#
	.Synopsis
	Get a free phone number.
	
   .Description 
	Returns a random free phone number from either Operator Connect or a Calling Plan.
	
   .Parameter NumberType
    The type of number required either "OperatorConnect" or "CallingPlan"
   
   
   .Example 

	Exampe 1

	Get-SCFreeUserNumber CallingPlan

	Example 2
	$NumberType = "OperatorConnect"
	$PSTN = Get-SCFreeUserNumber $NumberType
	Set-CsPhoneNumberAssignment -Identity $SIPAddress -PhoneNumber $PSTN -PhoneNumberType


	Example 3

	$PSTN = Get-SCFreeUserNumber OperatorConnect
	Write-Host "Phone Number : $PSTN"
	New-SCTeamsUser -ProfileName SDC -LoginName Brian.Derham -PSTN $PSTN 

	
#>	

	param (
	[ValidateSet('OperatorConnect','CallingPlan')]  [Parameter(Mandatory=$True, position = 0)] [string[]] $NumberType
	)

	$AllNumbers = Get-CsPhoneNumberAssignment -ActivationState Activated -PstnAssignmentStatus Unassigned | Where-Object {$_.NumberType.Contains($NumberType)}
	If ($AllNumbers.Count -gt 0) {
		$RandNumber = get-random -Minimum 0 -Maximum ($AllNumbers.count - 1)
	
		return $AllNumbers.Item($RandNumber).TelephoneNumber
	}
}






