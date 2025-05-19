Get-ADUser -Identity "Maxie" | Set-ADAccountControl -DoesNotRequirePreAuth:$true
Get-ADUser -Identity "Archie" | Set-ADAccountControl -DoesNotRequirePreAuth:$true