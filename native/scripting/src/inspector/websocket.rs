//! The parts of HTTP/1.1 and WebSocket (RFC 6455) that the DevTools
//! connection needs: one request head, the upgrade answer, and frames.
//! Clients mask their frames; this server does not mask its own.

use std::io::{self, Read, Write};

use super::{base64, sha1};

// RFC 6455 section 1.3
const ACCEPT_GUID: &str = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
// a request head larger than this is refused
const MAX_HEAD: usize = 16 * 1024;
// a larger message closes the connection
const MAX_MESSAGE: u64 = 64 * 1024 * 1024;

const OPCODE_CONTINUATION: u8 = 0x0;
const OPCODE_TEXT: u8 = 0x1;
const OPCODE_BINARY: u8 = 0x2;
const OPCODE_CLOSE: u8 = 0x8;
const OPCODE_PING: u8 = 0x9;
const OPCODE_PONG: u8 = 0xa;
const FINAL_BIT: u8 = 0x80;
const MASK_BIT: u8 = 0x80;
const LENGTH_16: u8 = 126;
const LENGTH_64: u8 = 127;

/// The request line and the headers of an HTTP request.
pub struct Request {
    pub method: String,
    pub path: String,
    // lower-case names
    pub headers: Vec<(String, String)>,
}

impl Request {
    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers.iter().find(|(key, _)| key == name).map(|(_, value)| value.as_str())
    }

    pub fn is_upgrade(&self) -> bool {
        self.header("upgrade").is_some_and(|value| value.eq_ignore_ascii_case("websocket"))
    }
}

/// Reads one request head. Reads byte by byte, thus no frame bytes after the
/// head are lost.
pub fn read_request(stream: &mut impl Read) -> io::Result<Request> {
    let mut head = Vec::new();
    let mut byte = [0u8; 1];

    while !head.ends_with(b"\r\n\r\n") {
        if head.len() >= MAX_HEAD || stream.read(&mut byte)? == 0 {
            return Err(io::Error::new(io::ErrorKind::InvalidData, "incomplete HTTP request"));
        }

        head.push(byte[0]);
    }

    let text = String::from_utf8_lossy(&head);
    let mut lines = text.split("\r\n");
    let mut request_line = lines.next().unwrap_or_default().split(' ');
    let method = request_line.next().unwrap_or_default().to_string();
    let path = request_line.next().unwrap_or_default().to_string();
    let headers = lines
        .filter_map(|line| line.split_once(':'))
        .map(|(name, value)| (name.trim().to_ascii_lowercase(), value.trim().to_string()))
        .collect();

    Ok(Request { method, path, headers })
}

pub fn accept_key(key: &str) -> String {
    base64::encode(&sha1::digest(format!("{key}{ACCEPT_GUID}").as_bytes()))
}

pub fn write_upgrade(stream: &mut impl Write, key: &str) -> io::Result<()> {
    write!(
        stream,
        "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: {}\r\n\r\n",
        accept_key(key)
    )?;

    stream.flush()
}

pub fn write_response(stream: &mut impl Write, status: &str, content_type: &str, body: &str) -> io::Result<()> {
    write!(
        stream,
        "HTTP/1.1 {status}\r\nContent-Type: {content_type}; charset=UTF-8\r\nContent-Length: {}\r\nCache-Control: no-cache\r\nConnection: close\r\n\r\n{body}",
        body.len()
    )?;

    stream.flush()
}

/// A message or a control frame from the client.
#[derive(Debug, PartialEq)]
pub enum Incoming {
    Text(String),
    Ping(Vec<u8>),
    Close,
}

/// Reads the next message. Fragments join into one message; pongs and binary
/// messages are skipped.
pub fn read_message(stream: &mut impl Read) -> io::Result<Incoming> {
    let mut message = Vec::new();

    loop {
        let (final_frame, opcode, payload) = read_frame(stream)?;

        match opcode {
            OPCODE_PING => return Ok(Incoming::Ping(payload)),
            OPCODE_CLOSE => return Ok(Incoming::Close),
            OPCODE_PONG => continue,
            OPCODE_TEXT | OPCODE_BINARY | OPCODE_CONTINUATION => {
                message.extend_from_slice(&payload);

                if message.len() as u64 > MAX_MESSAGE {
                    return Err(io::Error::new(io::ErrorKind::InvalidData, "message too large"));
                }

                if final_frame {
                    if opcode == OPCODE_BINARY {
                        message.clear();
                        continue;
                    }

                    return Ok(Incoming::Text(String::from_utf8_lossy(&message).into_owned()));
                }
            }
            _ => return Err(io::Error::new(io::ErrorKind::InvalidData, "unknown WebSocket opcode")),
        }
    }
}

