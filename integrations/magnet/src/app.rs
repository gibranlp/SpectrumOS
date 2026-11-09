//! The terminal UI: one search bar, category tabs, results, and downloads.

use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::Result;
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyEventKind, KeyModifiers, MouseEventKind};
use ratatui::{
    DefaultTerminal, Frame,
    layout::{Constraint, Layout, Rect},
    style::{Color, Modifier, Style, Stylize},
    text::{Line, Span, Text},
    widgets::{Block, BorderType, Borders, Cell, Clear, Paragraph, Row, Table, TableState, Wrap},
};
use tokio::sync::mpsc::{UnboundedReceiver, UnboundedSender, unbounded_channel};

use crate::daemon::Client;
use crate::engine::{self, State};
use crate::format;
use crate::magnet;
use crate::sources::{self, Group, SourceId, TorrentResult};
use crate::theme::{self, Theme};

// --- theme -----------------------------------------------------------------
//
// Colors come from the active SpectrumOS palette (see theme.rs). Status colors
// (success/warning/error) are kept for real status; decoration uses accent,
// accent_alt and blends of the two.

fn th() -> Theme {
    theme::get()
}

fn source_color(s: SourceId) -> Color {
    let t = th();
    match s {
        SourceId::Fitgirl => t.accent,
        SourceId::Yts => t.accent_alt,
        SourceId::TpbMovies | SourceId::TpbTv | SourceId::TpbMusic | SourceId::TpbOther => t.blend(0.5),
        SourceId::Eztv => t.toward_fg(t.accent, 0.45),
        SourceId::Nyaa => t.toward_fg(t.accent_alt, 0.45),
        SourceId::Subsplease => t.blend(0.25),
    }
}

const LOGO: [&str; 2] = [
    "█▀▄▀█ ▄▀█ █▀▀ █▄ █ █▀▀ ▀█▀",
    "█ ▀ █ █▀█ █▄█ █ ▀█ ██▄  █ ",
];

// --- sorting -----------------------------------------------------------------

#[derive(Clone, Copy, PartialEq)]
enum SortField {
    None,
    Size,
    Seeders,
    Source,
    Added,
}

const SORTS: [(SortField, bool); 9] = [
    (SortField::None, false),
    (SortField::Size, true),
    (SortField::Size, false),
    (SortField::Seeders, true),
    (SortField::Seeders, false),
    (SortField::Source, true),
    (SortField::Source, false),
    (SortField::Added, true),
    (SortField::Added, false),
];

fn sort_label(i: usize) -> String {
    let (f, asc) = SORTS[i];
    let name = match f {
        SortField::None => return "default".into(),
        SortField::Size => "size",
        SortField::Seeders => "seeders",
        SortField::Source => "source",
        SortField::Added => "added",
    };
    format!("{name} {}", if asc { "▴" } else { "▾" })
}

// --- state -------------------------------------------------------------------

enum Msg {
    Key(KeyEvent),
    Paste(String),
    Scroll(i32),
    Resize,
    Results { generation: u64, source: SourceId, result: Result<Vec<TorrentResult>, String> },
    Notice(String, Tone),
    Rows(Vec<engine::Row>),
}

#[derive(Clone, Copy, PartialEq)]
enum Tone {
    Info,
    Good,
    Bad,
}

#[derive(Clone)]
enum SrcStatus {
    Pending,
    Ok(usize),
    Down(String),
}

#[derive(Clone, Copy, PartialEq)]
enum Pane {
    Results,
    Downloads,
}

struct App {
    engine: Arc<Client>,
    http: reqwest::Client,
    tx: UnboundedSender<Msg>,

    query: String,
    cursor: usize,
    editing: bool,
    last_query: String,
    generation: u64,
    searched_at: Option<Instant>,
    /// Showing the Top 100 instead of search results.
    top: bool,

    raw: HashMap<SourceId, Vec<TorrentResult>>,
    status: HashMap<SourceId, SrcStatus>,
    view: Vec<TorrentResult>,
    tab: usize,
    pane: Pane,
    table: TableState,
    dl_table: TableState,
    marked: HashSet<String>,
    sort: usize,
    hide_dead: bool,
    detail: bool,
    help: bool,
    confirm_delete: Option<usize>,
    notice: Option<(String, Tone, Instant)>,
    rows: Vec<engine::Row>,
    theme_checked: Instant,
    quit: bool,
}

impl App {
    fn new(engine: Arc<Client>, tx: UnboundedSender<Msg>) -> Self {
        Self {
            engine,
            http: sources::http_client(),
            tx,
            query: String::new(),
            cursor: 0,
            editing: true,
            last_query: String::new(),
            generation: 0,
            searched_at: None,
            top: false,
            raw: HashMap::new(),
            status: HashMap::new(),
            view: Vec::new(),
            tab: 0,
            pane: Pane::Results,
            table: TableState::default().with_selected(Some(0)),
            dl_table: TableState::default().with_selected(Some(0)),
            marked: HashSet::new(),
            sort: 0,
            hide_dead: false,
            detail: false,
            help: false,
            confirm_delete: None,
            notice: None,
            rows: Vec::new(),
            theme_checked: Instant::now(),
            quit: false,
        }
    }

    fn group(&self) -> Group {
        Group::TABS[self.tab]
    }

    fn notify(&mut self, msg: impl Into<String>, tone: Tone) {
        self.notice = Some((msg.into(), tone, Instant::now()));
    }

    // --- searching ---

    fn search(&mut self) {
        self.run(false);
    }

    /// The most-seeded torrents per category, from the sources that rank them.
    fn load_top(&mut self) {
        self.run(true);
    }

    /// Leave the search box and show the Top 100.
    fn open_top(&mut self) {
        if is_top_command(&self.query) {
            self.query.clear();
            self.cursor = 0;
        }
        self.editing = false;
        self.pane = Pane::Results;
        self.load_top();
    }

