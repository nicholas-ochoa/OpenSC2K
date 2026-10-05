use super::*;

fn object(entries: &[(&str, Value)]) -> Value {
    Value::Object(Object {
        entries: entries.iter().map(|(key, value)| (key.to_string(), value.clone())).collect(),
    })
}

#[test]
fn numbers_parse_as_floats_and_integral_restores_integers() {
    let value = parse("[1, 1.0, -0, 1e3, 2.5]").unwrap();
    assert_eq!(
        value,
        Value::Array(vec![
            Value::Float(1.0),
            Value::Float(1.0),
            Value::Float(-0.0),
            Value::Float(1000.0),
            Value::Float(2.5)
        ])
    );
    assert_eq!(
        value.integral(),
        Value::Array(vec![
            Value::Int(1),
            Value::Int(1),
            Value::Int(0),
            Value::Int(1000),
            Value::Float(2.5)
        ])
    );
    assert_eq!(Value::Float(1e17).integral(), Value::Float(1e17));
}

#[test]
fn repeated_keys_keep_the_first_position_and_the_last_value() {
    let value = parse(r#"{"a": 1, "b": 3, "a": 2}"#).unwrap();
    assert_eq!(value, object(&[("a", Value::Float(2.0)), ("b", Value::Float(3.0))]));
}

#[test]
fn strings_decode_escapes_and_surrogate_pairs() {
    let value = parse(r#""x\"\\\/\b\f\n\r\té😀""#).unwrap();
    assert_eq!(value, Value::String("x\"\\/\u{8}\u{c}\n\r\té😀".into()));
    assert!(parse(r#""\ud83d""#).is_err());
    assert!(parse(r#""\x""#).is_err());
}

#[test]
fn errors_report_the_line_from_zero() {
    assert_eq!(parse("{\"a\": }").unwrap_err().line, 0);
    assert_eq!(parse("{\n\n\"a\" 1}").unwrap_err().line, 2);
    assert!(parse("1 2").is_err());
    assert!(parse("").is_err());
    assert!(parse("tru").is_err());
    assert!(parse("-").is_err());
    assert!(parse(".5").is_err());
    assert!(parse("1e").is_err());
    assert!(parse("[,]").is_err());
}

#[test]
fn the_reader_is_as_lenient_as_godot() {
    assert_eq!(parse("01").unwrap(), Value::Float(1.0));
    assert_eq!(parse("1.").unwrap(), Value::Float(1.0));
    assert_eq!(parse("1E+2").unwrap(), Value::Float(100.0));
    assert_eq!(parse("[1,]").unwrap(), Value::Array(vec![Value::Float(1.0)]));
    assert_eq!(parse(r#"{"a":1,}"#).unwrap(), object(&[("a", Value::Float(1.0))]));
}

#[test]
fn the_writer_matches_godot() {
    // the text that Godot 4.7 writes for the same value
    let value = object(&[
        (
            "a",
            Value::Array(vec![
                Value::Int(1),
                Value::Float(2.5),
                Value::String("x\"\\\n\t\u{8}\u{c}\r\u{b}/é".into()),
            ]),
        ),
        ("b", Value::Object(Object::new())),
        ("c", Value::Array(vec![])),
        ("d", object(&[("e", Value::Null), ("f", Value::Bool(true))])),
    ]);
    let expected = "{\n\t\"a\": [\n\t\t1,\n\t\t2.5,\n\t\t\"x\\\"\\\\\\n\\t\\b\\f\\r\\v/é\"\n\t],\n\t\"b\": {},\n\t\"c\": [],\n\t\"d\": {\n\t\t\"e\": null,\n\t\t\"f\": true\n\t}\n}";
    assert_eq!(stringify(&value, "\t", false), expected);

    let compact = object(&[("a", Value::Array(vec![Value::Int(1), object(&[("z", Value::Int(2))])]))]);
    assert_eq!(stringify(&compact, "", false), r#"{"a":[1,{"z":2}]}"#);
}

#[test]
fn floats_use_fourteen_significant_digits() {
    let cases = [
        (3.0, "3.0"),
        (1.5, "1.5"),
        (0.1, "0.1"),
        (-2.25, "-2.25"),
        (123456789.125, "123456789.125"),
        (1e20, "100000000000000000000.0"),
        (1e-7, "0.0000001"),
        (0.0, "0.0"),
        (100.0, "100.0"),
        (2.0 / 3.0, "0.666666666666667"),
        (1234.5678, "1234.5678"),
    ];

    for (value, text) in cases {
        assert_eq!(stringify(&Value::Float(value), "", false), text, "{value}");
    }
}

#[test]
fn sorted_keys_use_code_point_order() {
    let value = object(&[("b", Value::Int(1)), ("a", object(&[("é", Value::Null), ("z", Value::Null)]))]);
    assert_eq!(stringify(&value, "", true), r#"{"a":{"z":null,"é":null},"b":1}"#);
}
