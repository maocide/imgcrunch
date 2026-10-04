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

        // map grey to ascii
        let c = match grey {
            0..=31 => '#',
            32..=63 => '%',
            64..=95 => '*',
            96..=127 => '=',
            128..=159 => '+',
            160..=191 => ';',
            192..=223 => ':',
            224..=255 => '.',
        };

        if px_counter % width == 0 && px_counter != 0 {
            final_ascii.push('\n');
        }

        final_ascii.push(c);
        px_counter += 1;
    }

    Ok(final_ascii)
}