    fn run(&mut self, top: bool) {
        let q = if top { String::new() } else { self.query.trim().to_string() };
        self.top = top;
        self.generation += 1;
        self.last_query = q.clone();
        self.raw.clear();
        self.status.clear();
        self.marked.clear();
        self.searched_at = Some(Instant::now());
        self.table.select(Some(0));
        for src in SourceId::ALL.into_iter().filter(|s| !top || s.has_top()) {
            self.status.insert(src, SrcStatus::Pending);
            let tx = self.tx.clone();
            let http = self.http.clone();
            let q = q.clone();
            let generation = self.generation;
            tokio::spawn(async move {
                let job = async {
                    if top { src.top(&http).await } else { src.search(&http, &q).await }
                };
                let result = tokio::time::timeout(Duration::from_secs(45), job)
                    .await
                    .map_err(|_| "timed out".to_string())
                    .and_then(|r| r.map_err(|e| short_err(&e)));
                let _ = tx.send(Msg::Results { generation, source: src, result });
            });
        }
        self.rebuild();
    }

    fn on_results(&mut self, generation: u64, source: SourceId, result: Result<Vec<TorrentResult>, String>) {
        if generation != self.generation {
            return;
        }
        match result {
            Ok(list) => {
                self.status.insert(source, SrcStatus::Ok(list.len()));
                self.raw.insert(source, list);
            }
            Err(e) => {
                self.status.insert(source, SrcStatus::Down(e));
            }
        }
        self.rebuild();
    }

    fn pending(&self) -> bool {
        self.status.values().any(|s| matches!(s, SrcStatus::Pending))
    }

    /// Recompute the visible list, keeping the cursor on the same torrent.
    fn rebuild(&mut self) {
        // Follow the highlighted torrent as the list changes, unless the cursor
        // is still on the first row: then stay at the top while results stream in.
        let keep = self.selected().filter(|_| self.table.selected() != Some(0)).map(|r| r.info_hash.clone());
        let g = self.group();
        let all: Vec<TorrentResult> = SourceId::ALL
            .iter()
            .filter(|s| s.in_group(g))
            .filter_map(|s| self.raw.get(s))
            .flatten()
            .cloned()
            .collect();
        let mut list = sources::dedupe(all);
        if self.hide_dead {
            list.retain(|r| r.seeders > 0 || !r.source.reports_health());
        }
        sources::default_order(&mut list);
        if self.top {
            list.truncate(100);
        }
        let (field, asc) = SORTS[self.sort];
        let cmp_seed = |a: &TorrentResult, b: &TorrentResult| b.seeders.cmp(&a.seeders);
        match field {
            SortField::None => {}
            SortField::Size => list.sort_by(|a, b| dir(a.size_bytes.cmp(&b.size_bytes), asc).then(cmp_seed(a, b))),
            SortField::Seeders => list.sort_by(|a, b| dir(a.seeders.cmp(&b.seeders), asc)),
            SortField::Source => list.sort_by(|a, b| dir(a.source.label().cmp(b.source.label()), asc).then(cmp_seed(a, b))),
            SortField::Added => list.sort_by(|a, b| dir(a.added.unwrap_or(0).cmp(&b.added.unwrap_or(0)), asc).then(cmp_seed(a, b))),
        }
        self.view = list;
        let idx = keep
            .and_then(|h| self.view.iter().position(|r| r.info_hash == h))
            .unwrap_or_else(|| self.table.selected().unwrap_or(0).min(self.view.len().saturating_sub(1)));
        self.table.select(Some(idx));
        if idx == 0 {
            *self.table.offset_mut() = 0;
        }
    }

    fn selected(&self) -> Option<&TorrentResult> {
        self.table.selected().and_then(|i| self.view.get(i))
    }

    fn selected_dl(&self) -> Option<&engine::Row> {
        self.dl_table.selected().and_then(|i| self.rows.get(i))
    }

    // --- downloading ---

    fn download(&mut self, magnet: String, name: String) {
        let engine = self.engine.clone();
        let tx = self.tx.clone();
        tokio::spawn(async move {
            let msg = match engine.add(&magnet, Some(&name)).await {
                Ok(_) => Msg::Notice(format!("↓ Downloading {}", ellipsize(&name, 60)), Tone::Good),
                Err(e) => Msg::Notice(format!("Couldn't start {}: {}", ellipsize(&name, 40), short_err(&e)), Tone::Bad),
            };
            let _ = tx.send(msg);
        });
    }

    fn download_selection(&mut self) {
        let picks: Vec<TorrentResult> = if self.marked.is_empty() {
            self.selected().cloned().into_iter().collect()
        } else {
            self.view.iter().filter(|r| self.marked.contains(&r.info_hash)).cloned().collect()
        };
        if picks.is_empty() {
            return;
        }
        if picks.len() > 1 {
            self.notify(format!("↓ Queued {} torrents to {}", picks.len(), self.engine.out.display()), Tone::Good);
        }
        for r in picks {
            self.download(r.magnet, r.name);
        }
        self.marked.clear();
    }

    /// A magnet, a bare info hash, or a dropped .torrent path typed in the bar.
    fn try_direct(&mut self, input: &str) -> bool {
        if let Some(p) = magnet::parse_input(input) {
            self.download(p.magnet, p.name);
            self.query.clear();
            self.cursor = 0;
            return true;
        }
        let path = clean_path(input);
        if path.to_ascii_lowercase().ends_with(".torrent") && std::path::Path::new(&path).is_file() {
            let engine = self.engine.clone();
            let tx = self.tx.clone();
            tokio::spawn(async move {
                let msg = match engine.add_file(&path).await {
                    Ok(_) => Msg::Notice(format!("↓ Downloading {}", ellipsize(&path, 60)), Tone::Good),
                    Err(e) => Msg::Notice(format!("Couldn't open torrent file: {}", short_err(&e)), Tone::Bad),
                };
                let _ = tx.send(msg);
            });
            self.query.clear();
            self.cursor = 0;
            return true;
        }
        false
    }

    // --- input ---

