//! The printable city of SCURK Place & Print: the page grid of the city
//! image, a grayscale copy, and the PDF document of the page images.

pub const PAGE_WIDTH: f64 = 612.0;
pub const PAGE_HEIGHT: f64 = 792.0;
pub const MARGIN: f64 = 36.0;
const LUMINANCE: [f64; 3] = [0.299, 0.587, 0.114];

/// The rectangle of each selected page: x, y, width, and height. Pages count
/// down each column. `None` when a page is outside the grid.
pub fn page_regions(width: i64, height: i64, columns: i64, rows: i64, selected: &[i64]) -> Option<Vec<[i64; 4]>> {
    selected
        .iter()
        .map(|&page| {
            let (column, row) = (page / rows, page % rows);

            if !(0..columns).contains(&column) {
                return None;
            }

            let edge = |size: i64, index: i64, count: i64| (size as f64 * index as f64 / count as f64).floor() as i64;
            let (left, right) = (edge(width, column, columns), edge(width, column + 1, columns));
            let (top, bottom) = (edge(height, row, rows), edge(height, row + 1, rows));

            Some([left, top, (right - left).max(1), (bottom - top).max(1)])
        })
        .collect()
}

/// A grayscale copy of RGBA8 pixels; alpha stays.
pub fn monochrome(rgba: &[u8]) -> Vec<u8> {
    let mut result = rgba.to_vec();

    for pixel in result.chunks_exact_mut(4) {
        let luminance = (f64::from(pixel[0]) * LUMINANCE[0] + f64::from(pixel[1]) * LUMINANCE[1] + f64::from(pixel[2]) * LUMINANCE[2])
            .round()
            .clamp(0.0, 255.0) as u8;
        pixel[..3].fill(luminance);
    }

    result
}

/// One page: a JPEG image and its size in pixels.
pub struct Page<'a> {
    pub jpeg: &'a [u8],
    pub width: i64,
    pub height: i64,
}

/// A PDF 1.4 document with one letter page for each image, centered inside
/// the margins at the largest scale that fits.
pub fn pdf(pages: &[Page]) -> Vec<u8> {
    let object_count = 2 + pages.len() * 3;
    let mut bodies: Vec<Vec<u8>> = vec![Vec::new(); object_count + 1];
    let page_ids: Vec<usize> = (0..pages.len()).map(|index| 3 + index * 3).collect();
    let kids: String = page_ids.iter().map(|id| format!("{id} 0 R ")).collect();
    bodies[1] = b"<< /Type /Catalog /Pages 2 0 R >>\n".to_vec();
    bodies[2] = format!("<< /Type /Pages /Count {} /Kids [{kids}] >>\n", page_ids.len()).into_bytes();

    for (index, (page, &page_id)) in pages.iter().zip(&page_ids).enumerate() {
        let (image_id, content_id) = (page_id + 1, page_id + 2);
        let scale = ((PAGE_WIDTH - MARGIN * 2.0) / page.width as f64).min((PAGE_HEIGHT - MARGIN * 2.0) / page.height as f64);
        let (drawing_width, drawing_height) = (page.width as f64 * scale, page.height as f64 * scale);
        let (x, y) = ((PAGE_WIDTH - drawing_width) * 0.5, (PAGE_HEIGHT - drawing_height) * 0.5);
        let name = format!("Im{index}");
        let content = format!("q\n{drawing_width:.3} 0 0 {drawing_height:.3} {x:.3} {y:.3} cm\n/{name} Do\nQ\n");
        bodies[page_id] = format!(
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /XObject << /{name} {image_id} 0 R >> >> /Contents {content_id} 0 R >>\n"
        )
        .into_bytes();
        let mut image = format!(
            "<< /Type /XObject /Subtype /Image /Width {} /Height {} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode /Length {} >>\nstream\n",
            page.width,
            page.height,
            page.jpeg.len()
        )
        .into_bytes();
        image.extend_from_slice(page.jpeg);
        image.extend_from_slice(b"\nendstream\n");
        bodies[image_id] = image;
        bodies[content_id] = format!("<< /Length {} >>\nstream\n{content}endstream\n", content.len()).into_bytes();
    }

    let mut output = b"%PDF-1.4\n% OpenSC2K printable city\n".to_vec();
    let mut offsets = vec![0; object_count + 1];

    for (id, body) in bodies.iter().enumerate().skip(1) {
        offsets[id] = output.len();
        output.extend(format!("{id} 0 obj\n").into_bytes());
        output.extend_from_slice(body);
        output.extend_from_slice(b"endobj\n");
    }

    let xref = output.len();
    output.extend(format!("xref\n0 {}\n0000000000 65535 f \n", object_count + 1).into_bytes());

    for offset in &offsets[1..] {
        output.extend(format!("{offset:010} 00000 n \n").into_bytes());
    }

    output.extend(format!("trailer\n<< /Size {} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n", object_count + 1).into_bytes());
    output
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pages_count_down_each_column() {
        assert_eq!(page_regions(10, 9, 2, 3, &[0, 4]), Some(vec![[0, 0, 5, 3], [5, 3, 5, 3]]));
        assert_eq!(page_regions(10, 9, 2, 3, &[6]), None);
        assert_eq!(monochrome(&[255, 0, 0, 9]), vec![76, 76, 76, 9]);
    }

    #[test]
    fn the_document_lists_each_object() {
        let document = pdf(&[Page {
            jpeg: b"JPEG",
            width: 270,
            height: 360,
        }]);
        let text = String::from_utf8_lossy(&document);
        assert!(text.starts_with("%PDF-1.4\n"));
        assert!(text.contains("540.000 0 0 720.000 36.000 36.000 cm"));
        assert!(text.ends_with("%%EOF\n"));
        assert!(text.contains("xref\n0 6\n"));
    }
}
