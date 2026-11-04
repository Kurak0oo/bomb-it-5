//! Original-SWF research player: pinned Ruffle, offscreen Vulkan (Metal on macOS), explicit frame steps.
//! Reads commands from stdin, one per line. Frame counter = number of run_frame() calls.
use anyhow::{anyhow, Result};
use ruffle_core::events::{KeyDescriptor, KeyLocation, LogicalKey, MouseButton, NamedKey, PhysicalKey};
use ruffle_core::limits::ExecutionLimit;
use ruffle_core::tag_utils::movie_from_path;
use ruffle_core::{Player, PlayerBuilder, PlayerEvent};
use ruffle_render_wgpu::backend::{create_wgpu_instance, request_adapter_and_device, WgpuRenderBackend};
use ruffle_render_wgpu::descriptors::Descriptors;
use ruffle_render_wgpu::target::TextureTarget;
use ruffle_render_wgpu::wgpu;
use ruffle_core::FloatDuration;
use std::any::Any;
use std::io::{BufRead, Write};
use std::sync::{Arc, Mutex};
use std::time::{Instant, Duration};

fn key(name: &str) -> Result<KeyDescriptor> {
    let (l, p) = match name {
        "left" => (LogicalKey::Named(NamedKey::ArrowLeft), PhysicalKey::ArrowLeft),
        "right" => (LogicalKey::Named(NamedKey::ArrowRight), PhysicalKey::ArrowRight),
        "up" => (LogicalKey::Named(NamedKey::ArrowUp), PhysicalKey::ArrowUp),
        "down" => (LogicalKey::Named(NamedKey::ArrowDown), PhysicalKey::ArrowDown),
        "space" => (LogicalKey::Character(' '), PhysicalKey::Space),
        "enter" => (LogicalKey::Named(NamedKey::Enter), PhysicalKey::Enter),
        "esc" => (LogicalKey::Named(NamedKey::Escape), PhysicalKey::Escape),
        "p" => (LogicalKey::Character('p'), PhysicalKey::KeyP),
        _ => return Err(anyhow!("unknown key {name}")),
    };
    Ok(KeyDescriptor { physical_key: p, logical_key: l, key_location: KeyLocation::Standard })
}

