﻿#This script is what grabs data from the DPS servers and can run in one of two modes:
#option = 1: grab data from the links up on the DPS report log website
#option = 2: iterate through a hardcoded range of valid dates and attempt to download them from the DPS website
function update-logs{
    [CmdletBinding(DefaultParameterSetName='ByUserName')]
    param(
         [int] $option = 1,
         [Parameter (
            mandatory=$True,
            valueFromPipeline=$True,
            valueFromPipelineByPropertyName=$True)]
         [string] $projectpath,
         [switch] $updateDataset,
         [string] $datasetname = "Backup2016.dps",
         [string] $website
    )

    [string]$convertedFilePath=""
    #Finding your current directory

    #Start-sleep -seconds 5
    #Establishing PDFConverter function
    . $projectpath\bin\APICall.ps1

    if($updateDataset){
        . $projectpath\bin\DPSTextParser2.ps1
        $reportArray= new-object System.Collections.ArrayList
    }

    #Initializing an arraylist called links which will contain a list of links to download the report from for that day
    [System.Collections.ArrayList] $links = new-object System.Collections.ArrayList

    #-----------------PHASE 1: Generate Links------------------#
	#option 1
	
	if ($option -eq 1)
	{
		
        $site = Invoke-WebRequest http://dps.usc.edu/alerts/log/ -sessionvariable sesh
        $links = $site.Content | grep "http://dps.usc.edu/files" | %{$_.split('"')[1]} | grep "http://dps.usc.edu/files"
    }
    #option 2
    if($option -eq 2){
    
        [int[]] $daysinthemonth = 31,28,31,30,31,30,31,31,30,31,30,31
        #hard coded date range in format month, day, year
        [int[]] $startdate= 1,1,15
        [int[]] $enddate= 1,1,16
    
        #get the day of the week it is and initialize the daycount to that day
        $daycounthelper= Get-Date -Month $startdate[0] -Day $startdate[1] -Year (2000+$startdate[2])
        $daycount=$daycounthelper.DayOfWeek.value__-1 #0=monday, 6=sunday

        #while startdate hasn't reached enddate
        while (($startdate[0] -ne $enddate[0]) -or ($startdate[1] -ne $enddate[1]) -or ($startdate[2] -ne $enddate[2])){
        
            #conditional to ensure no weekends are counted
            if($daycount -ne 5 -and $daycount -ne 6){

                $month=$startdate[0]
                $day=$startdate[1]
                $year=$startdate[2]

                #generate link
                $linkstring="http://dps.usc.edu/files/20{2}/{0}/{0}{1}{2}.pdf" -f $month.tostring("00"), $day.tostring("00"), $year.toString("00")
                [void]$links.add($linkstring) 
            }

            #increment the daycount
            $daycount=$daycount+1
            if($daycount -eq 7){
                $daycount=0
            }

            #increment the day, month, and year as appropriate
            $startdate[1]=$startdate[1]+1
            if($startdate[1] -gt $daysinthemonth[$startdate[0]-1]){
                $startdate[1]=1
                $startdate[0]+=1
                if($startdate[0] -gt 12){
                    $startdate[0]=1
                    $startdate[2]+=1
                }
            }
        }  
    }
    if($option -eq 3){
        $links.add($website)
    }
    #-----------------PHASE 2: Download from the links------------------#
    write-verbose "Entering phase 2"
    $count=0
    for ($i=$links.count-1; $i -ge 0; $i--){
        $link=$links[$i]
        #Extracting the file name from the link and converting to a .txt file
        $txtname=$link -split "/"
        $txtname=$txtname[$txtname.length-1]
        $txtname=$txtname -replace ".pdf",".txt"

        $month=$txtname.substring(0,2)
        $year=$txtname.substring(4,2)

        #Creating folders if they don't already exist
        if(-Not (Test-Path $projectpath\dpsreports\20$year)){
            Write-verbose "20$year year folder does not exist. Creating folder"
            mkdir $projectpath\dpsreports\20$year
        }
        if(-Not (Test-Path $projectpath\dpsreports\20$year\$month)){
            Write-verbose "$month month folder does not exist. Creating folder"
            mkdir $projectpath\dpsreports\20$year\$month
        }

        #Downloading the file if it doesn't already exist
        if (-Not (Test-Path $projectpath\dpsreports\20$year\$month\$txtname)){
            
            Write-verbose "$txtname does not exist"
            Write-verbose "Pulling data from $link" 
            try{
            
                #check if this is a valid link	
                $site=Invoke-WebRequest $link 

                #calls convertpdf function with given link and filepath to store data in
                apicall -link $link -path $projectpath -quiet
                if($updateDataSet){
                    write-verbose "Appending to Dataset"
                    $retval = parsereports2 -option 4 -filepath $projectpath -file $txtname -generateDataset -dataset $datasetname -append -suppress
                    write-verbose "Appended to Dataset"
                }
				$count+=1
			}
			catch
			{
				Write-Error "An error has occured"
				Write-Error $_.Exception.Message
			}
			
		}
	}
	
    if($count -eq 0){
        return 0 #no files were downloaded
	}
	else
	{
		return 1
	}
}