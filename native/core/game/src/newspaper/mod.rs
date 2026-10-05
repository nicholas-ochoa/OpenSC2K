//! The newspaper story text: the DATA_USA grammar expands a headline and an
//! article from the story type, its argument, and a seed.

use sc2k_assets::data_usa::DataUsa;
use sc2k_assets::text::johab;
use sc2k_sim::sim::random::SimRandom;

const MAX_OUTPUT_BYTES: usize = 2047;
const MAX_RECURSION_DEPTH: usize = 128;
/// The seed offset of each story slot. -1 marks a slot without a published story.
pub const PUBLISHED_SEED_OFFSETS: [i64; 9] = [28, 49, 56, 63, 70, -1, -1, 42, 35];
/// The papers of a session.
const PAPER_COUNT: i64 = 6;
const PAPER_SEED_STRIDE: i64 = 500;
const DAYS_PER_MONTH: i64 = crate::clock::DAYS_PER_MONTH;
/// The bytes of the grammar tokens from phrase 32. Tokens 1 to 31 name their phrase.
pub const EXTENDED_TOKEN_BYTES: [u8; 60] = [
    0x7f, 0x9e, 0x9f, 0xa9, 0xaa, 0xab, 0xac, 0xae, 0xaf, 0xb0, 0xb1, 0xb2, 0xb3, 0xb4, 0xb8, 0xb9, 0xba, 0xbb, 0xbc, 0xbd, 0xbe, 0xbf,
    0xc0, 0xc1, 0xc2, 0xc3, 0xc4, 0xc5, 0xc8, 0xc9, 0xca, 0xcb, 0xcc, 0xcd, 0xce, 0xcf, 0xd9, 0xda, 0xdb, 0xdc, 0xdd, 0xdf, 0xee, 0xef,
    0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
];
const FIRST_EXTENDED_PHRASE: usize = 32;
/// The code page 437 characters of the grammar. Other high bytes are U+FFFD.
const CP437_LITERALS: [(u8, char); 40] = [
    (0x80, 'Ç'),
    (0x81, 'ü'),
    (0x82, 'é'),
    (0x83, 'â'),
    (0x84, 'ä'),
    (0x85, 'à'),
    (0x86, 'å'),
    (0x87, 'ç'),
    (0x88, 'ê'),
    (0x89, 'ë'),
    (0x8a, 'è'),
    (0x8b, 'ï'),
    (0x8c, 'î'),
    (0x8d, 'ì'),
    (0x8e, 'Ä'),
    (0x8f, 'Å'),
    (0x90, 'É'),
    (0x91, 'æ'),
    (0x92, 'Æ'),
    (0x93, 'ô'),
    (0x94, 'ö'),
    (0x95, 'ò'),
    (0x96, 'û'),
    (0x97, 'ù'),
    (0x98, 'ÿ'),
    (0x99, 'Ö'),
    (0x9a, 'Ü'),
    (0x9b, '¢'),
    (0x9c, '£'),
    (0x9d, '¥'),
    (0xa0, 'á'),
    (0xa1, 'í'),
    (0xa2, 'ó'),
    (0xa3, 'ú'),
    (0xa4, 'ñ'),
    (0xa5, 'Ñ'),
    (0xa6, 'ª'),
    (0xa7, 'º'),
    (0xa8, '¿'),
    (0xad, '¡'),
];

/// Grammar opcodes.
mod token {
    pub const ARGUMENT: u8 = 0x24;
    pub const RANDOM_NUMBER: u8 = 0x25;
    pub const ARGUMENT_TABLE: u8 = 0x26;
    pub const RANDOM_TABLE: u8 = 0x2a;
    /// Ends the headline part of a phrase and starts the article part.
    pub const SECTION: u8 = 0x2b;
    pub const PARAGRAPH: u8 = 0x2d;
    pub const SAVED_NUMBER: u8 = 0x3c;
    pub const CITY_NAME: u8 = 0x3d;
    pub const TEAM_NAME: u8 = 0x3e;
    pub const SAVED_TABLE_SECOND: u8 = 0x40;
    pub const SHARED_TABLE: u8 = 0x5b;
    pub const LITERAL: u8 = 0x5c;
    pub const SAVED_TABLE_FIRST: u8 = 0x5e;
    pub const MAYOR_NAME: u8 = 0x7e;
}

