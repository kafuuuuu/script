<#
.SYNOPSIS
    为所有用户从 Windows 11 中移除内置应用（现代应用）。

.DESCRIPTION
    此脚本将移除 `blacklistedapps` 变量中指定的所有内置应用。

    ##警告##
    请谨慎使用，恢复已删除的预配包并不是一个简单的过程。

    ##提示##
    如果要移除 "MicrosoftTeams"，也请考虑通过 Intune 设置目录禁用任务栏上的“聊天”图标，因为点击该图标会为用户重新安装该 appxpackage。

.NOTES

    思路基于一个最初用于移除 Windows 10 应用的脚本 / 鸣谢：Nickolaj Andersen @ MSEndpointMgr
    对原始脚本进行了修改，将 Appx 的处理方式从白名单改为黑名单

    文件名:      Remove-Appx-AllUsers-CloudSourceList.ps1
    作者:        Ben Whitmore
    联系方式:    @byteben
    日期:        2022 年 6 月 27 日

###### Windows 11 应用 ######

Microsoft.549981C3F5F10 (Cortana Search)
Microsoft.BingNews
Microsoft.BingWeather
Microsoft.DesktopAppInstaller
Microsoft.GamingApp
Microsoft.GetHelp
Microsoft.Getstarted
Microsoft.HEIFImageExtension
Microsoft.MicrosoftEdge.Stable
Microsoft.MicrosoftOfficeHub
Microsoft.MicrosoftSolitaireCollection
Microsoft.MicrosoftStickyNotes
Microsoft.Paint
Microsoft.People
Microsoft.PowerAutomateDesktop
Microsoft.ScreenSketch
Microsoft.SecHealthUI
Microsoft.StorePurchaseApp
Microsoft.Todos
Microsoft.UI.Xaml.2.4
Microsoft.VCLibs.140.00
Microsoft.VP9VideoExtensions
Microsoft.WebMediaExtensions
Microsoft.WebpImageExtension
Microsoft.Windows.Photos
Microsoft.WindowsAlarms
Microsoft.WindowsCalculator
Microsoft.WindowsCamera
microsoft.windowscommunicationsapps
Microsoft.WindowsFeedbackHub
Microsoft.WindowsMaps
Microsoft.WindowsNotepad
Microsoft.WindowsSoundRecorder
Microsoft.WindowsStore
Microsoft.WindowsTerminal
Microsoft.Xbox.TCUI
Microsoft.XboxGameOverlay
Microsoft.XboxGamingOverlay
Microsoft.XboxIdentityProvider
Microsoft.XboxSpeechToTextOverlay
Microsoft.YourPhone
Microsoft.ZuneMusic
Microsoft.ZuneVideo
MicrosoftTeams
MicrosoftWindows.Client.WebExperience
#>

