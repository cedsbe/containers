# containers

Containers for Kubernetes personal infrastructure

## Wallos container: readonly-rootfs and strict securityContext support

This image is prepared to run with a **readOnlyRootFilesystem** and minimal Linux capabilities in Kubernetes. Runtime writable files (nginx/pid files, tmp dirs, and logs) are placed under `/var/ephemeral` and `/var/log` so you can mount writable volumes there (PVC or emptyDir).

Recommended podSecurity & volumes (example):

```yaml
securityContext:
  allowPrivilegeEscalation: false
  readOnlyRootFilesystem: true
  capabilities:
    drop: ["ALL"]
volumeMounts:
  - name: wallos-data
    mountPath: /var/www/html/db
    subPath: db
  - name: wallos-data
    mountPath: /var/www/html/images/uploads/logos
    subPath: logos
  - name: wallos-ephemeral
    mountPath: /var/ephemeral
    subPath: ephemeral
  - name: wallos-ephemeral
    mountPath: /var/log
    subPath: log
  - name: tmp
    mountPath: /tmp
volumes:
  - name: wallos-data
    persistentVolumeClaim:
      claimName: wallos-data
  - name: wallos-ephemeral
    persistentVolumeClaim:
      claimName: wallos-ephemeral
  - name: tmp
    emptyDir: {}
```

Notes:

- Ensure Kubernetes `fsGroup` or proper volume permissions allow the container process to write to these mount points.
- The image configures nginx to use `/var/ephemeral` for temporary files and PID, and `/var/log` for logs, and prepares these directories at container startup.