/// The bytes of a new paragraph: a line break and an indent.
const PARAGRAPH_BYTES: [u8; 6] = [0x0a, 0x20, 0x20, 0x20, 0x20, 0x20];
/// The auxiliary byte that a story has not chosen yet.
const UNSET: u8 = 0xff;
const SAVED_NUMBER_SLOT: usize = 2;

/// The parts of a phrase to expand.
#[derive(Clone, Copy, PartialEq, Eq)]
enum Mode {
    /// The headline: the text before the section mark.
    Headline,
    /// The article: the text after the section mark of the selected phrase.
    Article,
    /// The whole text of a nested phrase in an article.
    Whole,
}

/// A saved story record.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Story {
    pub story_type: i64,
    pub argument: i64,
    pub auxiliary: Vec<u8>,
}

/// The names that the grammar inserts.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Names {
    pub city: String,
    pub mayor: String,
    pub teams: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Rendered {
    pub headline: String,
    pub article: String,
    /// The argument after the grammar replaced an argument out of its table.
    pub argument: i64,
    /// The choices that the story saves.
    pub auxiliary: Vec<u8>,
    pub random_state: i64,
}

/// The seed of a published story, or -1 for a paper or slot without one.
pub fn published_seed(session_seed: i64, city_days: i64, paper_index: i64, story_slot: i64) -> i64 {
    if !(0..PAPER_COUNT).contains(&paper_index) {
        return -1;
    }

    match usize::try_from(story_slot).ok().and_then(|slot| PUBLISHED_SEED_OFFSETS.get(slot)) {
        Some(&offset) if offset >= 0 => session_seed + city_days / DAYS_PER_MONTH + paper_index * PAPER_SEED_STRIDE + offset,
        _ => -1,
    }
}

/// The phrase that a grammar token byte expands, or 0 for a literal byte.
pub fn token_phrase_id(value: i64) -> usize {
    let token = (value & 0xff) as u8;

    if (1..=31).contains(&token) {
        return usize::from(token);
    }

    EXTENDED_TOKEN_BYTES
        .iter()
        .position(|&extended| extended == token)
        .map_or(0, |index| index + FIRST_EXTENDED_PHRASE)
}

/// The headline and the article of `story`.
pub fn render_story(data: &DataUsa, story: &Story, seed: i64, names: &Names) -> Result<Rendered, String> {
    let mut renderer = Renderer::new(data, story, names)?;
    renderer.random = SimRandom::new(seed);
    let headline_bytes = renderer.render_selected(Mode::Headline)?;
    let headline = title_case(&renderer.decode(&headline_bytes, true));

    renderer.random = SimRandom::new(seed);
    let mut article_bytes = renderer.render_selected(Mode::Article)?;
    capitalize_article(&mut article_bytes);
    let article = renderer.decode(&article_bytes, false);

    Ok(renderer.finish(headline, article))
}

/// The headline of `story` alone.
pub fn render_headline(data: &DataUsa, story: &Story, seed: i64, names: &Names) -> Result<Rendered, String> {
    let mut renderer = Renderer::new(data, story, names)?;
    renderer.random = SimRandom::new(seed);
    let headline_bytes = renderer.render_selected(Mode::Headline)?;
    let headline = title_case(&renderer.decode(&headline_bytes, true));

    Ok(renderer.finish(headline, String::new()))
}