    fn on_key(&mut self, k: KeyEvent) {
        if k.kind == KeyEventKind::Release {
            return;
        }
        let ctrl = k.modifiers.contains(KeyModifiers::CONTROL);
        if ctrl && k.code == KeyCode::Char('c') {
            self.quit = true;
            return;
        }
        if self.help {
            self.help = false;
            return;
        }
        if let Some(id) = self.confirm_delete {
            if matches!(k.code, KeyCode::Char('y') | KeyCode::Char('Y')) {
                self.engine_op(id, Op::Delete);
            }
            self.confirm_delete = None;
            return;
        }
        if self.editing {
            self.on_edit_key(k);
            return;
        }
        if self.detail {
            match k.code {
                KeyCode::Esc | KeyCode::Enter => self.detail = false,
                KeyCode::Char('d') => {
                    self.detail = false;
                    self.download_selection();
                }
                KeyCode::Char('y') => self.copy_magnet(),
                _ => {}
            }
            return;
        }
        match k.code {
            KeyCode::Char('Q') => self.quit = true,
            KeyCode::Char('?') => self.help = true,
            KeyCode::Char('/') => {
                self.editing = true;
                self.cursor = self.query.chars().count();
            }
            KeyCode::Char('m') => {
                self.editing = true;
                self.query.clear();
                self.cursor = 0;
                self.notify("Paste a magnet link, info hash, or .torrent path, then ↵", Tone::Info);
            }
            KeyCode::Tab | KeyCode::BackTab => {
                self.pane = if self.pane == Pane::Results { Pane::Downloads } else { Pane::Results };
            }
            KeyCode::Esc if self.pane == Pane::Downloads => self.pane = Pane::Results,
            KeyCode::Esc => {
                if !self.marked.is_empty() {
                    self.marked.clear();
                } else {
                    self.editing = true;
                }
            }
            _ if self.pane == Pane::Downloads => self.on_downloads_key(k),
            _ => self.on_results_key(k),
        }
    }

    fn on_results_key(&mut self, k: KeyEvent) {
        let n = self.view.len();
        let sel = self.table.selected().unwrap_or(0);
        match k.code {
            KeyCode::Down | KeyCode::Char('j') => self.table.select(Some((sel + 1).min(n.saturating_sub(1)))),
            KeyCode::Up | KeyCode::Char('k') => self.table.select(Some(sel.saturating_sub(1))),
            KeyCode::PageDown => self.table.select(Some((sel + 15).min(n.saturating_sub(1)))),
            KeyCode::PageUp => self.table.select(Some(sel.saturating_sub(15))),
            KeyCode::Home | KeyCode::Char('g') => self.table.select(Some(0)),
            KeyCode::End | KeyCode::Char('G') => self.table.select(Some(n.saturating_sub(1))),
            KeyCode::Right | KeyCode::Char('l') => {
                self.tab = (self.tab + 1) % Group::TABS.len();
                self.rebuild();
            }
            KeyCode::Left | KeyCode::Char('h') => {
                self.tab = (self.tab + Group::TABS.len() - 1) % Group::TABS.len();
                self.rebuild();
            }
            KeyCode::Char(c @ '1'..='7') => {
                self.tab = c as usize - '1' as usize;
                self.rebuild();
            }
            KeyCode::Char(' ') => {
                if let Some(h) = self.selected().map(|r| r.info_hash.clone()) {
                    if !self.marked.remove(&h) {
                        self.marked.insert(h);
                    }
                    self.table.select(Some((sel + 1).min(n.saturating_sub(1))));
                }
            }
            KeyCode::Char('d') | KeyCode::Char('D') => self.download_selection(),
            KeyCode::Enter => {
                if self.selected().is_some() {
                    self.detail = true;
                }
            }
            KeyCode::Char('s') => {
                self.sort = (self.sort + 1) % SORTS.len();
                self.rebuild();
                self.notify(format!("Sort: {}", sort_label(self.sort)), Tone::Info);
            }
            KeyCode::Char('z') => {
                self.hide_dead = !self.hide_dead;
                self.rebuild();
                let m = if self.hide_dead { "Hiding dead torrents" } else { "Showing all torrents" };
                self.notify(m, Tone::Info);
            }
            KeyCode::Char('y') => self.copy_magnet(),
            KeyCode::Char('r') if self.top => self.load_top(),
            KeyCode::Char('r') => self.search(),
            KeyCode::Char('t' | 'T') if self.top => self.search(),
            KeyCode::Char('t' | 'T') => self.load_top(),
            _ => {}
        }
    }

    fn on_downloads_key(&mut self, k: KeyEvent) {
        let n = self.rows.len();
        let sel = self.dl_table.selected().unwrap_or(0);
        let Some(row) = self.selected_dl().cloned() else {
            return;
        };
        match k.code {
            KeyCode::Down | KeyCode::Char('j') => self.dl_table.select(Some((sel + 1).min(n.saturating_sub(1)))),
            KeyCode::Up | KeyCode::Char('k') => self.dl_table.select(Some(sel.saturating_sub(1))),
            KeyCode::Char('p') | KeyCode::Char(' ') => self.engine_op(row.id, Op::Toggle),
            KeyCode::Char('c') => self.engine_op(row.id, Op::Remove),
            KeyCode::Char('X') => self.confirm_delete = Some(row.id),
            KeyCode::Char('e') | KeyCode::Char('o') | KeyCode::Enter => {
                let target = if row.folder.join(&row.name).exists() {
                    row.folder.join(&row.name)
                } else {
                    row.folder.clone()
                };
                let dir = if target.is_dir() { target } else { row.folder.clone() };
                open_folder(&dir);
                self.notify(format!("Opened {}", dir.display()), Tone::Info);
            }
            _ => {}
        }
    }

    fn engine_op(&mut self, id: usize, op: Op) {
        let engine = self.engine.clone();
        let tx = self.tx.clone();
        tokio::spawn(async move {
            let (r, done) = match op {
                Op::Toggle => (engine.toggle(id).await, None),
                Op::Remove => (engine.remove(id, false).await, Some("Removed from list (files kept)")),
                Op::Delete => (engine.remove(id, true).await, Some("Removed and deleted files")),
            };
            match (r, done) {
                (Err(e), _) => {
                    let _ = tx.send(Msg::Notice(short_err(&e), Tone::Bad));
                }
                (Ok(()), Some(m)) => {
                    let _ = tx.send(Msg::Notice(m.into(), Tone::Info));
                }
                _ => {}
            }
        });
    }

