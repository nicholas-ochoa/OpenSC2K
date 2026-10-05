use super::*;
use sc2k_assets::data_usa::{PHRASE_COUNT, TABLE_ENTRY_COUNT};

const KOREAN: [u8; 36] = [
    0x88, 0x61, 0x90, 0x61, 0x94, 0x61, 0x9c, 0x61, 0xa0, 0x61, 0xa4, 0x61, 0xac, 0x61, 0xb4, 0x61, 0xb8, 0x61, 0xc0, 0x61, 0xc4, 0x61,
    0xc8, 0x61, 0xcc, 0x61, 0xd0, 0x61, 0xd0, 0x65, 0x8a, 0x82, 0xaf, 0xa5, 0xa2, 0x85,
];
const KOREAN_TEXT: &str = "가나다라마바사아자차카타파하한국신문";
const STORY_TYPE: i64 = 2;

/// A grammar with story table 2 at phrase 100 and table 200 at phrase 101.
fn grammar(story: &[u8], subphrase: &[u8], johab: bool) -> DataUsa {
    let mut grammar = vec![0];
    grammar.extend_from_slice(story);
    grammar.push(0);
    let subphrase_offset = grammar.len() as i64;
    grammar.extend_from_slice(subphrase);
    grammar.push(0);

    let mut data = DataUsa {
        bases: vec![0; TABLE_ENTRY_COUNT],
        counts: vec![0; TABLE_ENTRY_COUNT],
        offsets: vec![0; PHRASE_COUNT],
        grammar,
        is_johab: johab,
    };
    data.bases[STORY_TYPE as usize] = 100;
    data.counts[STORY_TYPE as usize] = 1;
    data.bases[200] = 101;
    data.counts[200] = 1;
    data.offsets[100] = 1;
    data.offsets[101] = subphrase_offset;
    data
}

fn story(argument: i64) -> Story {
    Story {
        story_type: STORY_TYPE,
        argument,
        auxiliary: vec![UNSET; 3],
    }
}

fn names() -> Names {
    Names {
        city: "서울".into(),
        mayor: "김시장".into(),
        teams: Vec::new(),
    }
}

#[test]
fn korean_pairs_are_never_tokens() {
    let mut phrase = KOREAN.to_vec();
    // pair trails coincide with the @, backslash and ^ opcodes
    phrase.extend_from_slice(&[0xd9, 0x40, 0x84, 0x5c, 0xd9, 0x5e, 0x2b, 0x2d]);
    phrase.extend_from_slice(&KOREAN);
    phrase.extend_from_slice(&[
        0x20, 0x3d, 0x20, 0x7e, 0x20, 0x24, 0x20, 0x2a, 200, 0x20, 0x5c, 0x88, 0x61, 0x20, 0x5c, 0x2b,
    ]);
    let data = grammar(&phrase, &[0x8b, 0xa1, 0xac, 0x61], true);

    let rendered = render_story(&data, &story(27), 471, &names()).expect("a valid story");
    assert_eq!(rendered.headline, format!("{KOREAN_TEXT}“ㅍ♂"));
    assert_eq!(rendered.article.trim(), format!("{KOREAN_TEXT} 서울 김시장 27 기사 가 +"));
    assert_eq!(
        render_story(&data, &story(27), 471, &names()),
        Ok(rendered.clone()),
        "a seed gives one story"
    );

    let headline = render_headline(&data, &story(27), 471, &names()).unwrap();
    assert_eq!(headline.headline, rendered.headline);

    let mut malformed = data.clone();
    malformed.grammar[1] = 0xff;
    assert!(render_story(&malformed, &story(27), 471, &names()).is_err());
}

#[test]
fn english_text_follows_the_case_rules() {
    // an apostrophe after a capital L starts a word, with a saved table and number
    let phrase = b"the L'enfant plaza of =+the town of =.  its mayor ~, said $.  it is \x5e\xc8 and \x3c\x05.  \xd2yes\xd3, he said.";
    let data = grammar(phrase, b"good", false);
    let names = Names {
        city: "Townè".into(),
        mayor: "pat".into(),
        teams: Vec::new(),
    };

    let rendered = render_story(&data, &story(9), 3, &names).unwrap();
    assert_eq!(rendered.headline, "The L'Enfant Plaza Of Town ");
    assert!(
        rendered
            .article
            .starts_with("the town of Town .  Its mayor pat, said 9.  It is good and "),
        "{}",
        rendered.article
    );
    assert!(rendered.article.ends_with(".  \"Yes\", he said."), "{}", rendered.article);
    assert_eq!(rendered.auxiliary[0], 0, "the saved table keeps its choice");
    assert!((2..=5).contains(&rendered.auxiliary[2]), "the saved number is from 2 to its limit");
}

#[test]
fn malformed_stories_fail() {
    let data = grammar(b"a", b"b", false);
    let mut wrong_type = story(0);
    wrong_type.story_type = 3;
    assert!(
        render_story(&data, &wrong_type, 1, &Names::default())
            .unwrap_err()
            .contains("outside the grammar tables")
    );

    let mut short = story(0);
    short.auxiliary.pop();
    assert!(
        render_story(&data, &short, 1, &Names::default())
            .unwrap_err()
            .contains("wrong size")
    );

    let recursive = grammar(b"\x01", b"", false);
    let mut looping = recursive.clone();
    looping.offsets[1] = 1;
    assert!(
        render_story(&looping, &story(0), 1, &Names::default())
            .unwrap_err()
            .contains("too deep")
    );

    let open = grammar(b"\x2a", b"", false);
    assert!(
        render_story(&open, &story(0), 1, &Names::default())
            .unwrap_err()
            .contains("no argument")
    );
}

#[test]
fn seeds_and_tokens_follow_the_executable_tables() {
    assert_eq!(published_seed(0x1234, 250, 2, 0), 0x1234 + 10 + 1000 + 28);
    assert_eq!([1, 4, 5, 9].map(|slot| published_seed(0, 0, 0, slot)), [49, 70, -1, -1]);
    assert_eq!(published_seed(0, 0, 6, 0), -1);
    assert_eq!([0, 1, 31, 0x20, 0x7f, 0xff, 0x17f].map(token_phrase_id), [0, 1, 31, 0, 32, 91, 32]);
}
