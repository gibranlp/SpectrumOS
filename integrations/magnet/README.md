# Magnet

Finding a torrent these days sucks: fake download buttons, popups that spawn more tabs, and dead results with zero seeders.

Magnet is a torrent finder that lives in your terminal, written in Rust. It's a single binary with zero setup and nothing to configure. One search checks a short, curated list of reputable sources at once, and whatever you pick downloads straight into your downloads folder (`~/Downloads`).

It's a Rust take on [torlink](https://github.com/baairon/torlink).

## Get started

Download the latest Linux binary from [Releases](https://github.com/gibranlp/Magnet/releases). It's a single static file that runs on any Linux, x86_64 or arm64:

```sh
tar xzf magnet-*-linux-musl.tar.gz
install magnet-*/magnet ~/.local/bin/
magnet
```

Or build it yourself with Rust:

```sh
cargo install --git https://github.com/gibranlp/Magnet
magnet
```

Magnet opens straight to a search bar. You can:

- type what you want and press Enter
- paste a magnet link or a bare info hash
- drag a `.torrent` file onto the window
- press Enter on an empty box to browse what's new
- type `top100` and press Enter for the most popular torrents

After that it's all single keypresses, and `?` shows the full list at any time.

## Finding something

Results stream in from every source as each one answers. Every row shows its size and how many people are sharing it. Use `←`/`→` (or `1`–`7`) to switch between **All, Games, Movies, TV, Anime, Music, Other**. Music and Other rows say what each item is: FLAC, E-book, Comic, Picture, Cover, or Other.

- `d` downloads the highlighted result
- `space` marks several results, then `d` downloads them all together
- `Enter` opens details, `y` copies the magnet link
- `s` cycles the sort order, `z` hides dead torrents
- type `top100` and press Enter (or press `ctrl+t` in the search box, `t` in the results) for the Top 100: the most-seeded torrents in each tab, with adult content left out. Switch tabs to see each category's Top 100, and press `t` to go back to your search.

The Top 100 draws on the sources that report seeders: The Pirate Bay's top lists, YTS and Nyaa. FitGirl doesn't report seeders, so the Games tab has no Top 100.

## Your downloads

Press `tab` to switch to the Downloads pane, which shows progress, speed, peers and time left for each torrent.

- `p` pauses or resumes
- `e` opens the folder
- `c` removes a torrent from the list and keeps its files
- `X` removes it and deletes its files

You don't need to keep Magnet open. When you quit with `Q`, downloads keep going in a small background service. The service starts on its own when you open Magnet, and stops itself once everything has finished downloading. Paused and failed torrents don't keep it running. Anything left unfinished picks up where it left off the next time you open Magnet.

Finished downloads keep seeding while Magnet is open, so the next person can find them too.

## What it searches

| Category | Sources |
| --- | --- |
| Games | FitGirl |
| Movies | YTS, The Pirate Bay |
| TV | EZTV, The Pirate Bay |
| Anime | Nyaa, SubsPlease |
| Music | The Pirate Bay (music, FLAC) |
| Other | The Pirate Bay (e-books, comics, pictures, covers, other) |

Games are the only category that can run code, so they come from FitGirl alone. If a source is down, the search carries on without it, and its dot next to the tabs turns red.

## Headless

```
magnet search "<query>" [--category games|movies|tv|anime|music|other]   # merged results as JSON
magnet search --top [--category movies|tv|anime|music|other]          # the Top 100 as JSON
magnet get <magnet|infohash|file.torrent>...                 # download, then exit
magnet daemon                                                # the background service (started for you)
```

`get` hands its downloads to the same background service, so pressing Ctrl+C only stops watching them. The downloads themselves keep going.

## Where things live

- Downloads: your XDG download dir, falling back to `~/Downloads`
- Resume state: `~/.local/share/magnet/session`
- Background service log: `~/.local/share/magnet/daemon.log`

There's nothing to configure, so you shouldn't need to touch either.

## Privacy

Your files stay on your disk, and nothing routes through a central server: Magnet talks to the torrent network directly.

## License

MIT. Magnet is a Rust port of [torlink](https://github.com/baairon/torlink) by bairon.dev, also MIT; see [LICENSE](LICENSE).
