# escape=`
# copied from source to microsoft/dotnet:2.0-sdk as couldn't get this working on server insiders 13338

FROM microsoft/nanoserver as dotnet2.0_sdk

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install .NET Core SDK
ENV DOTNET_SDK_VERSION 2.1.202
ENV DOTNET_SDK_DOWNLOAD_URL https://dotnetcli.blob.core.windows.net/dotnet/Sdk/$DOTNET_SDK_VERSION/dotnet-sdk-$DOTNET_SDK_VERSION-win-x64.zip
ENV DOTNET_SDK_DOWNLOAD_SHA ae0c8044a021498089cfd5dbe8888acca8cdd3295b42ff7f447ac3b11f6e43dac3b6394c4055ae17dcf7c6800aa2d59b9c62859ff1dde4496dfbb59047597bf6

RUN Invoke-WebRequest $Env:DOTNET_SDK_DOWNLOAD_URL -OutFile dotnet.zip; `
    if ((Get-FileHash dotnet.zip -Algorithm sha512).Hash -ne $Env:DOTNET_SDK_DOWNLOAD_SHA) { `
        Write-Host 'CHECKSUM VERIFICATION FAILED!'; `
        exit 1; `
    }; `
    `
    Expand-Archive dotnet.zip -DestinationPath $Env:ProgramFiles\dotnet; `
    Remove-Item -Force dotnet.zip

RUN setx /M PATH $($Env:PATH + ';' + $Env:ProgramFiles + '\dotnet')

# Enable detection of running in a container
ENV DOTNET_RUNNING_IN_CONTAINER=true `
    # Enable correct mode for dotnet watch (only mode supported in a container)
    DOTNET_USE_POLLING_FILE_WATCHER=true `
    # Skip extraction of XML docs - generally not useful within an image/container - helps perfomance
    NUGET_XMLDOC_MODE=skip

# Trigger the population of the local package cache
RUN New-Item -Type Directory warmup; `
    cd warmup; `
    dotnet new; `
    cd ..; `
    Remove-Item -Force -Recurse warmup

# Workaround for https://github.com/Microsoft/DockerTools/issues/87. This instructs NuGet to use 4.5 behavior in which
# all errors when attempting to restore a project are ignored and treated as warnings instead. This allows the VS
# tooling to use -nowarn:MSB3202 to ignore issues with the .dcproj project
ENV RestoreUseSkipNonexistentTargets false

ENV DOTNET_CLI_TELEMETRY_OPTOUT 1

# -=-=-

FROM dotnet2.0_sdk as build

WORKDIR /root/
WORKDIR /root/src
COPY .  .
RUN dotnet restore ./root.csproj
RUN dotnet build -r win-x64
RUN dotnet publish -c release -r win-x64

# -=-=-

FROM microsoft/nanoserver as run

COPY --from=build /root/src/bin/release/netcoreapp2.0/win-x64/publish /root/bin

WORKDIR /root/bin
ENV fprocess="root.exe"
EXPOSE 8080

ADD https://github.com/openfaas/faas/releases/download/0.8.11/fwatchdog.exe /usr/bin/
CMD ["/usr/bin/fwatchdog.exe"]
