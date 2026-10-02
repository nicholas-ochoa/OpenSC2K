//! Opens a shared library at run time. This is the only platform-specific code of
//! the FluidSynth backend. The standard library already links the system loader:
//! libdl or libc on Linux, libSystem on macOS, and kernel32 on Windows.
use std::ffi::{CString, c_void};
use std::path::{Path, PathBuf};

/// An open shared library. OpenSC2K never closes it: FluidSynth objects and
/// function pointers stay valid until the process exits.
pub struct SharedLibrary {
    handle: *mut c_void,
}

// SAFETY: the handle is an opaque, process-wide loader token. The loaders of
// every supported platform accept it from any thread.
unsafe impl Send for SharedLibrary {}

unsafe impl Sync for SharedLibrary {}

impl SharedLibrary {
    /// Opens `path`. A bare file name uses the search path of the system.
    pub fn open(path: &Path) -> Result<Self, String> {
        let handle = os::open(path)?;

        Ok(Self { handle })
    }

    /// The address of `name`, or an error when the library does not export it.
    pub fn symbol(&self, name: &str) -> Result<*mut c_void, String> {
        let c_name = CString::new(name).map_err(|_| format!("Invalid symbol name {name}"))?;
        let address = os::symbol(self.handle, &c_name);

        if address.is_null() {
            return Err(format!("The FluidSynth library does not export {name}"));
        }

        Ok(address)
    }
}

/// The folder of the shared library that holds this code: the OpenSC2K audio
/// extension. FluidSynth is packaged beside it.
pub fn own_library_folder() -> Option<PathBuf> {
    let path = os::own_library_path()?;

    path.parent().map(Path::to_path_buf)
}

#[cfg(unix)]
mod os {
    use std::ffi::{CStr, CString, c_char, c_int, c_void};
    use std::os::unix::ffi::OsStrExt;
    use std::path::{Path, PathBuf};

    const RTLD_NOW: c_int = 2;

    #[cfg(target_os = "macos")]
    const RTLD_LOCAL: c_int = 4;

    #[cfg(not(target_os = "macos"))]
    const RTLD_LOCAL: c_int = 0;

    #[repr(C)]
    struct DlInfo {
        file_name: *const c_char,
        base: *mut c_void,
        symbol_name: *const c_char,
        symbol: *mut c_void,
    }

    #[cfg_attr(target_os = "linux", link(name = "dl"))]
    unsafe extern "C" {
        fn dlopen(file_name: *const c_char, flags: c_int) -> *mut c_void;

        fn dlsym(handle: *mut c_void, symbol: *const c_char) -> *mut c_void;

        fn dlerror() -> *const c_char;

        fn dladdr(address: *const c_void, info: *mut DlInfo) -> c_int;
    }

    pub fn open(path: &Path) -> Result<*mut c_void, String> {
        let c_path = CString::new(path.as_os_str().as_bytes()).map_err(|_| format!("Invalid library path {}", path.display()))?;

        // SAFETY: c_path is NUL-terminated. A null result reports the error through dlerror.
        let handle = unsafe { dlopen(c_path.as_ptr(), RTLD_NOW | RTLD_LOCAL) };

        if handle.is_null() {
            // SAFETY: dlerror describes the failed dlopen of this thread.
            return Err(c_message(unsafe { dlerror() }));
        }

        Ok(handle)
    }

    pub fn symbol(handle: *mut c_void, name: &CStr) -> *mut c_void {
        // SAFETY: handle came from dlopen and stays open; name is NUL-terminated.
        unsafe { dlsym(handle, name.as_ptr()) }
    }

    pub fn own_library_path() -> Option<PathBuf> {
        let mut info = DlInfo {
            file_name: std::ptr::null(),
            base: std::ptr::null_mut(),
            symbol_name: std::ptr::null(),
            symbol: std::ptr::null_mut(),
        };
        let address = own_library_path as *const c_void;

        // SAFETY: address is a function of this library; info is a valid out parameter.
        if unsafe { dladdr(address, &mut info) } == 0 || info.file_name.is_null() {
            return None;
        }

        // SAFETY: dladdr returned a NUL-terminated path that the loader owns.
        let bytes = unsafe { CStr::from_ptr(info.file_name) }.to_bytes();

        Some(PathBuf::from(std::ffi::OsStr::from_bytes(bytes)))
    }

    fn c_message(message: *const c_char) -> String {
        if message.is_null() {
            return String::from("unknown error");
        }

        // SAFETY: the loader returns a NUL-terminated message that stays valid until
        // the next loader call on this thread.
        unsafe { CStr::from_ptr(message) }.to_string_lossy().into_owned()
    }
}

#[cfg(windows)]
mod os {
    use std::ffi::{CStr, OsString, c_char, c_void};
    use std::os::windows::ffi::{OsStrExt, OsStringExt};
    use std::path::{Path, PathBuf};

    /// Resolve the dependencies of a DLL in its own folder, then in the safe default folders.
    const LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR: u32 = 0x0000_0100;
    const LOAD_LIBRARY_SEARCH_DEFAULT_DIRS: u32 = 0x0000_1000;
    const GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT: u32 = 0x0000_0002;
    const GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS: u32 = 0x0000_0004;
    const MAX_PATH_UNITS: usize = 32_768;

    unsafe extern "system" {
        fn LoadLibraryExW(file_name: *const u16, file: *mut c_void, flags: u32) -> *mut c_void;

        fn GetProcAddress(module: *mut c_void, name: *const c_char) -> *mut c_void;

        fn GetModuleHandleExW(flags: u32, name: *const u16, module: *mut *mut c_void) -> i32;

        fn GetModuleFileNameW(module: *mut c_void, file_name: *mut u16, size: u32) -> u32;

        fn GetLastError() -> u32;
    }

    pub fn open(path: &Path) -> Result<*mut c_void, String> {
        let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
        // a bare name never searches the current folder
        let flags = if path.is_absolute() {
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
        } else {
            LOAD_LIBRARY_SEARCH_DEFAULT_DIRS
        };

        // SAFETY: wide is NUL-terminated; a null result reports the error through GetLastError.
        let handle = unsafe { LoadLibraryExW(wide.as_ptr(), std::ptr::null_mut(), flags) };

        if handle.is_null() {
            // SAFETY: GetLastError has no preconditions.
            let code = unsafe { GetLastError() };

            return Err(format!("Windows error {code}"));
        }

        Ok(handle)
    }

    pub fn symbol(handle: *mut c_void, name: &CStr) -> *mut c_void {
        // SAFETY: handle came from LoadLibraryExW and stays loaded; name is NUL-terminated.
        unsafe { GetProcAddress(handle, name.as_ptr()) }
    }

    pub fn own_library_path() -> Option<PathBuf> {
        let mut module = std::ptr::null_mut();
        let address = own_library_path as *const u16;
        let flags = GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT;

        // SAFETY: address is a function of this module; module is a valid out parameter.
        if unsafe { GetModuleHandleExW(flags, address, &mut module) } == 0 {
            return None;
        }

        let mut buffer = vec![0u16; MAX_PATH_UNITS];

        // SAFETY: buffer holds MAX_PATH_UNITS units.
        let length = unsafe { GetModuleFileNameW(module, buffer.as_mut_ptr(), MAX_PATH_UNITS as u32) } as usize;

        if length == 0 || length >= MAX_PATH_UNITS {
            return None;
        }

        Some(PathBuf::from(OsString::from_wide(&buffer[..length])))
    }
}
