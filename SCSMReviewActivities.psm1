Function Get-SCSMActivityReviewer
{
<#
    .SYNOPSIS 
    This function gets the Review users from a review acitivity in SCSM.
      
    .DESCRIPTION
     A function gets the Review users from a review activity in SCSM. The object used must be from the get-scsmobject in the smlets module (the -Useradd variable is the user object from SCSM).
      
    .EXAMPLE
    
     Get-SCSMActivityReviewer -ID RA1234 

     .EXAMPLE
     
     $RA = Get-SCSMObject -class (Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$) -Filter "ID -eq RA125"
     
     Get-SCSMActivityReviewer -ReviewActivity $RA 

#>
[CmdletBinding(DefaultParameterSetName="string")]
[OutputType([PSObject])]
param(
    
    [Parameter(Mandatory=$true,ParameterSetName="string")]
    [string]$ID,
    [Parameter(Mandatory=$true,ParameterSetName="object")]
    [PSObject]$ReviewActivity 
)

    Begin
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Started ***"
        #Create Collection to return
        $Users = @()

        $RAC = Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$
        $ReviewerRelationship = Get-SCSMRelationshipClass -Name System.ReviewActivityHasReviewer$
        $ReviewerIsUser = Get-SCSMRelationshipClass -Name System.ReviewerIsUser$
    }
    process
    {
        try
        {
            if($PSCmdlet.ParameterSetName -eq "string")
            {
                $ReviewActivity = Get-SCSMObject -Class $RAC -Filter "ID -eq $ID"
            }
            $Reviewers = Get-SCSMRelatedObject -SMObject $ReviewActivity -Relationship $ReviewerRelationship
            foreach($Reviewer in $Reviewers)
            {
                $user = Get-SCSMRelatedObject -SMObject $Reviewer -Relationship $ReviewerIsUser
                $Users += $user
            }
        }
        catch
        {
               Write-Error $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    End
    {
        if($Users.count -gt 0)
        {
            Write-Output $Users
        }
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Finished ***"
    }

}


Function Add-SCSMActivityReviewer
{
    <#
    .SYNOPSIS 
    This function adds a user to a review acitivity in SCSM.
      
    .DESCRIPTION
     A function to add a user to a review activity in SCSM. The object used must be from the get-scsmobject in the smlets module (the -Useradd variable is the user object from SCSM).
      
    .EXAMPLE
    
     Add-SCSMActivityReviewer -Useradd $SCSMUser -RActivity $RAObject

     .EXAMPLE
     Add-SCSMActivityReviewer -Username rplank -ActivityID RA123 

     .EXAMPLE
     Add-SCSMActivityReviewer -username rplank -ActivityID RA1234 -domain <DomainNetbiosName>
#>
[CmdletBinding(DefaultParameterSetName="string")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="string")]
        [string]$ActivityID,
        [Parameter(Mandatory=$true,ParameterSetName="string")]
        [string]$username,
        [Parameter(Mandatory=$false,ParameterSetName="string")]
        [string]$domain,
        [Parameter(Mandatory=$True,ParameterSetName="Object")]
        [PSObject[]]$Useadd,
        [Parameter(Mandatory=$True,ParameterSetName="Object")]
        [PSObject]$RActivity    
    )
    begin
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Started ***"
        $relClassReviewerIsUser = Get-SCSMRelationshipClass System.ReviewerIsUser$
        $relClassReviewActivityHasReviewer = Get-SCSMRelationshipClass System.ReviewActivityHasReviewer$
        $Reviewers = @()
        $ReviewActivityClass = Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$

        

    }
    
    Process
    {
        try
        {
        
            if($PSCmdlet.ParameterSetName -eq "Object")
            {
                # Build a Collection of current Reviewers
                $ReviewerList = Get-SCSMRelatedObject -SMObject $RActivity  -relationship $relClassReviewActivityHasReviewer 
                foreach($Reviewer in $ReviewerList)
                {
                    $Review = Get-SCSMRelatedObject -SMObject $Reviewer -Relationship $relClassReviewerIsUser
                    $Reviewers += $Review
                }
                foreach ($User in $Useadd)
                {
                    if($Reviewers -notcontains $user)
                    {
                        $reviewerClass = get-scsmclass System.Reviewer
                        $reviewerArgs = @{ ReviewerId = "Reviewer{0}" } 
                        $reviewer = new-scsmobject -class $reviewerClass -PropertyHashtable $reviewerArgs -nocommit
                        $rel01 = new-scsmrelationshipobject -nocommit  -Relationship $relClassReviewActivityHasReviewer -sou $RActivity -tar $reviewer
                        $rel02 = new-scsmrelationshipobject -nocommit  -rel $relClassReviewerIsUser -Sour $reviewer -targ $User
                        $rel01.commit()
                        $rel02.commit()
                    }
                }
            }
            if($PSCmdlet.ParameterSetName -eq "string")
            {
                Write-Verbose "Get Review Activity from Id"
                $RActivity = Get-SCSMObject -Class $ReviewActivityClass -Filter "ID -eq $ActivityID"
                Write-Verbose "Build a Collection of current Reviewers"
                $ReviewerList = Get-SCSMRelatedObject -SMObject $RActivity  -relationship $relClassReviewActivityHasReviewer 
                foreach($Reviewer in $ReviewerList)
                {
                    $Review = Get-SCSMRelatedObject -SMObject $Reviewer -Relationship $relClassReviewerIsUser
                    $Reviewers += $Review
                }
                $user = Get-SCSMuser -username $username 
                if($domain -ne $null)
                {
                    if($user.Count -gt 1)
                    {
                        foreach($u in $user)
                        {
                            if($u.Domain -eq $domain)
                            {
                                $user = $u
                                
                            }
                        }
                    }
                }
                if($Reviewers -notcontains $user)
                {
                    $reviewerClass = get-scsmclass System.Reviewer
                    $reviewerArgs = @{ ReviewerId = "Reviewer{0}" } 
                    $reviewer = new-scsmobject -class $reviewerClass -PropertyHashtable $reviewerArgs -nocommit
                    $rel01 = new-scsmrelationshipobject -nocommit  -Relationship $relClassReviewActivityHasReviewer -sou $RActivity -tar $reviewer
                    $rel02 = new-scsmrelationshipobject -nocommit  -rel $relClassReviewerIsUser -Sour $reviewer -targ $User
                    $rel01.commit()
                    $rel02.commit()
                }
            }
        }
        catch
        {
            Write-Error $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end
    {       
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Finished ***"
    }
 }

Function Remove-SCSMActivityReviewer
 {
 <#
    .SYNOPSIS 
    This function removes a user from a review acitivity in SCSM.
      
    .DESCRIPTION
     A function to remove a user from a review activity in SCSM. The object used must be from the get-scsmobject in the smlets module (the -Useradd variable is the user object from SCSM).
      
    .EXAMPLE
    
     Remove-SCSMActivityReviewer -ActivityID RA1234 -username userA

     .EXAMPLE
     $user = Get-SCSMObject -class (Get-SCSMClass -name System.domain.User$) -Filter "username -eq <username>"
     $RA = Get-SCSMObject -class (Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$) -Filter "ID -eq RA125"
     
     Remove-SCSMActivityReviewer -Activity $RA -username $user

#>

    [CmdletBinding(DefaultParameterSetName="string")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="string")]
        [string]$ActivityID,
        [Parameter(Mandatory=$true,ParameterSetName="string")]
        [string]$username,
        [Parameter(Mandatory=$true,ParameterSetName="object")]
        [PSObject]$Activity,
        [Parameter(Mandatory=$true,ParameterSetName="object")]
        [PSObject]$user

    )
    begin
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Started ***"
        try
        {
            $ReviewActivityClass = Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$
            $ReviewerIsUser = Get-SCSMRelationshipClass System.ReviewerIsUser$
            $ReviewerRelationship = Get-SCSMRelationshipClass -Name System.ReviewActivityHasReviewer$
        }
        catch
        {
            Write-Error $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    process
    {
        try
        {
            if($PSCmdlet.ParameterSetName -eq "string")
            {
                $ReviewActivity = Get-SCSMObject -Class $ReviewActivityClass -Filter "ID -eq $ActivityID"
            }
            $Reviewers = Get-SCSMRelatedObject -SMObject $ReviewActivity -Relationship $ReviewerRelationship

            foreach($Reviewer in $Reviewers)
            {
                $userobj = Get-SCSMRelatedObject -SMObject $Reviewer -Relationship $ReviewerIsUser
                if($PScmdlet.ParameterSetName -eq "string")
                {
                    if($userobj.username -eq $username)
                    {
                        $ReviewertoUserRelationship = Get-SCSMRelationshipObject -TargetObject $Userobj -TargetRelationship $ReviewerIsUser
                        $ActivitytoReviewerRelationship = Get-SCSMRelationshipObject -TargetObject $ReviewertoUserRelationship.SourceObject -TargetRelationship $ReviewerRelationship
                        $ActivitytoReviewerRelationship | Remove-SCSMRelationshipObject
                        $ReviewertoUserRelationship | Remove-SCSMRelationshipObject 
                    }
                }
                Elseif($PSCmdlet.ParameterSetName -eq "object")
                {
                    if($user.username -eq $userobj.username)
                    {
                        $ReviewertoUserRelationship = Get-SCSMRelationshipObject -TargetObject $Userobj -TargetRelationship $ReviewerIsUser
                        $ActivitytoReviewerRelationship = Get-SCSMRelationshipObject -TargetObject $ReviewertoUserRelationship.SourceObject -TargetRelationship $ReviewerRelationship
                        $ActivitytoReviewerRelationship | Remove-SCSMRelationshipObject
                        $ReviewertoUserRelationship | Remove-SCSMRelationshipObject 
                    }
                }
            }
        }
        catch
        {
            Write-Error $PSCmdlet.ThrowTerminatingError($_)
        }

    }
    End
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Finished ***"
    }
 }


