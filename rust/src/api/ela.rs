use image::codecs::jpeg::JpegEncoder;
use std::io::Cursor;

fn make_ela(orig_pix: &mut [u8], lossy_pix: &[u8], scale: u8) {
    // loop on pixels and mutate them in heap directly
    for (orig, lossy) in orig_pix.iter_mut().zip(lossy_pix.iter()) {
        *orig = orig.abs_diff(*lossy).saturating_mul(scale);
    }
}

// Process ela decoding image from bytes. returns a png rgb pixel array
pub fn process_ela_bytes(raw_bytes: Vec<u8>, scale: u8) -> Result<Vec<u8>, String> {
    let mut jpeg_cursor = Cursor::new(Vec::new()); // cursor to write into mem as stream
    let mut out_cursor = Cursor::new(Vec::new()); // cursor to write encoded output
    let mut encoder = JpegEncoder::new_with_quality(&mut jpeg_cursor, 95); // encoder at 95 quality

    let mut orig_pixels = image::load_from_memory(&raw_bytes)
        .map_err(|e| e.to_string())? // convert ImageError to String and pop
        .to_rgb8();

    let dimensions = orig_pixels.dimensions();

    // encode to Jpeg
    encoder
        .encode(
            &orig_pixels,
            dimensions.0,
            dimensions.1,
            image::ExtendedColorType::Rgb8,
        )
        .map_err(|e| e.to_string())?; // convert to string the error

    let lossy_bytes = jpeg_cursor.into_inner(); // read from stream back to bytes as encoded image
    let lossy_pixels = image::load_from_memory_with_format(&lossy_bytes, image::ImageFormat::Jpeg)
        .map_err(|e| e.to_string())?
        .to_rgb8(); // processed in memory to pixels

    make_ela(&mut orig_pixels, &lossy_pixels, scale); // mutated original pixels in place to ela

    orig_pixels
        .write_to(&mut out_cursor, image::ImageFormat::Png)
        .map_err(|e| e.to_string())?;

    Ok(out_cursor.into_inner())
}
