#undef GCC
#pragma once

// defines are ignored and used directly, no ffi passthrough
#define uint64_t unsigned long
#define uint32_t unsigned int 
#define uint16_t unsigned short
#define uint8_t unsigned char


#define int64_t signed long
#define int32_t signed int
#define int16_t signed short
#define int8_t signed char


#define uint unsigned int 
#define bool _Bool

// defines for direct, typedefs for ffi

typedef int ffi_t; // fake, just requests the ffi-type (passthrough)

typedef ffi_t pid_t;
typedef ffi_t uid_t;
typedef ffi_t gid_t;
typedef ffi_t off_t;
typedef ffi_t ssize_t;
typedef ffi_t size_t;
typedef ffi_t socklen_t;
typedef ffi_t clockid_t;
typedef ffi_t mode_t;



struct opaque_ptr {
	int opaque;
};

typedef struct va_list {
	int opaque;
} va_list;


#define _SIGSET_NWORDS (1024 / (8 * sizeof (unsigned long int)))
 struct sigset_t
{
// defined because of sizes. Must allocate this directly, macos = 32 bit int, linux = bigger
  unsigned char __val[128];
} ;



#define sigset_t struct sigset_t
#define DIR struct opaque_ptr
#define fd_set struct opaque_ptr