    fn on_edit_key(&mut self, k: KeyEvent) {
        let ctrl = k.modifiers.contains(KeyModifiers::CONTROL);
        match k.code {
            KeyCode::Enter if is_top_command(&self.query) => self.open_top(),
            KeyCode::Char('t') if ctrl => self.open_top(),
            KeyCode::Enter => {
                let q = self.query.trim().to_string();
                if !self.try_direct(&q) {
                    self.editing = false;
                    self.pane = Pane::Results;
                    self.search();
                }
            }
            KeyCode::Esc => {
                if self.query != self.last_query && !self.query.is_empty() {
                    self.query = self.last_query.clone();
                    self.cursor = self.query.chars().count();
                }
                self.editing = false;
            }
            KeyCode::Tab => {
                self.editing = false;
                self.pane = Pane::Downloads;
            }
            KeyCode::Down => self.editing = false,
            KeyCode::Char('u') if ctrl => {
                self.query.clear();
                self.cursor = 0;
            }
            KeyCode::Char('w') if ctrl => {
                let chars: Vec<char> = self.query.chars().collect();
                let mut i = self.cursor;
                while i > 0 && chars[i - 1] == ' ' {
                    i -= 1;
                }
                while i > 0 && chars[i - 1] != ' ' {
                    i -= 1;
                }
                self.query = chars[..i].iter().chain(chars[self.cursor..].iter()).collect();
                self.cursor = i;
            }
            KeyCode::Char('a') if ctrl => self.cursor = 0,
            KeyCode::Char('e') if ctrl => self.cursor = self.query.chars().count(),
            KeyCode::Char(c) if !ctrl => self.insert(&c.to_string()),
            KeyCode::Backspace if self.cursor > 0 => {
                let b = byte_at(&self.query, self.cursor - 1);
                self.query.remove(b);
                self.cursor -= 1;
            }
            KeyCode::Delete if self.cursor < self.query.chars().count() => {
                let b = byte_at(&self.query, self.cursor);
                self.query.remove(b);
            }
            KeyCode::Left => self.cursor = self.cursor.saturating_sub(1),
            KeyCode::Right => self.cursor = (self.cursor + 1).min(self.query.chars().count()),
            KeyCode::Home => self.cursor = 0,
            KeyCode::End => self.cursor = self.query.chars().count(),
            _ => {}
        }
    }

    fn insert(&mut self, s: &str) {
        let b = byte_at(&self.query, self.cursor);
        self.query.insert_str(b, s);
        self.cursor += s.chars().count();
    }

    fn on_paste(&mut self, text: String) {
        let text = text.trim().replace(['\n', '\r'], " ");
        // A dropped .torrent file or pasted magnet goes straight to downloads.
        if self.try_direct(&text) {
            self.editing = false;
            return;
        }
        if !self.editing {
            self.editing = true;
            self.cursor = self.query.chars().count();
        }
        self.insert(&text);
    }

    fn copy_magnet(&mut self) {
        if let Some(r) = self.selected() {
            let m = r.magnet.clone();
            copy_to_clipboard(&m);
            self.notify("Magnet link copied to clipboard", Tone::Good);
        }
    }

    fn tick(&mut self) {
        // Follow SpectrumOS wallpaper changes while running.
        if self.theme_checked.elapsed() >= Duration::from_secs(2) {
            self.theme_checked = Instant::now();
            theme::reload();
        }
        let n = self.rows.len();
        if let Some(s) = self.dl_table.selected() {
            if s >= n && n > 0 {
                self.dl_table.select(Some(n - 1));
            }
        }
        if let Some((_, _, at)) = &self.notice {
            if at.elapsed() > Duration::from_secs(5) {
                self.notice = None;
            }
        }
    }

    // --- drawing ---

    fn draw(&mut self, f: &mut Frame) {
        let area = f.area();
        f.render_widget(Block::new().style(Style::new().bg(th().bg).fg(th().fg)), area);
        let [header, search, tabs, body, notice, footer] = Layout::vertical([
            Constraint::Length(3),
            Constraint::Length(3),
            Constraint::Length(1),
            Constraint::Fill(1),
            Constraint::Length(1),
            Constraint::Length(1),
        ])
        .areas(area.inner(ratatui::layout::Margin { horizontal: 1, vertical: 0 }));

        self.draw_header(f, header);
        self.draw_search(f, search);
        self.draw_tabs(f, tabs);
        match self.pane {
            Pane::Results => self.draw_results(f, body),
            Pane::Downloads => self.draw_downloads(f, body),
        }
        self.draw_notice(f, notice);
        self.draw_footer(f, footer);

        if self.detail {
            self.draw_detail(f, area);
        }
        if self.help {
            draw_help(f, area);
        }
        if let Some(id) = self.confirm_delete {
            let name = self.rows.iter().find(|r| r.id == id).map(|r| r.name.clone()).unwrap_or_default();
            let r = centered(area, 60, 5);
            f.render_widget(Clear, r);
            f.render_widget(
                Paragraph::new(vec![
                    Line::from(format!("Delete files of “{}”?", ellipsize(&name, 44))).fg(th().fg),
                    Line::from(""),
                    Line::from(vec![Span::from("y").fg(th().error).bold(), Span::from(" delete   ").fg(th().muted), Span::from("any other key").fg(th().accent), Span::from(" cancel").fg(th().muted)]),
                ])
                .block(popup(" Confirm ").border_style(Style::new().fg(th().error))),
                r,
            );
        }
    }

    fn draw_header(&self, f: &mut Frame, area: Rect) {
        let mut lines: Vec<Line> = LOGO
            .iter()
            .enumerate()
            .map(|(i, l)| Line::from(Span::styled(*l, Style::new().fg(if i == 0 { th().accent } else { th().accent_alt }).bold())))
            .collect();
        lines.push(Line::from(vec![
            Span::from("torrents straight from your terminal · saving to ").fg(th().muted),
            Span::from(tilde(&self.engine.out)).fg(th().fg),
        ]));
        f.render_widget(Paragraph::new(lines), area);

        // Download summary, top right.
        let active = self.rows.iter().filter(|r| matches!(r.state, State::Downloading | State::Starting)).count();
        let seeding = self.rows.iter().filter(|r| r.state == State::Seeding).count();
        let down: f64 = self.rows.iter().map(|r| r.down).sum();
        let up: f64 = self.rows.iter().map(|r| r.up).sum();
        let summary = Line::from(vec![
            Span::from(format!("↓ {}  ", format::speed(down))).fg(th().accent),
            Span::from(format!("↑ {}  ", format::speed(up))).fg(th().accent_alt),
            Span::from(format!("{active} active · {seeding} seeding")).fg(th().muted),
        ])
        .right_aligned();
        f.render_widget(Paragraph::new(summary), Rect { height: 1, ..area });
    }

