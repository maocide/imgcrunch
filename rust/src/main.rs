use image_crunch::api::ela::process_ela_bytes;
use image_crunch::api::strings::extract_strings;
use std::error::Error;
use std::fs::read;

/// My own runner to test the api and mess around with eldritch horrors
fn main() -> Result<(), Box<dyn Error>> {
    println!("image_crunch CLI runner");
    if let Ok(file_bytes) = read("zombillie.png") {
        let strings = extract_strings(file_bytes.clone(), 8)?; // deal with cloning here later, we will have paths.
        print!("{strings}");

        let ela = process_ela_bytes(file_bytes, 25).map_err(|e| e)?;
        std::fs::write("zombillie_ela.png", &ela)?;
        println!("Success! Generated zombillie_ela.png via image_crunch::api::ela");
    } else {
        println!(
            "image_crunch CLI compiled and ready! Place a zombillie.png here to run ELA test."
        );
    }
    Ok(())
}
