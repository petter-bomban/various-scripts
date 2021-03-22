## Script to demonstrate how jobs can be used
## This specific script starts a new job to recursively
## loop through each sub-folder in C:\

## Keep it mind that I have not split this into individual functions,
## to keep the demonstration simple and linear.
## I'd probably want some job-handler functins if this
## was in production, and doing something more complex.

$Path = "C:\"

## Initial setup of the individual jobs we'll run.
$JobItems = Get-ChildItem -Path $Path

## For piecing together the tree at the end
$FinalTree = @()

## For identifying jobs later
$JobPrefix = "TreeTest"
$JobNumber = 0

## Using Start-Sleep a couple of places to save CPU cycles
$WaitTime = 1 # seconds

## We'll run one job per childitem in $Path
## This is the first of two for-loops. One for starting, one for receiving.
foreach ($Item in $JobItems) {

    ## Processing outside of the job itself
    ## For example top-level items that are not folders
    ## continue out of the for-loop on to the next item if so
    if ($Item.Attributes -notlike "*Directory*") {

        $FinalTree += $Item
        continue
    }

    ## This is the code that will be running inside of the jobs
    $ScriptBlock = {

        ## The $Using: modifier will tell the job that the variable scope
        ## is from the parent process.
        $CurrentFolder = $Using:Item

        $JobChildItems = Get-ChildItem -Path $CurrentFolder.FullName -Recurse

        return $JobChildItems
    }

    ## Kicking off the job. This ends the current for-loop, and goes to the next one
    ## We receive all of the jobs together at the end.

    $JobName = $JobPrefix + "_" + "$JobNumber"
    Start-Job -Name $JobName -ScriptBlock $ScriptBlock

    ## Next job has a higher number
    $JobNumber +=1
}

## Wait for job completion
## We receive each job as it gets the status "Completed"
## Better to do this on a per-job basis, so we can add error-handling
$Completed = $false
while ($Completed -eq $false) {

    ## Get all current jobs in this session
    $AllJobs = Get-Job -Name "$JobPrefix*"

    ## If there are no more jobs, end
    if (($AllJobs.State -eq "Completed") -and ($AllJobs.HasMoreData -eq $False)) {

        $Completed = $True
    }

    foreach ($Job in $AllJobs) {

        ## If the job is still running, skip to see if next one is.
        ## The while-loop ensures that we get to all of them in the end.
        if ($Job.State -ne "Completed") {

            Start-Sleep -Seconds $WaitTime
            continue
        }

        ## Further error-handling here, like for example if status is Blocked or Failed
        ## ...

        ## Job's done! Add results to $FinalTree
        ## Note that "HasMoreData" is important. If the job is completed AND already received,
        ## .HasMoreData will be $false. $true signifies that the job has not delivered its data.
        if (($Job.State -eq "Completed") -and ($Job.HasMoreData -eq $true)) {
            
            $JobResult = Receive-Job -Name $Job.Name
            $FinalTree += $JobResult

            Write-Host "$(Job.Name) has completed!"
        }
    }
}

$FinalTree

