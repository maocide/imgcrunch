use ab_glyph::FontRef;
use image::{ImageBuffer, Rgba};
use std::io::Cursor;

pub fn convert_to_ascii(
    raw_bytes: Vec<u8>,
    target_width: usize,
    char_aspect: f32,
) -> Result<String, String> {
    println!("Hello this is ascii...\n");

    let orig_pixels = image::load_from_memory(&raw_bytes)
        .map_err(|e| e.to_string())? // convert ImageError to String and pop
        .to_rgb8();

    let (orig_width, orig_height) = orig_pixels.dimensions();
    let scale = orig_width as f32 / target_width as f32;

    let width = (orig_width as f32 / scale) as u32;
    let height = ((orig_height as f32 / scale) * char_aspect) as u32;

    let downscaled = image::imageops::resize(
        &orig_pixels,
        width,
        height,
        image::imageops::FilterType::Nearest,
    );

    // preallocate string with width * height + height for \n
    let mut final_ascii = String::with_capacity(((width * height) + height) as usize);
    let mut px_counter = 0;

    for &p in downscaled.pixels() {
        // map RGB to greyscale using standard perceptual weights (0.2126 R + 0.7152 G + 0.0722 B)
        // converted to int with * 256 to avoid float arithmetic
        let grey_u32 = (p[0] as u32 * 77) + (p[1] as u32 * 151) + (p[2] as u32 * 28);
        // divide by 256
        let grey = (grey_u32 / 256) as u8;

        // map grey to ascii (inverted for dark CRT btw)
        let c = match grey {
            0..=31 => ' ',
            32..=63 => '.',
            64..=95 => ':',
            96..=127 => ';',
            128..=159 => '+',
            160..=191 => '*',
            192..=223 => '%',
            224..=255 => '#',
        };

        if px_counter % width == 0 && px_counter != 0 {
            final_ascii.push('\n');
        }

        final_ascii.push(c);
        px_counter += 1;
    }

    Ok(final_ascii)
}

pub fn convert_to_ascii_image(
    raw_bytes: Vec<u8>,
    target_width: usize,
    char_aspect: f32,
) -> Result<(Vec<u8>, String), String> {
    // Drawing color
    let translucent_green = Rgba([0u8, 255u8, 0u8, 127u8]);
    // font scale
    let scale: usize = 10;

    let mut out_cursor = Cursor::new(Vec::new()); // cursor to write encoded output

    let ascii =
        convert_to_ascii(raw_bytes, target_width, char_aspect).map_err(|e| e.to_string())?;

    let ascii_iter = ascii.split('\n');
    let mut max_width = 0;
    let mut lines: Vec<String> = Vec::new();

    // split and get max width
    for line in ascii_iter {
        if line.len() > max_width {
            max_width = line.len();
        }
        lines.push(line.to_string());
    }

    // change scale value defining height to reflect the glyph real width (or guess)
    let char_width = scale as f32 * 0.46;
    let img_width = (max_width as f32 * char_width as f32) as usize;
    let img_height = lines.len() * scale;

    // gen image
    let mut img = ImageBuffer::from_fn(img_width as u32, img_height as u32, |_, _| {
        image::Rgba([0, 0, 0, 255])
    });

    let font = FontRef::try_from_slice(include_bytes!(
        "/usr/share/fonts/TTF/RobotoMono-Regular.ttf"
    ))
    .map_err(|e| e.to_string())?;

    // cook
    for (i, line) in lines.iter().enumerate() {
        let y = scale as usize * i;

        imageproc::drawing::draw_text_mut(
            &mut img,
            translucent_green,
            0,
            y as i32,
            scale as f32,
            &font,
            &line,
        );
    }

    // serve
    img.write_to(&mut out_cursor, image::ImageFormat::Png)
        .map_err(|e| e.to_string())?;

    // deliver
    Ok((out_cursor.into_inner(), ascii))
}
