# zig-yes

yes command written in Zig

## Installation

```
$ zig build -Doptimize=ReleaseFast
```

## Benchmark

Output goes through `vmsplice(2)` (zero-copy) when stdout is a pipe, which
makes it roughly 1.9x faster than GNU yes:

```
$ hyperfine --warmup 2 'yes | head -c 1G > /dev/null' './zig-out/bin/yes | head -c 1G > /dev/null'
Benchmark 1: yes | head -c 1G > /dev/null
  Time (mean ± σ):     331.7 ms ±  27.6 ms    [User: 37.3 ms, System: 531.9 ms]

Benchmark 2: ./zig-out/bin/yes | head -c 1G > /dev/null
  Time (mean ± σ):     178.1 ms ±   6.6 ms    [User: 26.7 ms, System: 335.7 ms]
```

|                  | GNU yes 9.4    | zig-yes                    |
|------------------|----------------|----------------------------|
| `yes`            | 331.7 ms / GiB | 178.1 ms / GiB (~5.6 GiB/s) |
| `yes hello world`| 375.1 ms / GiB | 233.3 ms / GiB             |

Measured on Linux (WSL2). Numbers vary by kernel and machine.

## License

MIT

## Author

Yasuhiro Matsumoto (a.k.a. mattn)
