use image_crunch::api::ascii::convert_to_ascii;
use image_crunch::api::ascii::convert_to_ascii_image;
use image_crunch::api::ela::process_ela_bytes;
use image_crunch::api::image_resize::image_resize;
use image_crunch::api::image_resize::image_thumbnail;
use image_crunch::api::playlist::list_files;
use image_crunch::api::strings::extract_strings;
use std::error::Error;
use std::fs::read;

/// My own runner to test the api and mess around with eldritch horrors
fn main() -> Result<(), Box<dyn Error>> {
    println!("image_crunch CLI runner");
    if let Ok(file_bytes) = read("zombillie.png") {
        /*
        let strings = extract_strings(file_bytes.clone(), 8)?; // deal with cloning here later, we will have paths.
        print!("{strings}");

        let ascii = convert_to_ascii(file_bytes.clone(), 90, 0.4)?; // deal with cloning here later, we will have paths.
        print!("{ascii}");

        let ascii_res = convert_to_ascii_image(file_bytes.clone(), 90, 0.4)?; // deal with cloning here later, we will have paths.
        std::fs::write("zombillie_ascii.png", &ascii_res.0)?;

        let ela = process_ela_bytes(file_bytes, 25).map_err(|e| e)?;
        std::fs::write("zombillie_ela.png", &ela)?;

        println!("Success! Generated zombillie_ela.png via image_crunch::api::ela");
        */
        let list = list_files(&"./".to_string(), 0, 0).map_err(|e| e.to_string())?;
        for item in list.iter() {
            print!("{item}\n");
        }

        let ela = image_thumbnail(file_bytes, 400, 800).map_err(|e| e)?;
        std::fs::write("zombillie_resize.png", &ela)?;
    } else {
        println!(
            "image_crunch CLI compiled and ready! Place a zombillie.png here to run ELA test."
        );
    }
    Ok(())
}