struct Renderer<'a> {
    source: &'a DataUsa,
    names: &'a Names,
    random: SimRandom,
    story_type: usize,
    argument: i64,
    auxiliary: [u8; 3],
    /// The choice of each table that a story shares between its parts, or -1.
    shared_choices: Vec<i64>,
    output: Vec<u8>,
}

impl<'a> Renderer<'a> {
    fn new(source: &'a DataUsa, story: &Story, names: &'a Names) -> Result<Self, String> {
        let story_type = usize::try_from(story.story_type)
            .ok()
            .filter(|&story_type| story_type < source.bases.len() && source.counts.get(story_type).is_some_and(|&count| count > 0));
        let Some(story_type) = story_type else {
            return Err("newspaper story type is outside the grammar tables".into());
        };
        let Ok(auxiliary) = <[u8; 3]>::try_from(story.auxiliary.as_slice()) else {
            return Err("newspaper story auxiliary data has the wrong size".into());
        };

        Ok(Self {
            source,
            names,
            random: SimRandom::new(0),
            story_type,
            argument: story.argument & 0xff,
            auxiliary,
            shared_choices: vec![-1; sc2k_assets::data_usa::TABLE_ENTRY_COUNT],
            output: Vec::new(),
        })
    }

    fn finish(self, headline: String, article: String) -> Rendered {
        Rendered {
            headline,
            article,
            argument: self.argument,
            auxiliary: self.auxiliary.to_vec(),
            random_state: self.random.state,
        }
    }

    fn render_selected(&mut self, mode: Mode) -> Result<Vec<u8>, String> {
        self.output.clear();
        let count = i64::from(self.source.counts[self.story_type]);
        let phrase_id = i64::from(self.source.bases[self.story_type]) + self.random.next_u15() % count;
        self.expand_phrase(phrase_id, mode, 0)?;

        Ok(std::mem::take(&mut self.output))
    }

    fn expand_phrase(&mut self, phrase_id: i64, mode: Mode, depth: usize) -> Result<(), String> {
        if depth > MAX_RECURSION_DEPTH {
            return Err("newspaper grammar recursion is too deep".into());
        }

        let phrase_id = usize::try_from(phrase_id)
            .ok()
            .filter(|&phrase_id| phrase_id < self.source.offsets.len())
            .ok_or("newspaper grammar phrase is out of range")?;
        let phrase = self.source.phrase_bytes(phrase_id);
        let mut cursor = 0;
        let mut mode = mode;

        if mode == Mode::Article {
            match phrase.iter().position(|&byte| byte == token::SECTION) {
                Some(section) => cursor = section + 1,
                None => return Ok(()),
            }

            mode = Mode::Whole;
        }

        while cursor < phrase.len() {
            let value = phrase[cursor];

            // Korean text: a pair is one character, never a grammar token
            if self.source.is_johab && value >= 0x80 {
                let character = char::from_u32(johab::code_point(phrase, cursor))
                    .filter(|&character| character != '\0')
                    .ok_or("newspaper grammar contains an invalid Johab pair")?;
                self.append_text(&character.to_string())?;
                cursor += 2;
                continue;
            }

            if mode == Mode::Headline && value == token::SECTION {
                return Ok(());
            }

            cursor = self.expand_token(phrase, cursor, mode, depth)? + 1;
        }

        Ok(())
    }

    /// Expand the token at `cursor`. Returns the position of its last byte.
    fn expand_token(&mut self, phrase: &[u8], cursor: usize, mode: Mode, depth: usize) -> Result<usize, String> {
        let value = phrase[cursor];

        match value {
            token::ARGUMENT => self.append_number(self.argument)?,
            token::PARAGRAPH => self.append_bytes(&PARAGRAPH_BYTES)?,
            token::CITY_NAME => self.append_text(&self.names.city.clone())?,
            token::MAYOR_NAME => self.append_text(&self.names.mayor.clone())?,
            token::TEAM_NAME => {
                let team = self.names.teams.get(self.argument as usize).cloned().unwrap_or_default();
                self.append_text(&team)?;
            }
            token::RANDOM_NUMBER
            | token::ARGUMENT_TABLE
            | token::RANDOM_TABLE
            | token::SAVED_NUMBER
            | token::SAVED_TABLE_SECOND
            | token::SHARED_TABLE
            | token::LITERAL
            | token::SAVED_TABLE_FIRST => return self.expand_argument_token(phrase, cursor, mode, depth),
            _ => match token_phrase_id(i64::from(value)) {
                0 => self.append_byte(value)?,
                phrase_id => self.expand_phrase(phrase_id as i64, mode, depth + 1)?,
            },
        }

        Ok(cursor)
    }