    fn draw_search(&self, f: &mut Frame, area: Rect) {
        let border = if self.editing { th().accent } else { th().rule };
        let block = Block::new()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::new().fg(border));
        let inner = block.inner(area);
        let content = if self.query.is_empty() && self.editing {
            Line::from(vec![
                Span::from("⌕ ").fg(th().accent),
                Span::from("Search, paste a magnet / info hash, drop a .torrent — or ↵ to browse").fg(th().muted),
            ])
        } else {
            Line::from(vec![Span::from("⌕ ").fg(th().accent), Span::from(self.query.as_str()).fg(th().fg)])
        };
        // keep the cursor visible on long input
        let width = inner.width.saturating_sub(3) as usize;
        let scroll = self.cursor.saturating_sub(width) as u16;
        f.render_widget(Paragraph::new(content).block(block).scroll((0, scroll)), area);
        if self.editing && !self.help {
            f.set_cursor_position((inner.x + 2 + (self.cursor as u16 - scroll), inner.y));
        }
    }

    fn draw_tabs(&self, f: &mut Frame, area: Rect) {
        let mut spans = Vec::new();
        for (i, g) in Group::TABS.iter().enumerate() {
            let label = format!(" {} ", g.label());
            if self.pane == Pane::Results && i == self.tab {
                spans.push(Span::styled(label, Style::new().fg(th().on_accent).bg(th().accent).bold()));
            } else {
                spans.push(Span::styled(label, Style::new().fg(th().muted)));
            }
            spans.push(Span::raw(" "));
        }
        spans.push(Span::from("│ ").fg(th().rule));
        let dl_label = format!(" Downloads {} ", if self.rows.is_empty() { String::new() } else { format!("({})", self.rows.len()) });
        if self.pane == Pane::Downloads {
            spans.push(Span::styled(dl_label, Style::new().fg(th().on_accent).bg(th().accent).bold()));
        } else {
            spans.push(Span::styled(dl_label, Style::new().fg(th().muted)));
        }
        let left = Line::from(spans);
        let left_w = left.width() as u16;
        f.render_widget(Paragraph::new(left), area);

        // Source health, right side. A source split across tabs (TPB) gets one
        // dot: its counts summed, pending while any part is, down only if all are.
        if self.pane == Pane::Results && !self.status.is_empty() {
            let g = self.group();
            let mut agg: Vec<(SourceId, Option<usize>, bool, bool)> = Vec::new(); // (src, count, pending, down)
            for src in SourceId::ALL.iter().filter(|s| s.in_group(g) && self.status.contains_key(s)) {
                let st = self.status.get(src).cloned().unwrap_or(SrcStatus::Pending);
                let i = match agg.iter().position(|a| a.0.label() == src.label()) {
                    Some(i) => i,
                    None => {
                        agg.push((*src, None, false, false));
                        agg.len() - 1
                    }
                };
                match st {
                    SrcStatus::Pending => agg[i].2 = true,
                    SrcStatus::Ok(n) => agg[i].1 = Some(agg[i].1.unwrap_or(0) + n),
                    SrcStatus::Down(_) => agg[i].3 = true,
                }
            }
            let build = |full: bool| {
                let mut s = Vec::new();
                for (src, count, pending, down) in &agg {
                    let (icon, c) = if *pending {
                        (spinner(), th().muted)
                    } else if count.is_some() {
                        ("●", th().success)
                    } else if *down {
                        ("✗", th().error)
                    } else {
                        ("●", th().muted)
                    };
                    s.push(Span::from(format!("{icon} ")).fg(c));
                    let text = match (full, count) {
                        (true, Some(n)) => format!("{} {n}  ", src.label()),
                        (true, None) => format!("{}  ", src.label()),
                        (false, _) => format!("{} ", src.tag()),
                    };
                    s.push(Span::from(text).fg(th().muted));
                }
                Line::from(s)
            };
            let room = area.width.saturating_sub(left_w + 2);
            let line = Some(build(true))
                .filter(|l| l.width() as u16 <= room)
                .or_else(|| Some(build(false)).filter(|l| l.width() as u16 <= room));
            if let Some(line) = line {
                f.render_widget(Paragraph::new(line.right_aligned()), area);
            }
        }
    }

    fn draw_results(&mut self, f: &mut Frame, area: Rect) {
        let title = if self.searched_at.is_none() {
            " Results ".to_string()
        } else if self.top {
            format!(" Top 100 · {} ", self.group().label())
        } else if self.last_query.is_empty() {
            format!(" Browsing latest · {} ", self.view.len())
        } else {
            format!(" “{}” · {} ", self.last_query, self.view.len())
        };
        let mut block = panel(&title);
        if self.sort != 0 || self.hide_dead || !self.marked.is_empty() {
            let mut bits = vec![];
            if !self.marked.is_empty() {
                bits.push(format!("{} marked", self.marked.len()));
            }
            if self.sort != 0 {
                bits.push(sort_label(self.sort));
            }
            if self.hide_dead {
                bits.push("alive only".into());
            }
            block = block.title_top(Line::from(format!(" {} ", bits.join(" · "))).fg(th().accent).right_aligned());
        }
        if !self.editing && self.pane == Pane::Results {
            block = block.border_style(Style::new().fg(th().accent));
        }

        if self.view.is_empty() {
            let msg = if self.searched_at.is_none() {
                vec![
                    Line::from(""),
                    Line::from("Type what you're looking for and press ↵.").fg(th().fg),
                    Line::from("Press ↵ on an empty box to browse what's new.").fg(th().muted),
                    Line::from("Type top100 and press ↵ for the most popular torrents.").fg(th().muted),
                ]
            } else if self.pending() {
                vec![Line::from(""), Line::from(format!("{} Searching every source…", spinner())).fg(th().muted)]
            } else {
                let down: Vec<String> = self
                    .status
                    .iter()
                    .filter_map(|(s, st)| match st {
                        SrcStatus::Down(e) if s.in_group(self.group()) => Some(format!("{}: {e}", s.label())),
                        _ => None,
                    })
                    .collect();
                let mut v = vec![Line::from(""), Line::from("Nothing found here.").fg(th().fg)];
                if self.top && self.group() == Group::Games {
                    v.push(Line::from("FitGirl doesn't report seeders, so Games has no Top 100.").fg(th().muted));
                } else if self.group() != Group::All {
                    v.push(Line::from("Try the All tab (← →), or another search.").fg(th().muted));
                }
                for d in down {
                    v.push(Line::from(format!("offline · {d}")).fg(th().error));
                }
                v
            };
            f.render_widget(Paragraph::new(msg).centered().block(block), area);
            return;
        }

        let rows = self.view.iter().map(|r| {
            let marked = self.marked.contains(&r.info_hash);
            let seeds = if r.source.reports_health() {
                let c = match r.seeders {
                    0 => th().error,
                    1..=9 => th().warning,
                    _ => th().success,
                };
                Cell::from(Line::from(format!("{}", r.seeders)).right_aligned()).fg(c)
            } else {
                Cell::from(Line::from("?").right_aligned()).fg(th().muted)
            };
            Row::new(vec![
                Cell::from(if marked { "◆" } else { " " }).fg(th().accent),
                Cell::from(r.source.tag()).fg(source_color(r.source)).bold(),
                Cell::from(Line::from(match r.kind {
                    // Say what non-video rows are: E-book, Comic, FLAC, …
                    Some(k) if !matches!(r.source, SourceId::TpbMovies | SourceId::TpbTv) => vec![
                        Span::from(format!("{k} · ")).fg(th().muted),
                        Span::from(r.name.as_str()).fg(if marked { th().accent } else { th().fg }),
                    ],
                    _ => vec![Span::from(r.name.as_str()).fg(if marked { th().accent } else { th().fg })],
                })),
                Cell::from(Line::from(format::bytes(r.size_bytes)).right_aligned()).fg(th().muted),
                seeds,
                Cell::from(Line::from(format::age(r.added)).right_aligned()).fg(th().muted),
            ])
        });
        let table = Table::new(
            rows,
            [
                Constraint::Length(1),
                Constraint::Length(4),
                Constraint::Fill(1),
                Constraint::Length(9),
                Constraint::Length(6),
                Constraint::Length(4),
            ],
        )
        .header(
            Row::new(vec!["", "SRC", "NAME", "     SIZE", "  SEED", " AGE"])
                .style(Style::new().fg(th().muted).add_modifier(Modifier::BOLD))
                .bottom_margin(0),
        )
        .column_spacing(1)
        .row_highlight_style(Style::new().bg(th().selection).add_modifier(Modifier::BOLD))
        .highlight_symbol(Span::from("❯ ").fg(th().accent))
        .highlight_spacing(ratatui::widgets::HighlightSpacing::Always)
        .block(block);
        f.render_stateful_widget(table, area, &mut self.table);
    }

    fn draw_downloads(&mut self, f: &mut Frame, area: Rect) {
        let mut block = panel(&format!(" Downloads → {} ", tilde(&self.engine.out))).border_style(Style::new().fg(th().accent));
        block = block.title_top(Line::from(" downloads keep going after you quit ").fg(th().muted).right_aligned());
        if self.rows.is_empty() {
            f.render_widget(
                Paragraph::new(vec![
                    Line::from(""),
                    Line::from("Nothing downloading yet.").fg(th().fg),
                    Line::from("Pick a result and press d — it lands in your downloads folder.").fg(th().muted),
                ])
                .centered()
                .block(block),
                area,
            );
            return;
        }
        let inner_w = area.width.saturating_sub(4);
        let bar_w = (inner_w / 5).clamp(10, 30) as usize;
        let rows = self.rows.iter().map(|r| {
            let (icon, color, label) = match r.state {
                State::Starting => (spinner(), th().muted, "finding peers…".to_string()),
                State::Downloading => ("↓", th().accent, r.eta.map(|e| format!("{} left", format::duration(e))).unwrap_or_else(|| "waiting for peers".into())),
                State::Seeding => ("↑", th().accent_alt, if r.uploaded > 0 { format!("seeding · {} up", format::bytes(r.uploaded)) } else { "seeding".into() }),
                State::Paused => ("⏸", th().warning, "paused".into()),
                State::Done => ("✓", th().success, "done".into()),
                State::Error => ("✗", th().error, r.error.clone().unwrap_or_else(|| "error".into())),
            };
            let frac = r.fraction();
            let filled = (frac * bar_w as f64).round() as usize;
            let bar = Line::from(vec![
                Span::from("━".repeat(filled)).fg(if frac >= 1.0 { th().success } else { th().accent }),
                Span::from("━".repeat(bar_w - filled.min(bar_w))).fg(th().rule),
            ]);
            let speed = match r.state {
                State::Downloading => format!("↓ {} · {} peers", format::speed(r.down), r.peers),
                State::Seeding => format!("↑ {} · {} peers", format::speed(r.up), r.peers),
                _ => String::new(),
            };
            Row::new(vec![
                Cell::from(icon).fg(color).bold(),
                Cell::from(r.name.as_str()).fg(th().fg),
                Cell::from(bar),
                Cell::from(Line::from(format!("{:>3.0}%", frac * 100.0)).right_aligned()).fg(th().fg),
                Cell::from(Line::from(format::bytes(r.total)).right_aligned()).fg(th().muted),
                Cell::from(speed).fg(th().muted),
                Cell::from(label).fg(color),
            ])
        });
        let table = Table::new(
            rows,
            [
                Constraint::Length(1),
                Constraint::Fill(1),
                Constraint::Length(bar_w as u16),
                Constraint::Length(4),
                Constraint::Length(9),
                Constraint::Length(24),
                Constraint::Length(20),
            ],
        )
        .column_spacing(1)
        .row_highlight_style(Style::new().bg(th().selection))
        .highlight_symbol(Span::from("❯ ").fg(th().accent))
        .highlight_spacing(ratatui::widgets::HighlightSpacing::Always)
        .block(block);
        f.render_stateful_widget(table, area, &mut self.dl_table);
    }

    fn draw_notice(&self, f: &mut Frame, area: Rect) {
        let line = if let Some((m, tone, _)) = &self.notice {
            let c = match tone {
                Tone::Info => th().fg,
                Tone::Good => th().success,
                Tone::Bad => th().error,
            };
            Line::from(Span::from(format!(" {m}")).fg(c))
        } else if self.pending() {
            let left = self.status.values().filter(|s| matches!(s, SrcStatus::Pending)).count();
            Line::from(format!(" {} waiting on {left} source{}…", spinner(), if left == 1 { "" } else { "s" })).fg(th().muted)
        } else {
            Line::from("")
        };
        f.render_widget(Paragraph::new(line), area);
    }

    fn draw_footer(&self, f: &mut Frame, area: Rect) {
        let top = if self.top { "back to search" } else { "top 100" };
        let hints: &[(&str, &str)] = if self.editing {
            &[("↵", "search"), ("ctrl+t", "top 100"), ("esc", "results"), ("tab", "downloads"), ("ctrl+u", "clear"), ("ctrl+c", "quit")]
        } else if self.detail {
            &[("d", "download"), ("y", "copy magnet"), ("esc", "back")]
        } else if self.pane == Pane::Downloads {
            &[("↑↓", "move"), ("p", "pause/resume"), ("e", "open folder"), ("c", "remove"), ("X", "delete files"), ("tab", "results"), ("Q", "quit")]
        } else {
            &[("↑↓", "move"), ("←→", "category"), ("d", "download"), ("␣", "mark"), ("↵", "details"), ("shift+t", top), ("/", "search"), ("s", "sort"), ("tab", "downloads"), ("?", "keys")]
        };
        let mut spans = Vec::new();
        for (k, l) in hints {
            spans.push(Span::from(format!(" {k} ")).fg(th().accent).bold());
            spans.push(Span::from(format!("{l}  ")).fg(th().muted));
        }
        f.render_widget(Paragraph::new(Line::from(spans)), area);
    }

    fn draw_detail(&self, f: &mut Frame, area: Rect) {
        let Some(r) = self.selected() else { return };
        let w = area.width.saturating_sub(8).min(90);
        let rect = centered(area, w, 17);
        f.render_widget(Clear, rect);
        let kv = |k: &str, v: String, c: Color| {
            Line::from(vec![Span::from(format!("{k:<10}")).fg(th().muted), Span::from(v).fg(c)])
        };
        let seeds = if r.source.reports_health() {
            format!("{} seeders · {} leechers", r.seeders, r.leechers)
        } else {
            "unknown (this source doesn't report swarm health)".into()
        };
        let mut lines = vec![
            Line::from(Span::from(r.name.clone()).fg(th().accent).bold()),
            Line::from(""),
            kv("Source", r.source.label().into(), source_color(r.source)),
            kv("Type", r.kind.unwrap_or("—").into(), th().fg),
            kv("Size", format::bytes(r.size_bytes), th().fg),
            kv("Health", seeds, th().fg),
        ];
        if let Some(n) = r.num_files {
            lines.push(kv("Files", n.to_string(), th().fg));
        }
        lines.push(kv("Added", format!("{} ago", format::age(r.added)), th().fg));
        lines.push(kv("Hash", r.info_hash.clone(), th().fg));
        lines.push(kv("Trackers", magnet::trackers_of(&r.magnet).len().to_string(), th().fg));
        lines.push(kv("Saves to", tilde(&self.engine.out), th().fg));
        if r.source == SourceId::Fitgirl {
            lines.push(Line::from(""));
            lines.push(Line::from("Games can run code — FitGirl is the only game source for that reason.").fg(th().warning));
        }
        f.render_widget(
            Paragraph::new(Text::from(lines))
                .wrap(Wrap { trim: false })
                .block(popup(" Details ").border_style(Style::new().fg(th().accent)).padding(ratatui::widgets::Padding::horizontal(1))),
            rect,
        );
    }
}

