function Get-SSLBinding {
    <#
        .SYNOPSIS
           Obtem os SSL Binding.

            Hostname        : NOME DO SERVIDOR
            Domain          : DOMINIO
            Binding         : 0.0.0.0:443
            Port            : 443
            AppId           : 7b2468fc-8b3e-4e67-b7b8-9364bc719342
            SslCertHash     : <Thumbprint>
            FriendlyName    : *.exemplo.com.br
            NotAfter        : 03/01/2022 18:15:03
            Issuer          : CN=Go Daddy Secure Certificate Authority - G4, OU=http://certs.godaddy.com/repository/, O="GoDaddy.com, Inc.", L=Scottsdale, S=Arizona, C=US
            Expiration_Date : 717
            status          : Valido
            Guid            : 4dc3e181-e14b-4a21-b022-59fc669b0914

        .EXAMPLE

        Get-SSLBinding

    #>

    function Get-IniContent ($filePath) {
        $ini = @{ }
        switch -regex -file $FilePath {
            “^\[(.+)\]” {
                # Section
                $section = $matches[1]
                $ini[$section] = @{ }
                $CommentCount = 0
            }
            “^(;.*)$” {
                # Comment
                $value = $matches[1]
                $CommentCount = $CommentCount + 1
                $name = “Comment” + $CommentCount
                $ini[$section][$name] = $value
            }
            “(.+?)\s*=(.*)” {
                # Key
                $name, $value = $matches[1..2]
                $ini[$section][$name] = $value
            }
        }
        return $ini
    }
    $binding_ssl_props = @()
    $reg_file = [System.IO.Path]::GetTempFileName()
    $tmp_file = [System.IO.Path]::GetTempFileName()
    reg export HKLM\SYSTEM\CurrentControlSet\Services\HTTP\Parameters\SslBindingInfo "$($reg_file)" /y | Out-Null
    $file = Get-Content $reg_file
    $file = $file -replace ('HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\HTTP\\Parameters\\SslBindingInfo\\', '') -replace ('hex:', '') -replace (",", "")
    $file = $file -replace ('\[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\HTTP\\Parameters\\SslBindingInfo]', '') -replace ('"', '')
    $file | Out-File $tmp_file -Force
    $binding_ssl = Get-IniContent -filePath $tmp_file
    Remove-Item $tmp_file -Force
    Remove-Item $reg_file -Force
    foreach ($current_binding in $binding_ssl.Keys) {
        $certificate = Get-ChildItem Cert:\ -Recurse | Where-Object { ($_.Thumbprint -match "$($binding_ssl.$current_binding.SslCertHash)") } | Select-Object FriendlyName, NotAfter, Issuer
        $certificate = $certificate[-1]
        $status = "Valido"
        if ($(($certificate.NotAfter - $(get-date)).Days) -le 7) { $status = "Alterar nos proximos dias" }
        if ($(($certificate.NotAfter - $(get-date)).Days) -le 0) { $status = "Expirado" }
        $info = [pscustomobject]@{
            "Hostname"        = hostname
            "Domain"          = $(Get-ItemProperty -Path HKLM:\SYSTEM\ControlSet001\Services\Tcpip\Parameters).domain
            "Binding"         = $current_binding
            "Port"            = $current_binding.split(':')[1]
            "AppId"           = $binding_ssl.$current_binding.AppId
            "SslCertHash"     = $binding_ssl.$current_binding.SslCertHash
            "FriendlyName"    = $certificate.FriendlyName
            "NotAfter"        = $certificate.NotAfter
            "Issuer"          = $certificate.Issuer
            "Expiration_Date" = $($certificate.NotAfter - $(get-date)).Days
            "status"          = $status
        }
        $guid = $info.AppId = "$(($info.AppId)[0..7] -join '')-$(($info.AppId)[8..11] -join '')-$(($info.AppId)[12..15] -join '')-$(($info.AppId)[16..19] -join '')-$(($info.AppId)[20..38] -join '')"
        $info | Add-Member -NotePropertyName "Guid" -NotePropertyValue $guid -Force
        $binding_ssl_props += $info

    }
    return $binding_ssl_props
}

