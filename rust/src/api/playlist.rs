use std::path::Path;
use std::{fs, time::SystemTime};

pub enum SortOrder {
    Name,
    Size,
    Modified,
    Created,
}

pub enum SortDirection {
    Asc,
    Desc,
}

struct FileBySize {
    name: String,
    size: u64,
}
struct FileByDate {
    name: String,
    date: SystemTime,
}

const VALID_EXTENSIONS: &[&str; 6] = &["png", "gif", "bmp", "jpeg", "jpg", "webp"];

pub fn is_valid_ext(ext: &str) -> bool {
    return VALID_EXTENSIONS
        .iter()
        .any(|&valid_ext| ext.eq_ignore_ascii_case(valid_ext));
}

pub fn is_valid_path(entry: &std::fs::DirEntry) -> bool {
    // avoid symlinks/dirs
    if let Ok(f_type) = entry.file_type() {
        if !f_type.is_file() {
            return false;
        }
    } else {
        return false;
    }

    // Path::new borrows directly
    let file_name = entry.file_name();
    match Path::new(&file_name).extension().and_then(|e| e.to_str()) {
        Some(ex) => is_valid_ext(ex),
        None => false,
    }
}

pub fn list_files(path: &str, order: u8, direction: u8) -> Result<Vec<String>, String> {
    let sort_order = match order {
        0 => SortOrder::Name,
        1 => SortOrder::Size,
        2 => SortOrder::Modified,
        3 => SortOrder::Created,
        _ => SortOrder::Name,
    };

    let sort_direction = match direction {
        0 => SortDirection::Asc,
        1 => SortDirection::Desc,
        _ => SortDirection::Asc,
    };

    let list_iter = fs::read_dir(path).map_err(|e| e.to_string())?;

    let result_paths = match sort_order {
        SortOrder::Name => {
            let mut valid_paths: Vec<_> = list_iter
                .filter_map(|entry| {
                    let entry = entry.ok()?;

                    if is_valid_path(&entry) == false {
                        return None;
                    }
                    entry.path().into_os_string().into_string().ok()
                })
                .collect();

            match sort_direction {
                SortDirection::Asc => valid_paths.sort_by(|a, b| a.cmp(b)),
                SortDirection::Desc => valid_paths.sort_by(|a, b| b.cmp(a)),
            };

            valid_paths
        }
        SortOrder::Size => {
            let mut valid_paths: Vec<FileBySize> = list_iter
                .filter_map(|entry| {
                    let entry = entry.ok()?;
                    if is_valid_path(&entry) == false {
                        return None;
                    }

                    let metadata = entry.metadata().ok()?;

                    let name = entry.path().into_os_string().into_string().ok()?;

                    Some(FileBySize {
                        name: name,
                        size: metadata.len(),
                    })
                })
                .collect();

            match sort_direction {
                SortDirection::Asc => valid_paths.sort_by(|a, b| a.size.cmp(&b.size)),
                SortDirection::Desc => valid_paths.sort_by(|a, b| b.size.cmp(&a.size)),
            };
            valid_paths
                .into_iter()
                .map(|file_by_size| file_by_size.name)
                .collect()
        }

        SortOrder::Modified => {
            let mut valid_paths: Vec<FileByDate> = list_iter
                .filter_map(|entry| {
                    let entry = entry.ok()?;
                    if is_valid_path(&entry) == false {
                        return None;
                    }

                    let metadata = entry.metadata().ok()?;

                    let name = entry.path().into_os_string().into_string().ok()?;

                    Some(FileByDate {
                        name: name,
                        date: metadata.created().or_else(|_| metadata.modified()).ok()?,
                        // tries created time. if the fs does not support it, falls back to modified time
                    })
                })
                .collect();

            match sort_direction {
                SortDirection::Asc => valid_paths.sort_by(|a, b| a.date.cmp(&b.date)),
                SortDirection::Desc => valid_paths.sort_by(|a, b| b.date.cmp(&a.date)),
            };
            valid_paths
                .into_iter()
                .map(|file_by_date| file_by_date.name)
                .collect()
        }

        SortOrder::Created => {
            let mut valid_paths: Vec<FileByDate> = list_iter
                .filter_map(|entry| {
                    let entry = entry.ok()?;
                    if is_valid_path(&entry) == false {
                        return None;
                    }

                    let metadata = entry.metadata().ok()?;

                    let name = entry.path().into_os_string().into_string().ok()?;

                    Some(FileByDate {
                        name: name,
                        date: metadata.created().ok()?,
                    })
                })
                .collect();

            match sort_direction {
                SortDirection::Asc => valid_paths.sort_by(|a, b| a.date.cmp(&b.date)),
                SortDirection::Desc => valid_paths.sort_by(|a, b| b.date.cmp(&a.date)),
            }
            valid_paths
                .into_iter()
                .map(|file_by_date| file_by_date.name)
                .collect()
        }
    };

    Ok(result_paths)
}
