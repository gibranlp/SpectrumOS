use anyhow::{Context, Result, bail};
use chrono::Utc;
use questline::{app::App, audio::{AudioPlayer, PlaybackStatus, SOUNDSCAPES}, storage};
use serde_json::{Value, json};
use std::{io::{self, Write}, path::PathBuf, time::{Duration, Instant}};
use uuid::Uuid;

fn optional_id(request: &Value, field: &str) -> Result<Option<Uuid>> {
    request[field].as_str().filter(|value| !value.is_empty())
        .map(Uuid::parse_str).transpose().map_err(Into::into)
}

fn complete(app: &mut App, minutes: i64) -> Result<()> {
    app.reload_data()?;
    app.active_focus_session.as_mut().context("Focus session missing")?.start_time =
        Utc::now() - chrono::Duration::minutes(minutes);
    app.tick_focus_session()
}

fn run() -> Result<()> {
    let request: Value = serde_json::from_str(&std::env::args().nth(1).context("Missing focus request")?)?;
    let minutes = request["duration"].as_i64().context("Missing duration")?;
    if !(5..=180).contains(&minutes) { bail!("Choose a duration from 5 to 180 minutes"); }
    let soundscape = request["soundscape"].as_str().unwrap_or("Silent");
    let soundscape_index = SOUNDSCAPES.iter().position(|item| item.name == soundscape)
        .context("Unknown soundscape")?;
    let project_id = optional_id(&request, "project_id")?;
    let task_id = optional_id(&request, "task_id")?;
    let control = PathBuf::from(request["control"].as_str().context("Missing control path")?);
    let path = storage::get_storage_dir()?.join("questline.db");
    if !path.is_file() { bail!("Open Questline and complete onboarding first"); }
    let mut app = App::new_headless(&path)?;
    if app.user.is_none() { bail!("Open Questline and complete onboarding first"); }
    if let Some(id) = project_id {
        let project = app.db.get_projects()?.into_iter().find(|project| project.id == id)
            .context("Campaign no longer exists")?;
        if project.archived || project.completed { bail!("Choose an active campaign"); }
    }
    if let Some(id) = task_id {
        let task = app.db.get_task_by_id(id)?;
        if task.completed || task.project_id != project_id { bail!("Choose an unfinished task in this campaign"); }
    }
    app.external_notifications = false;
    let audio_settings = app.audio_player.get_state();
    app.audio_player = AudioPlayer::new();
    app.audio_player.set_volume(audio_settings.volume);
    app.audio_player.set_sound_effects_enabled(audio_settings.sound_effects_enabled);
    app.audio_player.set_sound_effects_volume(audio_settings.sound_effects_volume);
    app.audio_player.set_local_music_folder(&audio_settings.local_music_folder);
    app.selected_focus_soundscape_idx = soundscape_index + 1;
    app.start_focus_session(minutes as i32, project_id, task_id)?;
    let mut elapsed = Duration::ZERO;
    let mut previous = Instant::now();
    let mut paused = false;
    loop {
        let now = Instant::now();
        if !paused { elapsed += now.duration_since(previous); }
        previous = now;
        let command: Value = serde_json::from_str(&std::fs::read_to_string(&control)?)?;
        if command["cancelled"].as_bool().unwrap_or(false) {
            app.audio_player.stop();
            println!("{}", json!({"phase":"idle", "remaining":minutes * 60}));
            return Ok(());
        }
        let next_paused = command["paused"].as_bool().unwrap_or(false);
        if next_paused != paused {
            if !next_paused && app.audio_player.get_state().status == PlaybackStatus::Paused {
                app.audio_player.pause();
            }
            paused = next_paused;
        }
        if paused && app.audio_player.get_state().status == PlaybackStatus::Playing {
            app.audio_player.pause();
        }
        let remaining = (minutes * 60 - elapsed.as_secs() as i64).max(0);
        if remaining == 0 {
            // Questline calcula y registra sus recompensas; el shell no escribe XP directamente.
            complete(&mut app, minutes)?;
            println!("{}", json!({"phase":"completed", "remaining":0, "message":"Focus complete — Questline XP awarded"}));
            io::stdout().flush()?;
            return Ok(());
        }
        println!("{}", json!({"phase":if paused {"paused"} else {"work"}, "remaining":remaining}));
        io::stdout().flush()?;
        std::thread::sleep(Duration::from_millis(250));
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use questline::models::{ClassType, User};

    #[test]
    fn completion_records_native_rewards_and_preserves_existing_xp() {
        let path = std::env::temp_dir().join(format!("spectrum-focus-{}.db", Uuid::new_v4()));
        let mut app = App::new_headless(&path).unwrap();
        let mut user = User { id: Uuid::new_v4(), username: "Focus test".into(),
            class: ClassType::CodeWarlock, level: 1, xp: 0, created_at: Utc::now(), specialization: None };
        app.db.insert_user(&user).unwrap();
        app.reload_data().unwrap();
        app.selected_focus_soundscape_idx = SOUNDSCAPES.iter().position(|item| item.name == "Silent").unwrap() + 1;
        app.start_focus_session(25, None, None).unwrap();
        assert!(app.db.get_focus_sessions().unwrap().is_empty());
        user.xp = 7;
        app.db.update_user(&user).unwrap();
        complete(&mut app, 25).unwrap();
        let sessions = app.db.get_focus_sessions().unwrap();
        assert_eq!(sessions.len(), 1);
        assert_eq!(sessions[0].duration_mins, 25);
        assert_eq!(sessions[0].soundscape, "Silent");
        assert!(app.db.get_user().unwrap().unwrap().xp >= 27);
        app.tick_focus_session().unwrap();
        assert_eq!(app.db.get_focus_sessions().unwrap().len(), 1);
        std::fs::remove_file(path).unwrap();
    }
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error:#}");
        std::process::exit(1);
    }
}