function Manage-SSLBinding {
    <#
    .SYNOPSIS
        Objetivo é gerenciar Build SSL nas portas.
        
    .EXAMPLE
        -certificate <Thumbprint>
        -appid       <Guid>
        -port        <Port>
        -action      create,change,remove
    .EXAMPLE
        Create

        Manage-SSLBinding -port 443 -certificate <Thumbprint> -guid $(New-Guid) -action create
        Manage-SSLBinding -port 443 -certificate <Thumbprint> -action create

        Caso não seja informado um appid será definido o 7b2468fc-8b3e-4e67-b7b8-9364bc719342 no Buiding.
    .EXAMPLE
       Change

       Manage-SSLBinding -port 443 -certificate <Thumbprint> -guid $(New-Guid) -action change
    .EXAMPLE
        Remove

        Manage-SSLBinding -port 443 -action remove
    #>
    [cmdletbinding()]
    param(
        $certificate,
        $appid,
        [parameter(Mandatory)]
        $port,
        [ValidateSet("create", "change", "remove")]
        $action
    )
    if ($appid -eq $null) { $appid = '7b2468fc-8b3e-4e67-b7b8-9364bc719342' }
    $netsh_command = [pscustomobject]@{
        "delete_acl" = "netsh http delete urlacl url=https://+:$port/"
        "delete_ssl" = "netsh http delete sslcert ipport=0.0.0.0:$port"
        "create_ssl" = "netsh http add sslcert ipport=0.0.0.0:$port certhash=$certificate appid={$appid}"
    }
    switch ($action) {
        "create" {
            $bind_ops = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
            if ($bind_ops -eq $null) {
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_acl)" -Verb RunAs -Wait -WindowStyle Hidden
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_ssl)" -Verb RunAs -Wait -WindowStyle Hidden
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.create_ssl)" -Verb RunAs -Wait -WindowStyle Hidden
                $bind_ops = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
                return $bind_ops
            }
            else {
                Write-Warning "Binding já existe, para alterar considere utilizar a opção change."
                return $bind_ops
            }
        }
        "change" {
            $bind_ops = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
            if ($bind_ops -ne $null) {
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_acl)" -Verb RunAs -Wait -WindowStyle Hidden
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_ssl)" -Verb RunAs -Wait -WindowStyle Hidden
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.create_ssl)" -Verb RunAs -Wait -WindowStyle Hidden
                $bind_ops_ = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
                if (($bind_ops -ne $bind_ops_) -and ($bind_ops_ -ne $null)) {
                    Write-Host "Binding alterado com sucesso" -ForegroundColor Green
                }
                else {
                    Write-Warning "Ops - Binding não foi alterado com sucesso"
                }
                $out_info = [pscustomobject]@{
                    anterior = $bind_ops
                    atual    = $bind_ops_
                }
                return $out_info
            }
            else {
                Write-Warning "Binding não encontrado. Utilize a action create para realizar a criação"
                return $false    
            }
        }
        "remove" {
            $bind_ops = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
            if ($bind_ops -ne $null) {
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_acl)" -Verb RunAs -Wait -WindowStyle Hidden
                Start-Process cmd.exe -ArgumentList "/c $($netsh_command.delete_ssl)" -Verb RunAs -Wait -WindowStyle Hidden
                $bind_ops_ = Get-SSLBinding | Where-Object { ($($_.Binding).split(':')[1] -eq "$port") }
                if ($bind_ops_ -eq $null) {
                    Write-Warning "Removido com sucesso."
                    return $bind_ops
                }
            }
            else {
                Write-Warning "Binding não encontrado."
                return $false

            }
        }

    }
}

