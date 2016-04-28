#Requires -Modules Pester
<#
.SYNOPSIS
    Tests the AzureRateCard module
.EXAMPLE
    Invoke-Pester 
.NOTES
    This script originated from work found here:  https://github.com/kmarquette/PesterInAction
    scriptanalyzer section basics taken from DSCResource.Tests
#>

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'ModuleHelper.psm1') -Force

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..).Path
$module = Split-Path -Leaf $RepoRoot
$psVersion = $PSVersionTable.PSVersion

#region PSScriptanalyzer
if ($psVersion.Major -ge 5)
{
    Write-Verbose -Verbose "Installing PSScriptAnalyzer"
    $PSScriptAnalyzerModuleName = "PSScriptAnalyzer"
    Install-Module -Name $PSScriptAnalyzerModuleName -Scope CurrentUser -Force 
    $PSScriptAnalyzerModule = get-module -Name $PSScriptAnalyzerModuleName -ListAvailable
    if ($PSScriptAnalyzerModule) {
        # Import the module if it is available
        $PSScriptAnalyzerModule | Import-Module -Force
    }
    else
    {
        # Module could not/would not be installed - so warn user that tests will fail.
        Write-Warning -Message ( @(
            "The 'PSScriptAnalyzer' module is not installed. "
            "The 'PowerShell modules scriptanalyzer' Pester test will fail "
            ) -Join '' )
    }
}
else
{
    Write-Verbose -Verbose "Skipping installation of PSScriptAnalyzer since it requires PSVersion 5.0 or greater. Used PSVersion: $($PSVersion)"
}

#endregion

Describe 'Text files formatting' {

    $allTextFiles = Get-TextFilesList $RepoRoot

    Context 'Files encoding' {

        It "Doesn't use Unicode encoding" {
            $unicodeFilesCount = 0
            $allTextFiles | %{
                if (Test-FileUnicode $_) {
                    $unicodeFilesCount += 1
                    Write-Warning "File $($_.FullName) contains 0x00 bytes. It's probably uses Unicode and need to be converted to UTF-8. Use Fixer 'Get-UnicodeFilesList `$pwd | ConvertTo-UTF8'."
                }
            }
            $unicodeFilesCount | Should Be 0
        }
    }

    Context 'Indentations' {

        It 'Uses spaces for indentation, not tabs' {
            $totalTabsCount = 0
            $allTextFiles | %{
                $fileName = $_.FullName
                Get-Content $_.FullName -Raw | Select-String "`t" | % {
                    Write-Warning "There are tab in $fileName. Use Fixer 'Get-TextFilesList `$pwd | ConvertTo-SpaceIndentation'."
                    $totalTabsCount++
                }
            }
            $totalTabsCount | Should Be 0
        }
    }
}

Describe "Module: $module" -Tags Unit {
#region ScriptAnalyzer
    Context 'PSScriptAnalyzer' {
        It "passes Invoke-ScriptAnalyzer" {

            # Perform PSScriptAnalyzer scan.
            # Using ErrorAction SilentlyContinue not to cause it to fail due to parse errors caused by unresolved resources.
            # Many of our examples try to import different modules which may not be present on the machine and PSScriptAnalyzer throws parse exceptions even though examples are valid.
            # Errors will still be returned as expected.
            $PSScriptAnalyzerErrors = Invoke-ScriptAnalyzer -path $RepoRoot -Severity Error -Recurse -ErrorAction SilentlyContinue
            if ($PSScriptAnalyzerErrors -ne $null) {
                Write-Error "There are PSScriptAnalyzer errors that need to be fixed:`n $PSScriptAnalyzerErrors"
                Write-Error "For instructions on how to run PSScriptAnalyzer on your own machine, please go to https://github.com/powershell/psscriptAnalyzer/"
                $PSScriptAnalyzerErrors.Count | Should Be $null
            }
        }     
    }
#endregion
#region Generic PS module tests
    Context "Module Configuration" {
        
        It "Has a root module file ($module.psm1)" {        
            
            "$RepoRoot\$module.psm1" | Should Exist
        }

        It "Is valid Powershell (Has no script errors)" {

            $contents = Get-Content -Path "$RepoRoot\$module.psm1" -ErrorAction SilentlyContinue
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $errors.Count | Should Be 0
        }

        It "Has a manifest file ($module.psd1)" {
            
            "$RepoRoot\$module.psd1" | Should Exist
        }

        It "Contains a root module path in the manifest (RootModule = '.\$module.psm1')" {
            
            "$RepoRoot\$module.psd1" | Should Exist
            "$RepoRoot\$module.psd1" | Should Contain "\.\\$module.psm1"
        }
        
        It "Is valid Powershell (Has no script errors)" {
            $contents = Get-Content -Path "$RepoRoot\$module.psm1" -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($contents, [ref]$errors)
            $errors.Count | Should Be 0
        }
    }
#endregion 
#region module content
    Context 'Module loads and Functions exist' {
        
        $manifest = Test-ModuleManifest -Path "$RepoRoot\$module.psd1"
        $ExportedCommands = $manifest.ExportedCommands
        $ModuleName = $manifest.Name
        
        BeforeEach {
            if (get-module $Module) {remove-module $Module}
            import-Module "$RepoRoot\$module.psd1" -ErrorAction SilentlyContinue
            $loadedModule = Get-Module $module -ErrorAction SilentlyContinue    
            $loadedFunctions = $loadedModule.ExportedCommands.Keys
            
        }
        
        It 'Module should load without error' {
            $loadedModule.Name | Should Be $ModuleName
        }

        It 'Exported commands should include all functions' {
            $loadedFunctions | Should Be $ExportedCommands.Keys
        }
        
        AfterEach {
            
            remove-module $module
            $loadedModule = $null
            $loadedFunctions = $null
        }
    }
#endregion
#region functions
    Context 'Help provided for Functions' {
        
        BeforeAll {
            if (get-module $Module) {remove-module $Module}
            import-Module "$RepoRoot\$module.psd1" -ErrorAction SilentlyContinue
            $loadedModule = Get-Module $module -ErrorAction SilentlyContinue    
            $loadedFunctions = $loadedModule.ExportedCommands.keys
        }
        
        Foreach ($Function in $loadedFunctions) {

            $Help = Get-Help $Function

            It "$Function should have a non-default Synopsis section in help" {                
                $Help.Synopsis | Should Not Match "\r\n$Function*"
                }

            It "$Function should have help examples" {
                $Help.Examples.Example.Count | Should Not Be 0
                }
        }
        
        AfterAll {
            
            remove-module $module
            $loadedFunctions = $null
            $loadedModule = $null
        }
    }
}
#endregion
