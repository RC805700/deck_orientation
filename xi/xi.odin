package xi

import xlib "vendor:x11/xlib"

// Foreign import for libXi (X Input Extension)
foreign import xi_lib "system:Xi"

Use :: enum i32 {
	MasterPointer  = 1,
	MasterKeyboard = 2,
	SlavePointer   = 3,
	SlaveKeyboard  = 4,
	FloatingSlave  = 5,
}

XIKeyClass :: 0
XIButtonClass :: 1
XIValuatorClass :: 2
XIScrollClass :: 3
XITouchClass :: 4

XIModeRelative :: 0
XIModeAbsolute :: 1

XIScrollTypeVertical :: 1
XIScrollTypeHorizontal :: 2

XIScrollFlagNoEmulation :: (1 << 0)
XIScrollFlagPreferred :: (1 << 1)

XIDirectTouch :: 1
XIDependentTouch :: 2


XIAnyClassInfo :: struct {
	type:     i32,
	sourceid: i32,
}

XIButtonState :: struct {
	mask_len: i32,
	mask:     [^]u8,
}

XIButtonClassInfo :: struct {
	type:        i32,
	sourceid:    i32,
	num_buttons: i32,
	labels:      [^]xlib.Atom,
	state:       XIButtonState,
}

XIKeyClassInfo :: struct {
	type:         i32,
	sourceid:     i32,
	num_keycodes: i32,
	keycodes:     [^]i32,
}

XIValuatorClassInfo :: struct {
	type:       i32,
	sourceid:   i32,
	number:     i32,
	label:      xlib.Atom,
	min:        f64,
	max:        f64,
	value:      f64,
	resolution: i32,
	mode:       i32,
}

XIScrollClassInfo :: struct {
	type:        i32,
	sourceid:    i32,
	number:      i32,
	scroll_type: i32,
	increment:   f64,
	flags:       i32,
}

XITouchClassInfo :: struct {
	type:        i32,
	sourceid:    i32,
	mode:        i32,
	num_touches: i32,
}

XIDeviceInfo :: struct {
	deviceid:    i32,
	name:        cstring,
	use:         Use,
	attachment:  i32,
	enabled:     b32,
	num_classes: i32,
	classes:     [^]^XIAnyClassInfo,
}

// Foreign procedures
foreign xi_lib {
	XIQueryDevice :: proc "c" (display: ^xlib.Display, deviceid: int, ndevices_return: ^i32) -> ^XIDeviceInfo ---
	XIFreeDeviceInfo :: proc "c" (info: ^XIDeviceInfo) ---
}
