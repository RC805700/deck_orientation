package xrandr
import xlib "vendor:x11/xlib"

// Foreign import for libXrandr (X Resize and Rotate Extension)
foreign import xrandr_lib "system:Xrandr"

XFixed :: i32

XTransform :: struct {
	matrx: [3][3]XFixed,
}

// Foreign procedures
foreign xrandr_lib {

	// Set CRTC config
	XRRSetCrtcConfig :: proc "c" (display: ^xlib.Display, resources: ^xlib.XRRScreenResources, crtc: xlib.RRCrtc, timestamp: xlib.Time, x, y: i32, mode: xlib.RRMode, rotation: xlib.Rotation, outputs: [^]xlib.RROutput, noutputs: i32) -> xlib.Status ---

	//Set Screen Size
	XRRSetScreenSize :: proc "c" (display: ^xlib.Display, window: xlib.Window, width, height: i32, mm_width, mm_height: i32) ---

	// Set CRTC transform
	XRRSetCrtcTransform :: proc "c" (display: ^xlib.Display, crtc: xlib.RRCrtc, transform: ^XTransform, filter_name: cstring, filter_params: ^XFixed, num_filter_params: i32) ---
}