Begin {

    # 日志函数
    function Write-LogEntry {
        param (
            [parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            [string]$Value,
            [parameter(Mandatory = $false)]
            [ValidateNotNullOrEmpty()]
            [string]$FileName = "AppXRemoval.log",
            [switch]$Stamp
        )
    
        # 构建日志文件，并将系统日期/时间追加到输出内容中
        $LogFile = Join-Path -Path $env:SystemRoot -ChildPath $("Temp\$FileName")
        $Time = -join @((Get-Date -Format "HH:mm:ss.fff"), " ", (Get-WmiObject -Class Win32_TimeZone | Select-Object -ExpandProperty Bias))
        $Date = (Get-Date -Format "MM-dd-yyyy")
    
        If ($Stamp) {
            $LogText = "<$($Value)> <time=\"$($Time)\" date=\"$($Date)\">"
        }
        else {
            $LogText = "$($Value)"   
        }
        
        Try {
            Out-File -InputObject $LogText -Append -NoClobber -Encoding Default -FilePath $LogFile -ErrorAction Stop
        }
        Catch [System.Exception] {
            Write-Warning -Message "Unable to add log entry to $LogFile.log file. Error message at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
        }
    }

    # 用于移除 AppxProvisionedPackage 的函数
    Function Remove-AppxProvisionedPackageCustom {

        # 尝试移除 AppxProvisioningPackage
        if (!([string]::IsNullOrEmpty($BlackListedApp))) {
            try {
            
                # 获取包名
                $AppProvisioningPackageName = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1
                Write-Host "$($BlackListedApp) found. Attempting removal ... " -NoNewline
                Write-LogEntry -Value "$($BlackListedApp) found. Attempting removal ... "

                # 执行移除
                $RemoveAppx = Remove-AppxProvisionedPackage -PackageName $AppProvisioningPackageName -Online -AllUsers
                
                # 重新检查是否仍然存在
                $AppProvisioningPackageNameReCheck = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $BlackListedApp } | Select-Object -ExpandProperty PackageName -First 1

                If ([string]::IsNullOrEmpty($AppProvisioningPackageNameReCheck) -and ($RemoveAppx.Online -eq $true)) {
                    Write-Host @CheckIcon
                    Write-Host " (Removed)"
                    Write-LogEntry -Value "$($BlackListedApp) removed"
                }
            }
            catch [System.Exception] {
                Write-Host " (Failed)"
                Write-LogEntry -Value "Failed to remove $($BlackListedApp)"
            }
        }
    }

    Write-LogEntry -Value "##################################"
    Write-LogEntry -Stamp -Value "Remove-Appx Started"
    Write-LogEntry -Value "##################################"

    # 操作系统检查
    $OS = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    Switch -Wildcard ( $OS ) {
        '21*' {
            $OSVer = "Windows 10"
            Write-Warning "This script is intended for use on Windows 11 devices. $($OSVer) was detected..."
            Write-LogEntry -Value "This script is intended for use on Windows 11 devices. $($OSVer) was detected..."
            Exit 1
        }
    }
    # 需要为所有用户移除的 Appx 预配包黑名单
    $BlackListedApps = $null
    $BlackListedApps = New-Object -TypeName System.Collections.ArrayList
    $BlackListedApps.AddRange(@(
            "Microsoft.BingNews",
            "Microsoft.GamingApp",
            "Microsoft.MicrosoftSolitaireCollection",
            "Microsoft.WindowsCommunicationsApps",
            "Microsoft.WindowsFeedbackHub",
            "Microsoft.XboxGameOverlay",
            "Microsoft.XboxGamingOverlay",
            "Microsoft.XboxIdentityProvider",
            "Microsoft.XboxSpeechToTextOverlay",
            "Microsoft.YourPhone",
            "Microsoft.ZuneMusic",
            "Microsoft.ZuneVideo",
            "MicrosoftTeams"
        ))
 
    # 定义图标
    $CheckIcon = @{
        Object          = [Char]8730
        ForegroundColor = 'Green'
        NoNewLine       = $true
    }
 
    # 定义应用计数
    [int]$AppCount = 0

}

Process {

    If ($($BlackListedApps.Count) -ne 0) {

        Write-Output `n"The following $($BlackListedApps.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "The following $($BlackListedApps.Count) apps were targeted for removal from the device:-"
        Write-LogEntry -Value "Apps marked for removal:$($BlackListedApps)"
        Write-Output ""
        $BlackListedApps

        # 初始化未命中目标的应用列表
        $AppNotTargetedList = New-Object -TypeName System.Collections.ArrayList

        # 获取 Appx 预配包
        Write-Output `n"Gathering installed Appx Provisioned Packages..."
        Write-LogEntry -Value "Gathering installed Appx Provisioned Packages..."
        Write-Output ""
        $AppArray = Get-AppxProvisionedPackage -Online | Select-Object -ExpandProperty DisplayName

        # 遍历每个预配包
        foreach ($BlackListedApp in $BlackListedApps) {

            # 调用函数，移除黑名单中定义的 Appx 预配包
            if (($BlackListedApp -in $AppArray)) {
                $AppCount ++
                Try {
                    Remove-AppxProvisionedPackageCustom -BlackListedApp $BlackListedApp
                }
                Catch {
                    Write-Warning `n"There was an error while attempting to remove $($BlakListedApp)"
                    Write-LogEntry -Value "There was an error when attempting to remove $($BlakListedApp)"
                }
            }
            else {
                $AppNotTargetedList.AddRange(@($BlackListedApp))
            }
        }

        # 更新输出信息
        If (!([string]::IsNullOrEmpty($AppNotTargetedList))) { 
            Write-Output `n"The following apps were not removed. Either they were already removed or the Package Name is invalid:-"
            Write-LogEntry -Value "The following apps were not removed. Either they were already removed or the Package Name is invalid:-"
            Write-LogEntry -Value "$($AppNotTargetedList)"
            Write-Output ""
            $AppNotTargetedList
        }
        If ($AppCount -eq 0) {
            Write-Output `n"No apps were removed. Most likely reason is they had been removed previously."
            Write-LogEntry -Value "No apps were removed. Most likely reason is they had been removed previously."
        }
    }
    else {
        Write-Output "No Black List Apps defined in array"
        Write-LogEntry -Value "No Black List Apps defined in array"
    }
}
