Prune images that are no longer required by the system due to age, status, or exceed limits as a **cronjob**.
### Enable ImagePruner controller 
Cron job to delete unused images
```sh
apiVersion: imageregistry.operator.openshift.io/v1
kind: ImagePruner
metadata:
  name: cluster
spec:
  failedJobsHistoryLimit: 3
  keepTagRevisions: 3
  schedule: ""
  successfulJobsHistoryLimit: 3
  suspend: false
```
