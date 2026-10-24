use image::codecs::png::CompressionType;
use image::codecs::png::FilterType;
use image::codecs::png::PngEncoder;
use image::ImageEncoder;
use std::io::Cursor;

/// Resize an image
pub fn image_resize(raw_bytes: Vec<u8>, width: u32, height: u32) -> Result<Vec<u8>, String> {
    let mut png_cursor = Cursor::new(Vec::new()); // cursor to write into mem as stream
    let encoder =
        PngEncoder::new_with_quality(&mut png_cursor, CompressionType::Best, FilterType::Adaptive); // encoder for png

    // DynamicImage
    let orig_pixels = image::load_from_memory(&raw_bytes).map_err(|e| e.to_string())?; // convert ImageError to String and pop

    // just resize DynamicImage struct
    let resized = orig_pixels
        .resize_exact(width, height, image::imageops::FilterType::Lanczos3)
        .to_rgba8();

    // encode to Png
    encoder
        .write_image(&resized, width, height, image::ExtendedColorType::Rgba8)
        .map_err(|e| e.to_string())?; // convert to string the error

    let png_bytes = png_cursor.into_inner(); // read from stream back to bytes as encoded image

    Ok(png_bytes)
}

/// Downscales an image preserving ratio in a fast way
pub fn image_thumbnail(raw_bytes: Vec<u8>, width: u32, height: u32) -> Result<Vec<u8>, String> {
    let mut png_cursor = Cursor::new(Vec::new()); // cursor to write into mem as stream
    let encoder =
        PngEncoder::new_with_quality(&mut png_cursor, CompressionType::Best, FilterType::Adaptive); // encoder for png

    // DynamicImage
    let orig_pixels = image::load_from_memory(&raw_bytes).map_err(|e| e.to_string())?; // convert ImageError to String and pop

    // just resize as fast as possible preserving ratio
    let resized = orig_pixels.thumbnail(width, height).to_rgba8();
    let new_dimensions = resized.dimensions();

    // encode to Png
    encoder
        .write_image(
            &resized,
            new_dimensions.0,
            new_dimensions.1,
            image::ExtendedColorType::Rgba8,
        )
        .map_err(|e| e.to_string())?; // convert to string the error

    let png_bytes = png_cursor.into_inner(); // read from stream back to bytes as encoded image

    Ok(png_bytes)
}
