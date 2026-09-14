# workspace/

This folder is mounted into the container at `/workspace`. Anything you put
here shows up inside the container immediately, and anything the container
writes shows up here - it is the same folder, not a copy.

Put your assignments here, one folder each:

```
workspace/
├── examples/
│   └── calc/      a working flexc++ + bisonc++ calculator, read this first
├── hazi1/         ← your work
└── hazi2/
```

`./dev.sh new hazi1` creates a folder here pre-filled with the example's
skeleton, which is usually the fastest way to start.

Everything outside this folder belongs to the environment itself (the
Dockerfiles, the scripts, the READMEs) and you should not need to touch it.
