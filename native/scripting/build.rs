//! Compiles the vendored QuickJS-ng C sources and the C helpers of the
//! runtime into one static library. The flags follow the CMake build of
//! QuickJS-ng. The compiler warnings of the unchanged sources are not shown.

const QUICKJS_DIR: &str = "quickjs";
const QUICKJS_SOURCES: [&str; 4] = ["quickjs.c", "libregexp.c", "libunicode.c", "dtoa.c"];
const SHIM_SOURCE: &str = "src/ffi/shim.c";

fn main() {
    let mut build = cc::Build::new();
    build
        .include(QUICKJS_DIR)
        .warnings(false)
        .define("_GNU_SOURCE", None)
        .define("QUICKJS_NG_BUILD", None);

    for source in QUICKJS_SOURCES {
        build.file(format!("{QUICKJS_DIR}/{source}"));
    }

    build.file(SHIM_SOURCE);

    // as the CMake Release build. A debug build keeps the internal asserts,
    // which also find leaked values when a runtime closes
    if std::env::var("PROFILE").as_deref() == Ok("release") {
        build.define("NDEBUG", None);
    }

    let target = std::env::var("TARGET").unwrap_or_default();

    if target.contains("windows") {
        build.define("WIN32_LEAN_AND_MEAN", None).define("_WIN32_WINNT", "0x0601");
    }

    if build.get_compiler().is_like_msvc() {
        build.flag("/std:c11").flag("/experimental:c11atomics");
    } else {
        build.flag("-std=gnu11").flag("-funsigned-char");
    }

    build.compile("quickjs");

    // QuickJS calls the C math library. Rust links it on the other targets
    if target.contains("linux") {
        println!("cargo:rustc-link-lib=m");
    }

    println!("cargo:rerun-if-changed={QUICKJS_DIR}");
    println!("cargo:rerun-if-changed={SHIM_SOURCE}");
}