#[derive(Clone, Copy)]
enum Op {
    Toggle,
    Remove,
    Delete,
}

fn dir(o: std::cmp::Ordering, asc: bool) -> std::cmp::Ordering {
    if asc { o } else { o.reverse() }
}

fn panel(title: &str) -> Block<'static> {
    Block::new()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::new().fg(th().rule))
        .title(Line::from(title.to_string()).fg(th().fg).bold())
}

/// An overlay panel, raised onto the palette's surface color.
fn popup(title: &str) -> Block<'static> {
    panel(title).style(Style::new().bg(th().surface))
}

/// "top100" or "Top 100" typed into the search box.
fn is_top_command(q: &str) -> bool {
    let q: String = q.chars().filter(|c| !c.is_whitespace()).collect::<String>().to_lowercase();
    q == "top100"
}

fn draw_help(f: &mut Frame, area: Rect) {
    let groups: [(&str, &[(&str, &str)]); 3] = [
        (
            "Anywhere",
            &[
                ("/", "Edit search"),
                ("m", "Paste magnet / hash / .torrent"),
                ("top100 ↵ · ctrl+t", "Top 100"),
                ("tab", "Switch Results ↔ Downloads"),
                ("?", "This help"),
                ("Q · ctrl+c", "Quit"),
            ],
        ),
        (
            "Results",
            &[
                ("↑↓ / jk", "Move"),
                ("←→ / hl / 1-7", "Category tab"),
                ("␣", "Mark for batch"),
                ("d", "Download (marked or current)"),
                ("↵", "Details"),
                ("s", "Cycle sort"),
                ("z", "Hide dead torrents"),
                ("y", "Copy magnet"),
                ("t / T", "Top 100 / back to search"),
                ("r", "Re-run search or refresh"),
            ],
        ),
        (
            "Downloads",
            &[
                ("p / ␣", "Pause / resume"),
                ("e / ↵", "Open folder"),
                ("c", "Remove from list (keeps files)"),
                ("X", "Remove and delete files"),
            ],
        ),
    ];
    let mut lines = vec![];
    for (title, keys) in groups {
        lines.push(Line::from(Span::from(title).fg(th().accent).bold()));
        for (k, l) in keys {
            lines.push(Line::from(vec![Span::from(format!("  {k:<18}")).fg(th().accent), Span::from(*l).fg(th().fg)]));
        }
        lines.push(Line::from(""));
    }
    lines.push(Line::from("Downloads continue in the background after you quit (Q).").fg(th().muted));
    let h = lines.len() as u16 + 2;
    let rect = centered(area, 62, h);
    f.render_widget(Clear, rect);
    f.render_widget(
        Paragraph::new(lines).block(popup(" Keys ").border_style(Style::new().fg(th().accent)).padding(ratatui::widgets::Padding::horizontal(1))),
        rect,
    );
}