Function Update-SCSMActivityReviewer
{

    [cmdletbinding(DefaultParameterSetName="Single")]
    Param(
        [Parameter(Mandatory=$true,ParameterSetName="Single")]
        [string]$ExistingReviewer,
        [Parameter(Mandatory=$true,ParameterSetName="Single")]
        [string]$NewReviewer,
        [Parameter(Mandatory=$True,ParameterSetName="Single")]
        [string]$ActivityID,
        [Parameter(Mandatory=$false,ParameterSetName="Bulk")]
        [switch]$InProgress,
        [Parameter(Mandatory=$false,ParameterSetName="Bulk")]
        [switch]$Pending
    )
    begin
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Started ***"
        $ReviewActivityClass = Get-SCSMClass -Name System.WorkItem.Activity.ReviewActivity$
        $MatchedRAs = @()
    }
    Process
    {
        try
        {
            if($PSCmdlet.ParameterSetName -eq "Bulk")
            {
                if($InProgress -eq $true)
                {
                    $InProgressID = (Get-SCSMEnumeration -name activitystatusenum.active$).ID
                    $ReviewActivities = Get-SCSMobject -class $ReviewActivityClass -Filter "Status -eq $InProgressID"

                }
                if($Pending -eq $true)
                {
                    $PendingID = (get-SCSMEnumeration -name  ActivityStatusEnum.Ready).ID
                    $ReviewActivities = Get-SCSMobject -class $ReviewActivityClass -Filter "Status -eq $PendingID"
            
                }
                if($InProgress -eq $false -and $Pending -eq $false)
                {
                    Write-Error "Select a switch for Bulk editing"
                }
            }
            else
            {
                $ReviewActivities = Get-SCSMobject -class $ReviewActivityClass -Filter "ID -eq $ActivityID"
            }
            foreach($RA in $ReviewActivities)
            {
                $Reviewers = Get-SCSMActivityReviewer -ReviewActivity $RA
                foreach($Reviewer in $Reviewers)
                {
                    if($Reviewer.username -eq $ExistingReviewer)
                    {
                        $MatchedRAs += $RA.ID
                    }
                }
            }
            if($MatchedRAs.count -gt 0)
            {
                Foreach($RA in $MatchedRAs)
                {
                    Remove-SCSMActivityReviewer -ActivityID $RA -username $ExistingReviewer
                    Add-SCSMActivityReviewer -ActivityID $RA -username $NewReviewer
                }
            }
            else
            {
                Write-output "No Review Activities Matched your Criteria"
            }
        }
        catch
        {
            Write-Error $PSCmdlet.ThrowTerminatingError($_)
        }
    }
    end
    {
        Write-Verbose "*** $($MyInvocation.MyCommand.CommandType) $($MyInvocation.MyCommand.Name) Finished ***"
    }

}
 