fn read_frame(stream: &mut impl Read) -> io::Result<(bool, u8, Vec<u8>)> {
    let mut header = [0u8; 2];
    stream.read_exact(&mut header)?;
    let final_frame = header[0] & FINAL_BIT != 0;
    let opcode = header[0] & 0x0f;
    let masked = header[1] & MASK_BIT != 0;

    let length = match header[1] & 0x7f {
        LENGTH_16 => {
            let mut bytes = [0u8; 2];
            stream.read_exact(&mut bytes)?;
            u16::from_be_bytes(bytes) as u64
        }
        LENGTH_64 => {
            let mut bytes = [0u8; 8];
            stream.read_exact(&mut bytes)?;
            u64::from_be_bytes(bytes)
        }
        short => short as u64,
    };

    if length > MAX_MESSAGE {
        return Err(io::Error::new(io::ErrorKind::InvalidData, "frame too large"));
    }

    let mut mask = [0u8; 4];

    if masked {
        stream.read_exact(&mut mask)?;
    }

    let mut payload = vec![0u8; length as usize];
    stream.read_exact(&mut payload)?;

    if masked {
        for (index, byte) in payload.iter_mut().enumerate() {
            *byte ^= mask[index % 4];
        }
    }

    Ok((final_frame, opcode, payload))
}

pub fn write_text(stream: &mut impl Write, text: &str) -> io::Result<()> {
    write_frame(stream, OPCODE_TEXT, text.as_bytes(), None)
}

pub fn write_pong(stream: &mut impl Write, payload: &[u8]) -> io::Result<()> {
    write_frame(stream, OPCODE_PONG, payload, None)
}

pub fn write_close(stream: &mut impl Write) -> io::Result<()> {
    write_frame(stream, OPCODE_CLOSE, &[], None)
}

/// Writes one final frame. A client masks with `mask`; the server passes None.
pub fn write_frame(stream: &mut impl Write, opcode: u8, payload: &[u8], mask: Option<[u8; 4]>) -> io::Result<()> {
    let mask_bit = if mask.is_some() { MASK_BIT } else { 0 };
    let mut frame = Vec::with_capacity(payload.len() + 14);
    frame.push(FINAL_BIT | opcode);

    match payload.len() {
        length if length < LENGTH_16 as usize => frame.push(mask_bit | length as u8),
        length if length <= u16::MAX as usize => {
            frame.push(mask_bit | LENGTH_16);
            frame.extend_from_slice(&(length as u16).to_be_bytes());
        }
        length => {
            frame.push(mask_bit | LENGTH_64);
            frame.extend_from_slice(&(length as u64).to_be_bytes());
        }
    }

    match mask {
        Some(key) => {
            frame.extend_from_slice(&key);
            frame.extend(payload.iter().enumerate().map(|(index, byte)| byte ^ key[index % 4]));
        }
        None => frame.extend_from_slice(payload),
    }

    stream.write_all(&frame)?;
    stream.flush()
}

#[cfg(test)]
pub const TEXT_OPCODE: u8 = OPCODE_TEXT;

#[cfg(test)]
mod tests {
    use std::io::Cursor;

    use super::*;

    #[test]
    fn the_accept_key_matches_the_rfc_example() {
        assert_eq!(accept_key("dGhlIHNhbXBsZSBub25jZQ=="), "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=");
    }

    #[test]
    fn a_request_head_keeps_its_path_and_headers() {
        let mut input = Cursor::new(b"GET /json/list HTTP/1.1\r\nHost: 127.0.0.1:9229\r\nUpgrade: WebSocket\r\n\r\nrest".to_vec());
        let request = read_request(&mut input).unwrap();

        assert_eq!((request.method.as_str(), request.path.as_str()), ("GET", "/json/list"));
        assert_eq!(request.header("host"), Some("127.0.0.1:9229"));
        assert!(request.is_upgrade());
        assert_eq!(
            input.position(),
            input.get_ref().len() as u64 - 4,
            "the bytes after the head stay unread"
        );
    }

    #[test]
    fn masked_and_fragmented_messages_read_as_one_text() {
        let mut bytes = Vec::new();
        let long = "x".repeat(70_000);
        write_frame(&mut bytes, OPCODE_PING, b"hi", Some([1, 2, 3, 4])).unwrap();
        bytes.extend_from_slice(&[OPCODE_TEXT, MASK_BIT | 3, 9, 9, 9, 9]);
        bytes.extend(b"abc".iter().map(|byte| byte ^ 9));
        write_frame(&mut bytes, OPCODE_CONTINUATION, b"def", Some([5, 6, 7, 8])).unwrap();
        write_frame(&mut bytes, OPCODE_TEXT, long.as_bytes(), Some([7, 7, 7, 7])).unwrap();
        write_close(&mut bytes).unwrap();
        let mut input = Cursor::new(bytes);

        assert_eq!(read_message(&mut input).unwrap(), Incoming::Ping(b"hi".to_vec()));
        assert_eq!(read_message(&mut input).unwrap(), Incoming::Text("abcdef".to_string()));
        assert_eq!(read_message(&mut input).unwrap(), Incoming::Text(long));
        assert_eq!(read_message(&mut input).unwrap(), Incoming::Close);
    }

    #[test]
    fn server_frames_use_each_length_form() {
        for size in [5usize, 300, 70_000] {
            let mut bytes = Vec::new();
            write_text(&mut bytes, &"y".repeat(size)).unwrap();
            let header = match size {
                5 => 2,
                300 => 4,
                _ => 10,
            };

            assert_eq!(bytes.len(), size + header);
            assert_eq!(read_message(&mut Cursor::new(bytes)).unwrap(), Incoming::Text("y".repeat(size)));
        }
    }
}
