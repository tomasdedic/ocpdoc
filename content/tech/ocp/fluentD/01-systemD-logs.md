# SYSTEMD Journal logs transport
## LOGS location

journalctl may be used to query the contents of the systemd(1) journal
as written by systemd-journald.service(8)

Configuration files are: **/etc/systemd/journald.conf**  
There the "Storage=" option controls whether to store journal data 
- *volatile*, journal log data will be stored only in memory, i.e. below the /run/log/journal hierarchy (which is created if needed).
- *persistent*, data will be stored preferably on disk, i.e. below the /var/log/journal hierarchy (which is created if needed), with a fallback to /run/log/journal (which is created if needed), during early boot and if the disk is not writable.
- *auto* is similar to "persistent" but the directory /var/log/journal is not created if needed, so that its existence controls where log data goes.
- *none* turns off all storage, all log data received will be dropped.

In case of Openshift node configuration is set to **persistent**
```sh
 # all units in journal
journalctl --field _SYSTEMD_UNIT
 # journals path
journalctl --field JOURNAL_PATH
 # journal disk-usage 
journalctl --disk-usage
 # current journals
journalctl --field JOURNAL_NAME
```
## Event structure
Fluentd event consists of tag, time and record.
+ tag: Where an event comes from. For message routing
+ time: When an event happens. Nanosecond resolution
+ record: Actual log content. JSON object

```sh
The input plugin has responsibility for generating Fluentd event from data sources. For example, in_tail generates events from text lines. If you have following line in apache logs:
192.168.0.1 - - [28/Feb/2013:12:00:00 +0900] "GET / HTTP/1.1" 200 777
you got following event:
tag: apache.access         # set by configuration
time: 1362020400.000000000 # 28/Feb/2013:12:00:00 +0900
record: {"user":"-","method":"GET","code":200,"size":777,"host":"192.168.0.1","path":"/"}
```