fn centered(area: Rect, w: u16, h: u16) -> Rect {
    let w = w.min(area.width);
    let h = h.min(area.height);
    Rect { x: area.x + (area.width - w) / 2, y: area.y + (area.height - h) / 2, width: w, height: h }
}

fn spinner() -> &'static str {
    const FRAMES: [&str; 10] = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
    let ms = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    FRAMES[(ms / 100) as usize % FRAMES.len()]
}

fn byte_at(s: &str, char_idx: usize) -> usize {
    s.char_indices().nth(char_idx).map(|(b, _)| b).unwrap_or(s.len())
}

pub fn ellipsize(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        s.to_string()
    } else {
        format!("{}…", s.chars().take(max - 1).collect::<String>())
    }
}

pub fn short_err(e: &dyn std::fmt::Display) -> String {
    let s = e.to_string();
    let s = s.lines().next().unwrap_or("").to_string();
    if s.contains("error sending request") || s.contains("dns") {
        "unreachable".into()
    } else {
        ellipsize(&s, 60)
    }
}

fn tilde(p: &std::path::Path) -> String {
    if let Some(home) = dirs::home_dir() {
        if let Ok(rest) = p.strip_prefix(&home) {
            return format!("~/{}", rest.display());
        }
    }
    p.display().to_string()
}

