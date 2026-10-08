use std::fs::read;
use std::io::Cursor;
use std::time::Instant;

use image::codecs::jpeg::JpegEncoder;
use image_crunch::api::ascii::convert_to_ascii;
use image_crunch::api::ela::process_ela_bytes;
use image_crunch::api::strings::extract_strings;

struct BenchStat {
    name: &'static str,
    min_ms: f64,
    mean_ms: f64,
    max_ms: f64,
    throughput: Option<String>,
}

impl BenchStat {
    fn compute(name: &'static str, mut times: Vec<f64>, throughput: Option<String>) -> Self {
        times.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let count = times.len();
        let min_ms = times[0];
        let max_ms = times[count - 1];
        let sum: f64 = times.iter().sum();
        let mean_ms = sum / count as f64;
        Self {
            name,
            min_ms,
            mean_ms,
            max_ms,
            throughput,
        }
    }
}

fn bench_strings(bytes: &[u8]) -> BenchStat {
    // Warmup
    for _ in 0..5 {
        let _ = extract_strings(bytes.to_vec(), 8);
    }

    let iterations = 30;
    let mut times = Vec::with_capacity(iterations);

    for _ in 0..iterations {
        let start = Instant::now();
        let _ = extract_strings(bytes.to_vec(), 8);
        times.push(start.elapsed().as_secs_f64() * 1000.0);
    }

    let mean = times.iter().sum::<f64>() / iterations as f64;
    let mb_size = bytes.len() as f64 / (1024.0 * 1024.0);
    let throughput_mb_s = mb_size / (mean / 1000.0);

    BenchStat::compute(
        "extract_strings (min_len: 8)",
        times,
        Some(format!("{:.1} MB/s", throughput_mb_s)),
    )
}

fn bench_ascii(bytes: &[u8], target_width: usize) -> BenchStat {
    // Warmup
    for _ in 0..3 {
        let _ = convert_to_ascii(bytes.to_vec(), target_width, 0.4);
    }

    let iterations = 20;
    let mut times = Vec::with_capacity(iterations);

    for _ in 0..iterations {
        let start = Instant::now();
        let _ = convert_to_ascii(bytes.to_vec(), target_width, 0.4);
        times.push(start.elapsed().as_secs_f64() * 1000.0);
    }

    let mean = times.iter().sum::<f64>() / iterations as f64;
    let fps = 1000.0 / mean;

    BenchStat::compute(
        "convert_to_ascii (120 cols)",
        times,
        Some(format!("{:.1} FPS", fps)),
    )
}

fn bench_ela_full(bytes: &[u8]) -> BenchStat {
    // Warmup
    for _ in 0..3 {
        let _ = process_ela_bytes(bytes.to_vec(), 25);
    }

    let iterations = 15;
    let mut times = Vec::with_capacity(iterations);

    for _ in 0..iterations {
        let start = Instant::now();
        let _ = process_ela_bytes(bytes.to_vec(), 25);
        times.push(start.elapsed().as_secs_f64() * 1000.0);
    }

    let mean = times.iter().sum::<f64>() / iterations as f64;
    let fps = 1000.0 / mean;

    BenchStat::compute(
        "process_ela_bytes (full pipeline)",
        times,
        Some(format!("{:.2} FPS", fps)),
    )
}

