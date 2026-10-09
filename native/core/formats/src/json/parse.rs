//! The JSON reader.

use super::{Object, Value};

/// The most nested arrays and objects in one document.
const MAX_DEPTH: usize = 512;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ParseError {
    pub message: String,
    /// The line of the error, from 0, as Godot counts it.
    pub line: usize,
}

/// One JSON value with optional white space around it.
pub fn parse(text: &str) -> Result<Value, ParseError> {
    let mut parser = Parser {
        text: text.as_bytes(),
        position: 0,
        line: 0,
    };

    parser.skip_space();
    let value = parser.value(0)?;
    parser.skip_space();

    if parser.position < parser.text.len() {
        return Err(parser.error("Expected 'EOF'"));
    }

    Ok(value)
}

struct Parser<'a> {
    text: &'a [u8],
    position: usize,
    line: usize,
}

impl Parser<'_> {
    fn error(&self, message: &str) -> ParseError {
        ParseError {
            message: message.to_string(),
            line: self.line,
        }
    }

    fn peek(&self) -> Option<u8> {
        self.text.get(self.position).copied()
    }

    fn skip_space(&mut self) {
        while let Some(byte) = self.peek() {
            match byte {
                b'\n' => self.line += 1,
                b' ' | b'\t' | b'\r' => {}
                _ => return,
            }

            self.position += 1;
        }
    }

    fn expect_word(&mut self, word: &str, value: Value) -> Result<Value, ParseError> {
        if self.text[self.position..].starts_with(word.as_bytes()) {
            self.position += word.len();

            Ok(value)
        } else {
            Err(self.error("Unexpected character"))
        }
    }

    fn value(&mut self, depth: usize) -> Result<Value, ParseError> {
        if depth > MAX_DEPTH {
            return Err(self.error("Too many nested objects and arrays"));
        }

        match self.peek() {
            Some(b'{') => self.object(depth),
            Some(b'[') => self.array(depth),
            Some(b'"') => self.string().map(Value::String),
            Some(b't') => self.expect_word("true", Value::Bool(true)),
            Some(b'f') => self.expect_word("false", Value::Bool(false)),
            Some(b'n') => self.expect_word("null", Value::Null),
            Some(b'-' | b'0'..=b'9') => self.number(),
            Some(_) => Err(self.error("Unexpected character")),
            None => Err(self.error("Unexpected end of file")),
        }
    }

    fn object(&mut self, depth: usize) -> Result<Value, ParseError> {
        self.position += 1;
        let mut object = Object::new();
        self.skip_space();

        if self.peek() == Some(b'}') {
            self.position += 1;

            return Ok(Value::Object(object));
        }

        loop {
            self.skip_space();

            // Godot accepts a comma after the last member
            if self.peek() == Some(b'}') && !object.is_empty() {
                self.position += 1;

                return Ok(Value::Object(object));
            }

            if self.peek() != Some(b'"') {
                return Err(self.error("Expected key"));
            }

            let key = self.string()?;
            self.skip_space();

            if self.peek() != Some(b':') {
                return Err(self.error("Expected ':'"));
            }

            self.position += 1;
            self.skip_space();
            let value = self.value(depth + 1)?;
            object.insert(&key, value);
            self.skip_space();

            match self.peek() {
                Some(b',') => self.position += 1,
                Some(b'}') => {
                    self.position += 1;

                    return Ok(Value::Object(object));
                }
                _ => return Err(self.error("Expected '}' or ','")),
            }
        }
    }

    fn array(&mut self, depth: usize) -> Result<Value, ParseError> {
        self.position += 1;
        let mut items = Vec::new();
        self.skip_space();

        if self.peek() == Some(b']') {
            self.position += 1;

            return Ok(Value::Array(items));
        }

        loop {
            self.skip_space();

            // Godot accepts a comma after the last item
            if self.peek() == Some(b']') && !items.is_empty() {
                self.position += 1;

                return Ok(Value::Array(items));
            }

            items.push(self.value(depth + 1)?);
            self.skip_space();

            match self.peek() {
                Some(b',') => self.position += 1,
                Some(b']') => {
                    self.position += 1;

                    return Ok(Value::Array(items));
                }
                _ => return Err(self.error("Expected ']' or ','")),
            }
        }
    }

    fn number(&mut self) -> Result<Value, ParseError> {
        let start = self.position;

        if self.peek() == Some(b'-') {
            self.position += 1;
        }

        let digits = |parser: &mut Self| {
            let first = parser.position;

            while matches!(parser.peek(), Some(b'0'..=b'9')) {
                parser.position += 1;
            }

            parser.position > first
        };

        if !digits(self) {
            return Err(self.error("Expected number"));
        }

        // Godot accepts a point without digits after it, and leading zeros
        if self.peek() == Some(b'.') {
            self.position += 1;
            digits(self);
        }

        if matches!(self.peek(), Some(b'e' | b'E')) {
            self.position += 1;

            if matches!(self.peek(), Some(b'+' | b'-')) {
                self.position += 1;
            }

            if !digits(self) {
                return Err(self.error("Expected number"));
            }
        }

        let text = std::str::from_utf8(&self.text[start..self.position]).expect("ASCII digits");
        let text = text.strip_suffix('.').unwrap_or(text);

        text.parse::<f64>().map(Value::Float).map_err(|_| self.error("Expected number"))
    }

    fn string(&mut self) -> Result<String, ParseError> {
        self.position += 1;
        let mut bytes: Vec<u8> = Vec::new();

        loop {
            let Some(byte) = self.peek() else {
                return Err(self.error("Unterminated string"));
            };

            self.position += 1;

            match byte {
                b'"' => break,
                b'\\' => {
                    let Some(escape) = self.peek() else {
                        return Err(self.error("Unterminated string"));
                    };

                    self.position += 1;

                    let character = match escape {
                        b'"' => '"',
                        b'\\' => '\\',
                        b'/' => '/',
                        b'b' => '\u{8}',
                        b'f' => '\u{c}',
                        b'n' => '\n',
                        b'r' => '\r',
                        b't' => '\t',
                        b'u' => self.unicode_escape()?,
                        _ => return Err(self.error("Invalid escape sequence")),
                    };

                    let mut buffer = [0_u8; 4];
                    bytes.extend_from_slice(character.encode_utf8(&mut buffer).as_bytes());
                }
                b'\n' => {
                    self.line += 1;
                    bytes.push(byte);
                }
                _ => bytes.push(byte),
            }
        }

        String::from_utf8(bytes).map_err(|_| self.error("Invalid UTF-8"))
    }

    fn hex4(&mut self) -> Result<u32, ParseError> {
        let digits = self
            .text
            .get(self.position..self.position + 4)
            .ok_or_else(|| self.error("Malformed hex constant"))?;
        let text = std::str::from_utf8(digits).map_err(|_| self.error("Malformed hex constant"))?;
        let value = u32::from_str_radix(text, 16).map_err(|_| self.error("Malformed hex constant"))?;
        self.position += 4;

        Ok(value)
    }

    fn unicode_escape(&mut self) -> Result<char, ParseError> {
        let first = self.hex4()?;

        // a surrogate pair holds a character above the basic plane
        let code = if (0xd800..0xdc00).contains(&first) {
            if !self.text[self.position..].starts_with(b"\\u") {
                return Err(self.error("Invalid UTF-16 sequence in string, unpaired lead surrogate"));
            }

            self.position += 2;
            let second = self.hex4()?;

            if !(0xdc00..0xe000).contains(&second) {
                return Err(self.error("Invalid UTF-16 sequence in string, unpaired lead surrogate"));
            }

            0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00)
        } else if (0xdc00..0xe000).contains(&first) {
            return Err(self.error("Invalid UTF-16 sequence in string, unpaired trail surrogate"));
        } else {
            first
        };

        char::from_u32(code).ok_or_else(|| self.error("Invalid unicode codepoint"))
    }
}
