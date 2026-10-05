/*
 * C helpers for the Rust bindings of QuickJS-ng. The header defines these
 * functions as static inline functions or macros, thus Rust cannot call
 * them directly.
 */
#include <stdint.h>

#include "quickjs.h"

/* the Rust JSValue mirrors the struct of the 64-bit build without NaN boxing */
_Static_assert(sizeof(JSValue) == 16, "OpenSC2K needs the 16-byte JSValue of a 64-bit build");

JSValue osc_new_bool(JSContext *ctx, int value)
{
    return JS_NewBool(ctx, value != 0);
}

JSValue osc_new_int64(JSContext *ctx, int64_t value)
{
    return JS_NewInt64(ctx, value);
}

JSValue osc_new_float64(JSContext *ctx, double value)
{
    return JS_NewFloat64(ctx, value);
}

/* the module of a JS_EVAL_TYPE_MODULE | JS_EVAL_FLAG_COMPILE_ONLY result */
JSModuleDef *osc_module_of(JSValueConst value)
{
    return JS_VALUE_GET_TAG(value) == JS_TAG_MODULE ? (JSModuleDef *)JS_VALUE_GET_PTR(value) : NULL;
}
