## Microsoft Teams Profiles

#### Decsiption
A bunch of functions ready to use to do Teams admin as if they're commandlets. Currently its mainly geared towards Operator Connect and Calling plans but does support Direct Routing as part of the profiles although I have not tested with multiple direct routing providers in the same tenant.

    Function Get-SCTeamsProfiles
	Function Set-SCTeamsProfiles -SCProfile ProfileObject
	Function New-SCTeamsProfile -ProfileName Some_Name -Domain MyDomain.local -PhoneNumberType DirectRouting -RoutingPolicy Global -DialOutPolicy DialoutCPCandPSTNDomestic -CallingLineIdentity ACompany 08001231234 -Description "Some kind of profile details"
	Function New-SCTeamsUser -ProfileName BCP -LoginName John.Smith -PSTN +442071231234
	Function Remove-SCTeamsUserPSTN -ProfileName Sales -LoginName John.Smith
	Function Get-SCHuntGroups -FileName Output.csv
	Function Get-SCOperatorConnectUsers -FileName Output.csv
	Function Get-SCTeamsUser -ProfileName ICT -LoginName Anna.Parson
	Function Get-SCPhoneNumber -PSTN +442071231234
	Function Get-SCFreeUserNumber -NumberType OperatorConnect
	Function Test-SCTeamsProfile -ProfileName ICT

 You need to 'load' the functions by running ". .\SCTeamsProfiles.ps1" from where ever you've put the files
 and if you're clever you might put this in your powershell profile by running "notepad $profile" and adding
 ". .\SCTeamsProfiles.ps1" to the end of the file, amending the path to SCTeamsProfiles.ps1 and this is 
 called dot sourcing. 

 Also this uses .\TeamsProfiles.json as a way of storing configured profiles.   
