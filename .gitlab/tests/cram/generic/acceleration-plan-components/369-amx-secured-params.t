Create R alias:

  $ alias R="${CRAM_REMOTE_COMMAND:-}"

Prepare ACLs

  $ acl_file="/cfg/etc/acl/admin/tr181-bulkdata.json"

  $ R tee "$acl_file" > /dev/null <<'EOF'
  > {
  >     "Device.BulkData.": {
  >         "Order": 2,
  >         "Param": "rwxn",
  >         "Obj": "rwxn",
  >         "InstantiatedObj": "rwxn",
  >         "CommandEvent": "rwxn"
  >     }
  > }
  > EOF

Get secured parameter attributes with gsdm

  $ R "ba-cli 'gsdm -p Device.BulkData.Profile.' | grep 'Password'"
  RWH (cstring_t   ) Device.BulkData.Profile.{i}.HTTP.Password

Add instance with secured parameter and set the value

  $ profile=$(R ba-cli 'Device.BulkData.Profile.+{Alias=testing}' | grep '^Device\.BulkData\.Profile\.[0-9]\+\.$')

  $ R "ba-cli '"$profile"HTTP.Password=secret'" > /dev/null

Get empty strings for secured parameters with public access via the cli

  $ R "ba-cli '"$profile"HTTP.Password?' | grep -v '>'"
  Device.BulkData.Profile.[0-9]+.HTTP.Password="" (re)
  

Get parameter values for secured parameters with secured access via the cli

  $ R "ba-cli 'secured; "$profile"HTTP.Password?' | grep -v '>'"
  Device.BulkData.Profile.[0-9]+.HTTP.Password="secret" (re)
  
Get empty parameter value with usp-cli connected to obuspa

  $ R "usp-cli '"$profile"HTTP.Password?' | grep -v '>'"
  Device.BulkData.Profile.[0-9]+.HTTP.Password="" (re)
  
Get non-secured parameter value with usp-cli connected to obuspa

  $ R "usp-cli '"$profile"HTTP.Method?' | grep -v '>'"
  Device.BulkData.Profile.[0-9]+.HTTP.Method="POST" (re)
  
Get empty string for secured parameter via amx-fcgi

  $ session_id=$(curl --silent -X POST "http://192.168.1.1/session" --data '{"username":"admin","password":"admin"}' --max-time 3 | jq -r .sessionID)
  $ curl -X GET "http://192.168.1.1/serviceElements/"$profile"HTTP.Password" -H "Authorization: bearer $session_id" --silent --max-time 3 | jq '.[0].parameters'
  {
    "Password": ""
  }

Clean up previously added instance and remove ACL file

  $ R "ba-cli '"$profile"-'" > /dev/null
  $ R rm "$acl_file"
