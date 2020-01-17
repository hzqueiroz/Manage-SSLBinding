# Manage-SSLBinding
Gerenciar certificados em ambientes Windows utilizando powershell

Esse PS1 foi desenvoldido para ajudar as pessoas a gerenciar certificados.

O Get-SSLBinding

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


Manage-SSLBinding
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