    /// Expand a token with one argument byte. Returns the position of its last byte.
    fn expand_argument_token(&mut self, phrase: &[u8], cursor: usize, mode: Mode, depth: usize) -> Result<usize, String> {
        let at = cursor + 1;
        let argument = *phrase.get(at).ok_or("newspaper grammar opcode has no argument")?;
        let table_id = usize::from(argument);

        match phrase[cursor] {
            token::RANDOM_NUMBER => {
                let number = self.random_number(argument);
                self.append_number(number)?;
            }
            token::ARGUMENT_TABLE => {
                let count = self.table_count(table_id)?;

                if self.argument >= count {
                    self.argument = 0;
                }

                self.expand_phrase(self.table_base(table_id) + self.argument, mode, depth + 1)?;
            }
            token::RANDOM_TABLE => {
                let count = self.table_count(table_id)?;
                let choice = self.random.next_u15() % count;
                self.expand_phrase(self.table_base(table_id) + choice, mode, depth + 1)?;
            }
            token::SAVED_NUMBER => {
                let number = self.random_number(argument);

                if self.auxiliary[SAVED_NUMBER_SLOT] == UNSET {
                    self.auxiliary[SAVED_NUMBER_SLOT] = number as u8;
                }

                self.append_number(i64::from(self.auxiliary[SAVED_NUMBER_SLOT]))?;
            }
            token::SAVED_TABLE_FIRST => self.expand_saved_table(table_id, 0, mode, depth)?,
            token::SAVED_TABLE_SECOND => self.expand_saved_table(table_id, 1, mode, depth)?,
            token::SHARED_TABLE => {
                let count = self.table_count(table_id)?;
                let generated = self.random.next_u15() % count;

                if self.shared_choices[table_id] < 0 {
                    self.shared_choices[table_id] = generated;
                }

                self.expand_phrase(self.table_base(table_id) + self.shared_choices[table_id], mode, depth + 1)?;
            }
            _ => {
                let point = if self.source.is_johab { johab::code_point(phrase, at) } else { 0 };

                match char::from_u32(point).filter(|_| point > 0) {
                    Some(character) => {
                        self.append_text(&character.to_string())?;

                        return Ok(at + 1);
                    }
                    None => self.append_byte(argument)?,
                }
            }
        }

        Ok(at)
    }

    /// A number from 2 to `limit`, or 0 for a limit below 2.
    fn random_number(&mut self, limit: u8) -> i64 {
        let limit = i64::from(limit);

        if limit > 1 { self.random.next_u15() % (limit - 1) + 2 } else { 0 }
    }

    fn expand_saved_table(&mut self, table_id: usize, slot: usize, mode: Mode, depth: usize) -> Result<(), String> {
        let count = self.table_count(table_id)?;
        let generated = self.random.next_u15() % count;

        if i64::from(self.auxiliary[slot]) >= count {
            self.auxiliary[slot] = generated as u8;
        }

        self.expand_phrase(self.table_base(table_id) + i64::from(self.auxiliary[slot]), mode, depth + 1)
    }

    fn table_base(&self, table_id: usize) -> i64 {
        i64::from(self.source.bases[table_id])
    }

