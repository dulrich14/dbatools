﻿function Test-DbaDeprecatedFeature {
    <#
        .SYNOPSIS
            Displays information relating to deprecated features for SQL Server 2005 and above.

        .DESCRIPTION
            Displays information relating to deprecated features for SQL Server 2005 and above.

        .PARAMETER SqlInstance
            The target SQL Server instance

        .PARAMETER SqlCredential
            Login to the target instance using alternate Windows or SQL Login Authentication. Accepts credential objects (Get-Credential).

        .PARAMETER Database
            The database(s) to process - this list is auto-populated from the server. If unspecified, all databases will be processed.

        .PARAMETER ExcludeDatabase
            The database(s) to exclude - this list is auto-populated from the server

        .PARAMETER InputObject
            A collection of databases (such as returned by Get-DbaDatabase), to be tested.

        .PARAMETER EnableException
            By default, when something goes wrong we try to catch it, interpret it and give you a friendly warning message.
            This avoids overwhelming you with "sea of red" exceptions, but is inconvenient because it basically disables advanced scripting.
            Using this switch turns this "nice by default" feature off and enables you to catch exceptions with your own try/catch.

        .NOTES
            Author: Chrissy LeMaire (@cl), netnerds.net
            Tags: Deprecated
            Website: https://dbatools.io
            Copyright (c) 2018 by dbatools, licensed under MIT
-           License: MIT https://opensource.org/licenses/MIT

        .LINK
            https://dbatools.io/Test-DbaDeprecatedFeature

        .EXAMPLE
            Get-DbaDatabase -SqlInstance sql2008 -Database testdb, db2 | Test-DbaDeprecatedFeature
            Check deprecated features on server sql2008 for only the testdb and db2 databases


        .EXAMPLE
            Get-DbaDatabase -SqlInstance sql2008 -Database testdb, db2 | Test-DbaDeprecatedFeature | Select *
            See the object definition in the output as well

        .EXAMPLE
            Test-DbaDeprecatedFeature -SqlInstance sql2008, sqlserver2012
            Check deprecated features for all databases on the servers sql2008 and sqlserver2012.

        .EXAMPLE
            Test-DbaDeprecatedFeature -SqlInstance sql2008 -Database TestDB
            Check deprecated features on server sql2008 for only the TestDB database

        #>
    [CmdletBinding()]
    param (
        [Alias("ServerInstance", "SqlServer", "SqlServers")]
        [DbaInstanceParameter[]]$SqlInstance,
        [PSCredential]$SqlCredential,
        [string[]]$Database,
        [string[]]$ExcludeDatabase,
        [parameter(ValueFromPipeline)]
        [Microsoft.SqlServer.Management.Smo.Database[]]$InputObject,
        [switch]$EnableException
    )

    begin {
        $sql = "SELECT  SERVERPROPERTY('MachineName') AS ComputerName,
            ISNULL(SERVERPROPERTY('InstanceName'), 'MSSQLSERVER') AS InstanceName,
            SERVERPROPERTY('ServerName') AS SqlInstance, object_id as ID, Name, type_desc as Type, Object_Definition (object_id) as Definition FROM sys.all_objects
            Where Type = 'P' AND is_ms_shipped = 0"
    }

    process {
        foreach ($instance in $SqlInstance) {
            $InputObject += Get-DbaDatabase -SqlInstance $SqlInstance -SqlCredential $SqlCredential -Database $Database -ExcludeDatabase $ExcludeDatabase
        }
        foreach ($db in $InputObject) {
            Write-Message -Level Verbose -Message "Processing $db on $($db.Parent.Name)"

            if ($db.IsAccessible -eq $false) {
                Stop-Function -Message "The database $db is not accessible. Skipping database." -Continue
            }

            $deps = $db.Query("select instance_name as dep from sys.dm_os_performance_counters where object_name like '%Deprecated%'")
            try {
                $results = $db.Query($sql)
                foreach ($dep in $deps) {
                    $escaped = [Regex]::Escape("$($dep.dep)".Trim())
                    $matchedep = $results | Where-Object Definition -match $escaped
                    if ($matchedep) {
                        $matchedep | Add-Member -NotePropertyName DeprecatedFeature -NotePropertyValue $dep.dep.ToString().Trim() -PassThru -Force |
                        Select-DefaultView -Property ComputerName, InstanceName, SqlInstance, DeprecatedFeature, ID, Name, Type
                    }
                }
            }
            catch {
                Stop-Function -Message "Failure" -ErrorRecord $_ -Continue
            }
        }
    }
}