/// Paths dropped onto a terminal arrive quoted or as file:// URIs.
fn clean_path(s: &str) -> String {
    let s = s.trim().trim_matches(|c| c == '\'' || c == '"');
    let s = s.strip_prefix("file://").unwrap_or(s);
    let s = urlencoding::decode(s).map(|c| c.into_owned()).unwrap_or_else(|_| s.to_string());
    s.replace("\\ ", " ")
}

fn open_folder(p: &std::path::Path) {
    let cmd = if cfg!(target_os = "macos") {
        "open"
    } else if cfg!(windows) {
        "explorer"
    } else {
        "xdg-open"
    };
    let _ = std::process::Command::new(cmd)
        .arg(p)
        .stdin(std::process::Stdio::null())
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .spawn();
}

fn copy_to_clipboard(text: &str) {
    use std::io::Write;
    let tools: &[(&str, &[&str])] = &[
        ("wl-copy", &[]),
        ("xclip", &["-selection", "clipboard"]),
        ("xsel", &["--clipboard", "--input"]),
        ("pbcopy", &[]),
    ];
    for (bin, args) in tools {
        if let Ok(mut child) = std::process::Command::new(bin)
            .args(*args)
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()
        {
            if let Some(mut stdin) = child.stdin.take() {
                let _ = stdin.write_all(text.as_bytes());
            }
            if child.wait().map(|s| s.success()).unwrap_or(false) {
                return;
            }
        }
    }
    // OSC 52: works over ssh in most modern terminals.
    use base64::Engine as _;
    let b64 = base64::engine::general_purpose::STANDARD.encode(text);
    let mut out = std::io::stdout();
    let _ = write!(out, "\x1b]52;c;{b64}\x07");
    let _ = out.flush();
}

// --- main loop ----------------------------------------------------------------

pub async fn run(engine: Arc<Client>) -> Result<usize> {
    let (tx, mut rx): (UnboundedSender<Msg>, UnboundedReceiver<Msg>) = unbounded_channel();

    // crossterm's reader blocks, so it lives on its own thread.
    let input_tx = tx.clone();
    std::thread::spawn(move || {
        loop {
            let msg = match event::read() {
                Ok(Event::Key(k)) => Msg::Key(k),
                Ok(Event::Paste(s)) => Msg::Paste(s),
                Ok(Event::Resize(..)) => Msg::Resize,
                Ok(Event::Mouse(m)) => match m.kind {
                    MouseEventKind::ScrollDown => Msg::Scroll(3),
                    MouseEventKind::ScrollUp => Msg::Scroll(-3),
                    _ => continue,
                },
                Ok(_) => continue,
                Err(_) => break,
            };
            if input_tx.send(msg).is_err() {
                break;
            }
        }
    });

    let mut terminal: DefaultTerminal = ratatui::init();
    crossterm::execute!(
        std::io::stdout(),
        crossterm::event::EnableBracketedPaste,
        crossterm::event::EnableMouseCapture
    )?;
    theme::reload();

    // Download state comes from the background service; poll it off the UI loop.
    let poll_tx = tx.clone();
    let poll_engine = engine.clone();
    tokio::spawn(async move {
        loop {
            match poll_engine.rows().await {
                Ok(rows) => {
                    if poll_tx.send(Msg::Rows(rows)).is_err() {
                        break;
                    }
                }
                Err(e) => {
                    let _ = poll_tx.send(Msg::Notice(format!("Background service: {}", short_err(&e)), Tone::Bad));
                }
            }
            tokio::time::sleep(Duration::from_millis(500)).await;
        }
    });

    let mut app = App::new(engine, tx);
    app.tick();

    let mut ticker = tokio::time::interval(Duration::from_millis(250));
    let res: Result<()> = async {
        loop {
            terminal.draw(|f| app.draw(f))?;
            tokio::select! {
                _ = ticker.tick() => app.tick(),
                Some(msg) = rx.recv() => {
                    match msg {
                        Msg::Key(k) => app.on_key(k),
                        Msg::Paste(s) => app.on_paste(s),
                        Msg::Scroll(d) => {
                            let (t, n) = match app.pane {
                                Pane::Results => (&mut app.table, app.view.len()),
                                Pane::Downloads => (&mut app.dl_table, app.rows.len()),
                            };
                            let cur = t.selected().unwrap_or(0) as i32;
                            t.select(Some((cur + d).clamp(0, n.saturating_sub(1) as i32) as usize));
                        }
                        Msg::Resize => {}
                        Msg::Results { generation, source, result } => app.on_results(generation, source, result),
                        Msg::Notice(m, tone) => app.notify(m, tone),
                        Msg::Rows(rows) => { app.rows = rows; app.tick(); }
                    }
                }
            }
            if app.quit {
                return Ok(());
            }
        }
    }
    .await;

    let _ = crossterm::execute!(
        std::io::stdout(),
        crossterm::event::DisableBracketedPaste,
        crossterm::event::DisableMouseCapture
    );
    ratatui::restore();
    res.map(|_| crate::daemon::active_count(&app.rows))
}
