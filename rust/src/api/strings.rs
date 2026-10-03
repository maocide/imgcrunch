use std::str::from_utf8;

pub fn extract_strings(raw_bytes: Vec<u8>, min_len: usize) -> Result<String, String> {
    println!("Hello this is strings...\n");

    let mut results = Vec::<String>::new();
    let mut buf = Vec::<u8>::new();

    for &b in &raw_bytes {
        if b.is_ascii_graphic() || b.is_ascii_whitespace() {
            buf.push(b);
        } else if buf.len() >= min_len {
            if let Ok(s) = from_utf8(&buf) {
                results.push(s.to_string());
            }
            buf.clear();
        } else {
            buf.clear();
        }
    }

    // last flush to catch any string left
    if buf.len() >= min_len {
        if let Ok(s) = from_utf8(&buf) {
            results.push(s.to_string());
        }
    }

    let to_return = results.join("\n");

    Ok(to_return)
}
