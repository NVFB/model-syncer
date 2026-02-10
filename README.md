# ModelSyncer

Periodically syncs a directory of models from a **source** (`SRC`) to a **destination** (`DST`) using `rsync`, driven by a configurable crontab. Designed to run as a **sidecar** next to an app that consumes the synced models (e.g. inference server), with both containers sharing the same volumes.

## How it works

- A single sync command: `rsync -avH "$SRC" "$DST"` with locking so only one run is active at a time.
- Schedule is defined at container start via **crontab** (env or file). Default: every hour (`0 * * * *`).
- Optional: run one sync immediately on start with `RUN_ON_START=1`.

## Using ModelSyncer as a sidecar

Run the syncer **next to** your main app in the same pod/compose stack. Mount the same **SRC** and **DST** volumes into both containers so the app reads from the destination that the sidecar keeps updated.

- **SRC**: read-only source of truth (e.g. NFS, object-store mount, or another container’s output).
- **DST**: writable destination; the sidecar writes here and your app reads from here.

### Environment variables

| Variable        | Default            | Description                                                          |
| --------------- | ------------------ | -------------------------------------------------------------------- |
| `SRC`           | `/scratch/models/` | Source directory (mount your source here).                           |
| `DST`           | `/raid/models/`    | Destination directory (mount a volume here; shared with your app).   |
| `CRON_SCHEDULE` | `0 * * * *`        | Cron schedule (e.g. `*/5 * * * *` for every 5 minutes).              |
| `RUN_ON_START`  | `0`                | Set to `1` or `true` to run one sync immediately at startup.         |
| `CRONTAB_FILE`  | —                  | Path inside container to a crontab file (overrides `CRON_SCHEDULE`). |
| `CRONTAB`       | —                  | Full crontab contents (overrides `CRON_SCHEDULE`).                   |

### Kubernetes: sidecar in the same pod

Share a volume between the main container and the ModelSyncer sidecar. The app uses the same `DST` path read-only; the sidecar writes to it.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mistral-7b
  namespace: default
  labels:
    app: mistral-7b
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mistral-7b
  template:
    metadata:
      labels:
        app: mistral-7b
    spec:
      containers:
        - name: app
          image: vllm/vllm-openai:latest
          command: ["/bin/sh", "-c"]
          args: [
              # Point vLLM at the local model directory inside the container
              "vllm serve /raid/models/Mistral-7B-Instruct-v0.3 --trust-remote-code --enable-chunked-prefill --max_num_batched_tokens 1024",
            ]
          ports:
            - containerPort: 8000
          resources:
            limits:
              cpu: "10"
              memory: 20G
              nvidia.com/gpu: "1"
            requests:
              cpu: "2"
              memory: 6G
              nvidia.com/gpu: "1"
          volumeMounts:
            - name: models
              mountPath: /raid/models
              readOnly: true
            - name: shm
              mountPath: /dev/shm
        - name: model-syncer
          image: ghcr.io/NVFB/model-syncer:latest
          env:
            - name: SRC
              value: /scratch/models/
            - name: DST
              value: /raid/models/
            - name: CRON_SCHEDULE
              value: "*/10 * * * *"
            - name: RUN_ON_START
              value: "1"
          volumeMounts:
            - name: nfs-models
              mountPath: /scratch/models
              readOnly: true
            - name: local-models
              mountPath: /raid/models
      volumes:
        - name: nfs-models
          persistentVolumeClaim:
            claimName: nfs-models-pvc
        - name: local-models
          emptyDir: {}
        - name: shm
          emptyDir:
            medium: Memory
            sizeLimit: "2Gi"
```

## Image and build

- **GHCR:** `ghcr.io/YOUR_ORG/ModelSyncer:latest` (and `:sha-<commit>` from CI).
- Built on push to `main` via GitHub Actions; image is pushed to GitHub Container Registry.

Replace `YOUR_ORG` with your GitHub org or username.

## Custom crontab

- **Simple schedule:** set `CRON_SCHEDULE` (and optionally `SRC`/`DST`).
- **Full control:** set `CRONTAB` (full crontab text) or mount a file and set `CRONTAB_FILE` to its path in the container. The image uses Alpine’s crontab format (no user field); cron runs as root and uses `SHELL=/bin/bash`. Ensure your job line passes `SRC` and `DST` if you override the command.

## License

See repository license file.
