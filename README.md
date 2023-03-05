# Microsoft AppCenter Publishing BashScript

[Visual Studio AppCenter](https://learn.microsoft.com/en-us/appcenter/) – is Microsoft Services for Building, Testing, Distribution, Publication, Analytic and Diagnostic of your apps. 

This repository contains small bashscript for uploading Android apps to AppCenter services by [AppCenter Rest API](https://learn.microsoft.com/en-us/appcenter/distribution/uploading)

### How to use

Copy somewhere `credentials.sh` file and change AppCenter credencial data according of your account.

```bash
Usage, run:
  ./app-center-uploader.sh [options]
  ./app-center-uploader.sh --help

Supported options:
  '-f, --file (required)' - path to apk build file.
  '-c, --credentials (required)' - path to credentials file with AppCenter token and other private data.

For example:
  ./app-center-uploader.sh -f ./app/build/outputs/apk/release/app-release.apk -c ./credentials.sh
  ./app-center-uploader.sh --file ./app/build/outputs/apk/release/app-v.apk --credentials ./credentials.sh
```

The script divide the build file on chunks and upload one after another to service. Build your Android App and run general script to upload it into AppCenter:
```bash
./app-center-uploader.sh --file ./app/build/outputs/apk/release/app-release.apk --credentials ./credentials.sh
```

Sample output:
```bash
Creating release (1/8)
API Response: {...}

Creating metadata (2/8)
{..., "status_code":"Success"}

Uploading chunked binary (3/8)
start uploading chunk 1: ./build/app-center-split/splitaa
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
 12 4096k    0     0   12  512k      0   444k  0:00:09  0:00:01  0:00:08  443k
100 4096k  100    49  100 4096k     19  1668k  0:00:02  0:00:02 --:--:-- 1667k
100 4096k  100    49  100 4096k     19  1668k  0:00:02  0:00:02 --:--:-- 1667k
{"error":false,"chunk_num":1,"error_code":"None"}
start uploading chunk 2: ./build/app-center-split/splitab
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
...

Finalising upload (4/8)
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100   447  100   443  100     4    805      7 --:--:-- --:--:-- --:--:--   811
{... ,"state":"Done"}

Commit release (5/8)
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100   134  100    78  100    56    135     97 --:--:-- --:--:-- --:--:--   233
100   134  100    78  100    56    135     97 --:--:-- --:--:-- --:--:--   233
{..., "upload_status":"uploadFinished"}

Polling for release id (6/8)
max_poll_attempts=300
0 null
1 null
2 null
3 57

Applying destination to release (7/8)
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100   121  100    74  100    47    111     70 --:--:-- --:--:-- --:--:--   182
{"provisioning_status_url":null,"destinations":[{"name":"Collaborators"}]}

Clean cache (8/8)
removed './build/app-center-split/splitax'
removed './build/app-center-split/splitbf'
removed './build/app-center-split/splitai'
...
removed './build/app-center-split/splitad'
removed directory './build/app-center-split'

Downloading file link: https://appcenter.ms/orgs/<my_account>/apps/<my_app>/distribute/releases/57
```