fn main() -> Result<()> {
    tracing_subscriber::fmt().with_env_filter("warn").with_writer(std::io::stderr).init();
    let args: Vec<String> = std::env::args().collect();
    let swf = &args[1];
    // `--scale N` renders the 700×510 stage at N× (render bake-off); input coordinates
    // stay in stage units and are scaled here, so cases run unchanged.
    let scale: f64 = match args.iter().position(|a| a == "--scale") {
        Some(i) => args.get(i + 1).ok_or(anyhow!("--scale needs a value"))?.parse()?,
        None => 1.0,
    };
    // Vulkan everywhere it exists, so recorded runs keep their renderer; macOS has Metal only.
    #[cfg(target_os = "macos")]
    let backends = wgpu::Backends::METAL;
    #[cfg(not(target_os = "macos"))]
    let backends = wgpu::Backends::VULKAN;
    let instance = create_wgpu_instance(backends, wgpu::BackendOptions::default(), None);
    let (adapter, device, queue) = futures::executor::block_on(request_adapter_and_device(
        backends, &instance, None, wgpu::PowerPreference::LowPower))
        .map_err(|e| anyhow!(e.to_string()))?;
    eprintln!("adapter: {:?}", adapter.get_info());
    let descriptors = Arc::new(Descriptors::new(instance, adapter, device, queue));
    let movie = movie_from_path(swf, None).map_err(|e| anyhow!(e.to_string()))?;
    let (w, h) = ((700.0 * scale).round() as u32, (510.0 * scale).round() as u32);
    let target = TextureTarget::new(&descriptors.device, (w, h)).map_err(|e| anyhow!(e.to_string()))?;
    let player: Arc<Mutex<Player>> = PlayerBuilder::new()
        .with_renderer(WgpuRenderBackend::new(descriptors.clone(), target).map_err(|e| anyhow!(e.to_string()))?)
        .with_movie(movie)
        .with_viewport_dimensions(w, h, scale)
        .with_autoplay(true)
        .build();
    let mut frame: u64 = 0;
    let mut realtime = false;
    let mut cap_dir: Option<String> = None;
    #[cfg(feature = "reference-state")]
    let mut trace_dir: Option<String> = None;
    #[cfg(feature = "reference-state")]
    let mut trace_mode = "full";
    #[cfg(feature = "reference-events")]
    let mut event_dir: Option<String> = None;
    let t0 = Instant::now();
    let stdin = std::io::stdin();
    let mut out = std::io::stdout();
    let shot = |p: &Arc<Mutex<Player>>, path: &str| -> Result<()> {
        let mut pl = p.lock().unwrap();
        pl.render();
        let r = <dyn Any>::downcast_mut::<WgpuRenderBackend<TextureTarget>>(pl.renderer_mut()).unwrap();
        let img = r.capture_frame().ok_or(anyhow!("no frame"))?;
        img.save(path)?;
        Ok(())
    };
    #[cfg(feature = "reference-focus")]
    let focus = |p: &Arc<Mutex<Player>>| {
        let mut pl = p.lock().unwrap();
        let mut state = pl.reference_focus_state();
        if state["available"] == false {
            // Discover the weak Game reference without executing ActionScript.
            let _ = pl.reference_state(32, 20000);
            state = pl.reference_focus_state();
            state["bootstrap_full_graph"] = serde_json::Value::Bool(true);
        }
        state
    };
    for line in stdin.lock().lines() {
        let line = line?;
        let t: Vec<&str> = line.split_whitespace().collect();
        if t.is_empty() || t[0].starts_with('#') { continue; }
        let ev = |e: PlayerEvent| { player.lock().unwrap().handle_event(e); };
        #[cfg(feature = "reference-events")]
        player.lock().unwrap().reference_events_mark(frame, line.clone()).map_err(|e|anyhow!(e))?;
        match t[0] {
            "step" => {
                let n: u64 = t[1].parse()?;
                for _ in 0..n {
                    let fstart = Instant::now();
                    let dt = {
                        let mut pl = player.lock().unwrap();
                        pl.preload(&mut ExecutionLimit::none());
                        #[cfg(feature = "reference-events")]
                        pl.reference_events_mark(frame + 1, "run_frame".into()).map_err(|e|anyhow!(e))?;
                        pl.run_frame();
                        let fr = pl.frame_rate();
                        let dt = FloatDuration::from_millis(1000.0 / fr);
                        #[cfg(feature = "reference-events")]
                        pl.reference_events_mark(frame + 1, "update_timers".into()).map_err(|e|anyhow!(e))?;
                        pl.update_timers(dt);
                        dt
                    };
                    frame += 1;
                    #[cfg(feature = "reference-events")]
                    if let Some(d) = &event_dir {
                        let events = player.lock().unwrap().reference_events_drain();
                        std::fs::write(format!("{d}/f{frame:06}.json"), serde_json::to_vec(&events)?)?;
                    }
                    #[cfg(feature = "reference-state")]
                    if let Some(d) = &trace_dir {
                        let state = match trace_mode {
                            #[cfg(feature = "reference-compact")]
                            "compact" => player.lock().unwrap().reference_compact_state(32, 20000),
                            #[cfg(feature = "reference-focus")]
                            "focus" => focus(&player),
                            _ => player.lock().unwrap().reference_state(32, 20000),
                        };
                        std::fs::write(format!("{d}/f{frame:06}.json"), serde_json::to_vec(&state)?)?;
                    }
                    if let Some(d) = &cap_dir { shot(&player, &format!("{d}/f{frame:06}.png"))?; }
                    if realtime {
                        let want = Duration::from_secs_f64(dt.as_millis() / 1000.0);
                        let el = fstart.elapsed();
                        if el < want { std::thread::sleep(want - el); }
                    }
                }
            }
            "cap" => { cap_dir = if t.len() > 1 && t[1] != "off" { std::fs::create_dir_all(t[1])?; Some(t[1].to_string()) } else { None }; }
            #[cfg(feature = "reference-state")]
            "trace" => {
                trace_mode = "full";
                trace_dir = if t.len() > 1 && t[1] != "off" { std::fs::create_dir_all(t[1])?; Some(t[1].to_string()) } else { None };
            }
            #[cfg(feature = "reference-compact")]
            "trace-compact" => {
                trace_mode = "compact";
                trace_dir = if t.len() > 1 && t[1] != "off" { std::fs::create_dir_all(t[1])?; Some(t[1].to_string()) } else { None };
            }
            #[cfg(feature = "reference-compact")]
            "compact" => {
                let state = player.lock().unwrap().reference_compact_state(32, 20000);
                std::fs::write(t[1], serde_json::to_vec(&state)?)?;
            }
            #[cfg(feature = "reference-focus")]
            "trace-focus" => {
                trace_mode = "focus";
                trace_dir = if t.len() > 1 && t[1] != "off" { std::fs::create_dir_all(t[1])?; Some(t[1].to_string()) } else { None };
            }
            #[cfg(feature = "reference-focus")]
            "focus" => {
                let state = focus(&player);
                std::fs::write(t[1], serde_json::to_vec(&state)?)?;
            }
            #[cfg(feature = "reference-events")]
            "events" => {
                if t[1] == "off" {
                    if let Some(d) = &event_dir {
                        let events = player.lock().unwrap().reference_events_drain();
                        std::fs::write(format!("{d}/tail-{frame:06}.json"), serde_json::to_vec(&events)?)?;
                    }
                    event_dir = None;
                    player.lock().unwrap().reference_events_enable(false, 20000, Vec::new()).map_err(|e|anyhow!(e))?;
                } else {
                    let capacity = t.get(2).map(|s|s.parse()).transpose()?.unwrap_or(20000);
                    let prefixes = t.iter().skip(3).map(|s|s.to_string()).collect();
                    player.lock().unwrap().reference_events_enable(true, capacity, prefixes).map_err(|e|anyhow!(e))?;
                    event_dir = if t[1] == "on" { None } else { std::fs::create_dir_all(t[1])?; Some(t[1].to_string()) };
                }
            }
            #[cfg(feature = "reference-events")]
            "events-dump" => {
                let events = player.lock().unwrap().reference_events_drain();
                std::fs::write(t[1], serde_json::to_vec(&events)?)?;
            }
            #[cfg(feature = "reference-events")]
            "seed" => {
                if frame != 0 { return Err(anyhow!("seed must precede the first step")); }
                player.lock().unwrap().reference_rng_seed(t[1].parse()?).map_err(|e|anyhow!(e))?;
            }
            #[cfg(feature = "reference-state")]
            "state" => {
                let state = player.lock().unwrap().reference_state(32, 20000);
                std::fs::write(t[1], serde_json::to_vec(&state)?)?;
            }
            #[cfg(feature = "reference-fixtures")]
            "fixture" => {
                let command = std::fs::read_to_string(t[1])?;
                let result = player.lock().unwrap().reference_fixture(&command).map_err(|e|anyhow!(e))?;
                let result_path = std::path::Path::new(t[1]).with_file_name(
                    format!("{}-result.json", std::path::Path::new(t[1]).file_stem().unwrap().to_string_lossy()));
                std::fs::write(result_path, serde_json::to_vec(&result)?)?;
            }
            #[cfg(feature = "reference-display")]
            "display" => {
                let list = player.lock().unwrap().reference_display_list();
                std::fs::write(t[1], serde_json::to_vec(&list)?)?;
            }
            #[cfg(feature = "reference-display")]
            "piece" => {
                // One display-list path rendered alone (its masks, filters and blends
                // included) on a transparent stage, cropped to its render bounds.
                let piece = player.lock().unwrap().reference_isolate(t[1]).map_err(|e| anyhow!(e))?;
                let (bounds, px) = (piece.render_bounds, piece.pixel_bounds);
                let rendered = {
                    let mut pl = player.lock().unwrap();
                    pl.render();
                    let r = <dyn Any>::downcast_mut::<WgpuRenderBackend<TextureTarget>>(pl.renderer_mut()).unwrap();
                    r.capture_frame()
                };
                player.lock().unwrap().reference_restore(piece);
                let img = rendered.ok_or(anyhow!("no frame"))?;
                let x0 = (px[0].floor().max(0.0) as u32).min(w);
                let y0 = (px[1].floor().max(0.0) as u32).min(h);
                let x1 = (px[2].ceil().max(0.0) as u32).min(w);
                let y1 = (px[3].ceil().max(0.0) as u32).min(h);
                let crop = image::imageops::crop_imm(&img, x0, y0, (x1 - x0).max(1), (y1 - y0).max(1)).to_image();
                crop.save(t[2])?;
                std::fs::write(format!("{}.json", t[2]), serde_json::to_vec(&serde_json::json!({
                    "path": t[1], "scale": scale, "render_bounds": bounds,
                    "pixel_origin": [x0, y0], "pixel_size": [crop.width(), crop.height()],
                    "pixel_bounds": px,
                    "clipped_by_viewport": px[0] < 0.0 || px[1] < 0.0 || px[2] > w as f64 || px[3] > h as f64,
                }))?)?;
            }
            "shot" => shot(&player, t[1])?,
            "kd" => ev(PlayerEvent::KeyDown { key: key(t[1])? }),
            "ku" => ev(PlayerEvent::KeyUp { key: key(t[1])? }),
            "move" => ev(PlayerEvent::MouseMove { x: t[1].parse::<f64>()? * scale, y: t[2].parse::<f64>()? * scale }),
            "click" => {
                let (x, y): (f64, f64) = (t[1].parse::<f64>()? * scale, t[2].parse::<f64>()? * scale);
                ev(PlayerEvent::MouseMove { x, y });
                ev(PlayerEvent::MouseDown { x, y, button: MouseButton::Left, index: None });
                ev(PlayerEvent::MouseUp { x, y, button: MouseButton::Left });
            }
            "realtime" => realtime = t[1] == "1",
            "quit" => break,
            _ => return Err(anyhow!("unknown command {}", t[0])),
        }
        let fr = player.lock().unwrap().frame_rate();
        writeln!(out, "OK frame={frame} wall_ms={} fps_setting={fr} cmd={line}", t0.elapsed().as_millis())?;
        out.flush()?;
    }
    Ok(())
}