/// Dissects ELA into its 5 forensic pipeline stages to pinpoint exact bottlenecks.
fn profile_ela_stages(bytes: &[u8]) {
    println!("\n  ==> ELA Pipeline Micro-Profiling (Where is the time going?):");

    let iterations = 10;
    let mut t_png_decode = 0.0;
    let mut t_jpeg_encode = 0.0;
    let mut t_jpeg_decode = 0.0;
    let mut t_pixel_math = 0.0;
    let mut t_png_encode = 0.0;

    for _ in 0..iterations {
        // Stage 1: Decode input PNG
        let s1 = Instant::now();
        let mut orig_pixels = image::load_from_memory(bytes).unwrap().to_rgb8();
        t_png_decode += s1.elapsed().as_secs_f64() * 1000.0;

        let (w, h) = orig_pixels.dimensions();

        // Stage 2: Encode to JPEG Q95
        let s2 = Instant::now();
        let mut jpeg_cursor = Cursor::new(Vec::new());
        let mut encoder = JpegEncoder::new_with_quality(&mut jpeg_cursor, 95);
        encoder
            .encode(&orig_pixels, w, h, image::ExtendedColorType::Rgb8)
            .unwrap();
        let lossy_bytes = jpeg_cursor.into_inner();
        t_jpeg_encode += s2.elapsed().as_secs_f64() * 1000.0;

        // Stage 3: Decode JPEG back to raw RGB
        let s3 = Instant::now();
        let lossy_pixels =
            image::load_from_memory_with_format(&lossy_bytes, image::ImageFormat::Jpeg)
                .unwrap()
                .to_rgb8();
        t_jpeg_decode += s3.elapsed().as_secs_f64() * 1000.0;

        // Stage 4: Pure ELA Pixel Difference Math (make_ela loop)
        let s4 = Instant::now();
        for (orig, lossy) in orig_pixels.iter_mut().zip(lossy_pixels.iter()) {
            *orig = orig.abs_diff(*lossy).saturating_mul(25);
        }
        t_pixel_math += s4.elapsed().as_secs_f64() * 1000.0;

        // Stage 5: Encode output to PNG
        let s5 = Instant::now();
        let mut out_cursor = Cursor::new(Vec::new());
        orig_pixels
            .write_to(&mut out_cursor, image::ImageFormat::Png)
            .unwrap();
        t_png_encode += s5.elapsed().as_secs_f64() * 1000.0;
    }

    let it = iterations as f64;
    let avg_s1 = t_png_decode / it;
    let avg_s2 = t_jpeg_encode / it;
    let avg_s3 = t_jpeg_decode / it;
    let avg_s4 = t_pixel_math / it;
    let avg_s5 = t_png_encode / it;
    let total = avg_s1 + avg_s2 + avg_s3 + avg_s4 + avg_s5;

    println!("      1. Input PNG Decode:       {:>7.2} ms ({:>5.1}%)", avg_s1, (avg_s1 / total) * 100.0);
    println!("      2. JPEG Compress (Q95):    {:>7.2} ms ({:>5.1}%)", avg_s2, (avg_s2 / total) * 100.0);
    println!("      3. JPEG Decompress:        {:>7.2} ms ({:>5.1}%)", avg_s3, (avg_s3 / total) * 100.0);
    println!("      4. ELA Pixel Math (loop):  {:>7.2} ms ({:>5.1}%) <-- Pure Rust compute!", avg_s4, (avg_s4 / total) * 100.0);
    println!("      5. Output PNG Encode:      {:>7.2} ms ({:>5.1}%)", avg_s5, (avg_s5 / total) * 100.0);
    println!("      ------------------------------------------------");
    println!("      TOTAL PER FRAME:           {:>7.2} ms (100.0%)", total);
}

fn main() {
    println!("\n+--------------------------------------------------------------+");
    println!("|          image_crunch FORENSIC BENCHMARK HARNESS             |");
    println!("+--------------------------------------------------------------+");

    let test_file = "zombillie.png";
    let bytes = match read(test_file) {
        Ok(b) => b,
        Err(e) => {
            eprintln!("Error reading {test_file}: {e}");
            return;
        }
    };

    let mb = bytes.len() as f64 / (1024.0 * 1024.0);
    println!("  Target Image:  {} ({:.2} MB, 944x1648 = 1.55 MP)", test_file, mb);

    println!("\n[1/3] Benchmarking String Extractor...");
    let stat_strings = bench_strings(&bytes);

    println!("[2/3] Benchmarking ASCII Converter...");
    let stat_ascii = bench_ascii(&bytes, 120);

    println!("[3/3] Benchmarking ELA Analysis Engine...");
    let stat_ela = bench_ela_full(&bytes);

    println!("\n+-------------------------------------------------------------------------------+");
    println!("| BENCHMARK RESULTS SUMMARY                                                     |");
    println!("+---------------------------------------+-----------+-----------+---------------+");
    println!("| Pipeline Task                         | Mean (ms) | Range (ms)| Throughput    |");
    println!("+---------------------------------------+-----------+-----------+---------------+");

    for stat in [&stat_strings, &stat_ascii, &stat_ela] {
        let tp = stat.throughput.as_deref().unwrap_or("-");
        println!(
            "| {:<37} | {:>7.2}ms | {:>4.1}-{:>4.1}ms | {:<13} |",
            stat.name, stat.mean_ms, stat.min_ms, stat.max_ms, tp
        );
    }
    println!("+---------------------------------------+-----------+-----------+---------------+");

    profile_ela_stages(&bytes);
    println!("\nBenchmark complete.\n");
}
