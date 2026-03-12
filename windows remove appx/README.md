[https://github.com/MSEndpointMgr/Windows/tree/master/BuiltInApps](https://github.com/MSEndpointMgr/Windows/tree/master/BuiltInApps)

#### list packages

    Get-AppxPackage -AllUsers | Where-Object NonRemovable -eq $False | Select Name, PackageFullName

#### remove packages

    Remove-AppxPackage -AllUsers -Package "**PackageFullName**"