    fn table_count(&self, table_id: usize) -> Result<i64, String> {
        match self.source.counts.get(table_id) {
            None => Err("newspaper grammar table is out of range".into()),
            Some(&count) if count <= 0 => Err("newspaper grammar table is empty".into()),
            Some(&count) => Ok(i64::from(count)),
        }
    }

    fn append_number(&mut self, value: i64) -> Result<(), String> {
        self.append_text(&(value & 0xff).to_string())
    }

    /// Korean text keeps UTF-8. Other text keeps ASCII; other characters become spaces.
    fn append_text(&mut self, value: &str) -> Result<(), String> {
        if self.source.is_johab {
            return self.append_bytes(value.as_bytes());
        }

        let bytes: Vec<u8> = value
            .chars()
            .map(|character| if character.is_ascii() { character as u8 } else { b' ' })
            .collect();
        self.append_bytes(&bytes)
    }

    fn append_bytes(&mut self, values: &[u8]) -> Result<(), String> {
        values.iter().try_for_each(|&value| self.append_byte(value))
    }

    fn append_byte(&mut self, value: u8) -> Result<(), String> {
        if self.output.len() >= MAX_OUTPUT_BYTES {
            return Err("newspaper grammar output is too long".into());
        }

        self.output.push(value);

        Ok(())
    }

    fn decode(&self, values: &[u8], headline: bool) -> String {
        if self.source.is_johab {
            return String::from_utf8_lossy(values).into_owned();
        }

        values.iter().map(|&value| decode_oem(value, headline)).collect()
    }
}

/// The character of a code page 437 byte. An article also turns the curly
/// quotes into straight quotes.
fn decode_oem(value: u8, headline: bool) -> char {
    match value {
        0xd5 => '\'',
        0xd4 if !headline => '\'',
        0xd2 | 0xd3 if !headline => '"',
        0x00..=0x7f => char::from(value),
        _ => CP437_LITERALS
            .iter()
            .find(|&&(byte, _)| byte == value)
            .map_or('\u{fffd}', |&(_, character)| character),
    }
}

/// The simple case mapping of `character`, as Godot's single-character case tables.
fn upper(character: char) -> char {
    let mut mapped = character.to_uppercase();

    match (mapped.next(), mapped.next()) {
        (Some(single), None) => single,
        _ => character,
    }
}

fn lower(character: char) -> char {
    let mut mapped = character.to_lowercase();

    match (mapped.next(), mapped.next()) {
        (Some(single), None) => single,
        _ => character,
    }
}

fn is_lower(character: char) -> bool {
    lower(character) == character && upper(character) != character
}

fn is_alphanumeric(character: char) -> bool {
    character.is_ascii_alphanumeric() || lower(character) != upper(character)
}

/// Capitalize the first letter of each word. An apostrophe after L, as in
/// L'Enfant, starts a new word.
fn title_case(value: &str) -> String {
    let mut result = String::with_capacity(value.len());
    let mut in_word = false;
    let mut previous = None;

    for character in value.chars() {
        let mut output = character;

        if character == '\'' {
            if previous == Some('L') {
                in_word = false;
            }
        } else if !in_word && is_lower(character) {
            output = upper(character);
            in_word = true;
        } else {
            in_word = is_alphanumeric(character);
        }

        result.push(output);
        previous = Some(character);
    }

    result
}

/// Capitalize the first letter after the end of a sentence and its space.
fn capitalize_article(values: &mut [u8]) {
    const DELIMITERS: [u8; 6] = [0x20, 0x2e, 0x21, 0x3f, 0xd2, 0x22];
    let mut delimiter_count: i64 = 0;

    for value in values.iter_mut() {
        if delimiter_count >= 2 && value.is_ascii_lowercase() {
            *value -= 0x20;
            delimiter_count = 0;
        } else if DELIMITERS.contains(value) {
            delimiter_count += 1;
        } else {
            delimiter_count = if *value == 0x2c { -1 } else { 0 };
        }
    }
}

#[cfg(test)]
mod tests;
