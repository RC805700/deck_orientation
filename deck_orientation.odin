package deck_orientation

import "core:fmt"
import "core:io"
import "core:log"
import "core:math/linalg"
import "core:mem"
import os "core:os/os2"
import "core:strings"
import "core:sys/linux"
import "core:sys/posix"
import "core:time"
import "vendor:x11/xlib"
import "xi"

HIDIOCGRAWINFO :: 0x80084803
VALVE_VID :: 0x28de
DECK_PID :: 0x1205

Hidraw_Devinfo :: struct {
	bustype: u32,
	vendor:  i16,
	product: i16,
}

Orientation :: enum {
	ORIENT_HORIZONTAL,
	ORIENT_HORIZONTAL_INVERTED,
	ORIENT_VERTICAL,
	ORIENT_VERTICAL_INVERTED,
}

InputReportHeader :: struct {
	version: u16,
	type:    u8,
	length:  u8,
}
SteamDeckState :: struct {
	// If packet num matches that on your prior call, then the controller
	// state hasn't been changed since your last call and there is no need to
	// process it
	packet_num:         u32,
	// Button bitmask and trigger data.
	buttons_l:          u32,
	buttons_h:          u32,
	// Left pad coordinates
	left_pad_x:         i16,
	left_pad_y:         i16,
	// Right pad coordinates
	right_pad_x:        i16,
	right_pad_y:        i16,
	// Accelerometer values
	accel_x:            i16,
	accel_y:            i16,
	accel_z:            i16,
	// Gyroscope values
	gyro_x:             i16,
	gyro_y:             i16,
	gyro_z:             i16,
	// Gyro quaternions
	gyro_quat_w:        i16,
	gyro_quat_x:        i16,
	gyro_quat_y:        i16,
	gyro_quat_z:        i16,
	// Uncalibrated trigger values
	trigger_raw_l:      u16,
	trigger_raw_r:      u16,
	// Left stick values
	left_stick_x:       i16,
	left_stick_y:       i16,
	// Right stick values
	right_stick_x:      i16,
	right_stick_y:      i16,
	// Touchpad pressures
	pressure_pad_left:  u16,
	pressure_pad_right: u16,
	reserved:           [4]u8,
}
InputReport :: struct {
	header:     InputReportHeader,
	deck_state: SteamDeckState,
}

open_sd_hid :: proc() -> (^os.File, os.Error) {
	dir, err := os.open("/dev")

	if err != nil {
		return nil, err
	}
	defer os.close(dir)

	it := os.read_directory_iterator_create(dir)
	defer os.read_directory_iterator_destroy(&it)
	hinfo: Hidraw_Devinfo
	for info in os.read_directory_iterator(&it) {
		if (strings.contains(info.fullpath, "hidraw")) {
			f, err := os.open(info.fullpath, {.Read})
			defer os.close(f)
			if err != nil {
				continue
			}
			if (linux.ioctl(linux.Fd(os.fd(f)), HIDIOCGRAWINFO, uintptr(&hinfo)) == 0) {
				log.infof(
					"Found HIDRAW: %s — VID=%x PID=%x",
					info.fullpath,
					hinfo.vendor,
					hinfo.product,
				)
				if (hinfo.vendor == VALVE_VID && hinfo.product == DECK_PID) {
					log.infof("Steam Deck controller found at %s", info.fullpath)
					return os.open(info.fullpath, {.Read})
				}
			}
		}
	}
	return nil, os.General_Error.Not_Exist
}

is_flat :: proc(ax: f32, ay: f32, az: f32) -> bool {
	g: f32 = linalg.sqrt(ax * ax + ay * ay + az * az)

	// Normalize
	//ax /= g;
	//ay /= g;
	nz := az / g

	// If Z accounts for >0.85g → device is nearly flat
	// (0.85 = about 30° tilt)
	if (linalg.abs(nz) > 0.85) {
		return true
	}

	return false
}

get_orientation_hysteresis :: proc(
	ax: f32,
	ay: f32,
	last_orientation: Orientation,
) -> Orientation {
	absX: f32 = linalg.abs(ax)
	absY: f32 = linalg.abs(ay)

	// Hysteresis margin in m/s²
	deadzone: f32 = 1.5

	switch (last_orientation) {

	case .ORIENT_HORIZONTAL, .ORIENT_HORIZONTAL_INVERTED:
		// Stay horizontal unless vertical is MUCH stronger
		if (absX > absY + deadzone) {
			return (ax > 0) ? .ORIENT_VERTICAL : .ORIENT_VERTICAL_INVERTED
		} else {
			return (ay > 0) ? .ORIENT_HORIZONTAL : .ORIENT_HORIZONTAL_INVERTED
		}

	case .ORIENT_VERTICAL, .ORIENT_VERTICAL_INVERTED:
		// Stay vertical unless horizontal is MUCH stronger
		if (absY > absX + deadzone) {
			return (ay > 0) ? .ORIENT_HORIZONTAL : .ORIENT_HORIZONTAL_INVERTED
		} else {
			return (ax > 0) ? .ORIENT_VERTICAL : .ORIENT_VERTICAL_INVERTED
		}
	}

	return .ORIENT_HORIZONTAL
}

run_cmd :: proc(cmd: []string) {
	ret, _, stderr, _ := os.process_exec({command = cmd}, context.allocator)
	defer {
		delete(stderr)
		//delete(stdout)
	}
	if (!ret.success) {
		log.errorf("stderr: %s", stderr)
	}
}

rotate_x11 :: proc(o: Orientation, output: string) {
	rot := "right"

	switch (o) {
	case .ORIENT_HORIZONTAL:
		rot = "right"
		break
	case .ORIENT_HORIZONTAL_INVERTED:
		rot = "left"
		break
	case .ORIENT_VERTICAL:
		rot = "inverted"
		break
	case .ORIENT_VERTICAL_INVERTED:
		rot = "normal"
		break
	}

	cmd := [5]string{"xrandr", "--output", output, "--rotate", rot}
	run_cmd(cmd[:])
}

main :: proc() {
	context.logger = log.create_console_logger()
	when ODIN_DEBUG {
		track: mem.Tracking_Allocator
		mem.tracking_allocator_init(&track, context.allocator)
		context.allocator = mem.tracking_allocator(&track)

		defer {
			if len(track.allocation_map) > 0 {
				fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
				for _, entry in track.allocation_map {
					fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
				}
			}
			if len(track.bad_free_array) > 0 {
				fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
				for entry in track.bad_free_array {
					fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
				}
			}
			mem.tracking_allocator_destroy(&track)
		}
	}
	display := xlib.OpenDisplay(nil)
	if display == nil {
		log.errorf("X11 not found")
		return
	}
	defer xlib.CloseDisplay(display)
	screen := xlib.DefaultScreen(display)
	root := xlib.RootWindow(display, screen)
	res := xlib.XRRGetScreenResources(display, root)
	on: string
	for routput in res.outputs[:res.noutput] {
		output_info := xlib.XRRGetOutputInfo(display, res, routput)
		if strings.contains(string(output_info.name), "eDP") {
			on = string(output_info.name)
		}
	}
	if len(on) < 3 {
		log.error("Failed to get display name")
		return
	}
	ndevices: i32
	qdev := xi.XIQueryDevice(display, xlib.XIAllDevices, &ndevices)
	if qdev == nil {
		log.error("Failed to get touch device")
		// Handle error (e.g., BadDevice)
		return
	}
	defer xi.XIFreeDeviceInfo(qdev)

	pointer: string
	// Now iterate over the devices
	devs := ([^]xi.XIDeviceInfo)(qdev)[:ndevices]
	for d in devs {
		if (d.use == xi.Use.MasterPointer || d.use == xi.Use.SlavePointer) {
			if strings.contains(string(d.name), "FTS") {
				pointer = fmt.tprintf("pointer:%s", string(d.name))
			}
		}
	}
	f, err := open_sd_hid()
	defer os.close(f)
	if err != nil {
		if err == os.General_Error.Not_Exist {
			log.error("No hidraw device found")
		} else {
			log.errorf("Failed to open hidraw device: %s", err)
		}
		return
	}

	first_sample: bool = true
	pending_active: bool = false
	buf: [64]byte
	last_orientation: Orientation = .ORIENT_HORIZONTAL
	pending_orientation: Orientation = .ORIENT_HORIZONTAL
	pending_since: time.Stopwatch
	touch_cmd := [4]string{"xinput", "--map-to-output", pointer, on}
	looptime: time.Time

	pollfd: posix.pollfd = {
		fd     = posix.FD(os.fd(f)),
		events = {.IN},
	}
	for (posix.poll(&pollfd, 1, 10) >= 0) {
		n, err := os.read_full(f, buf[:])
		if err != io.Error.None {
			log.errorf("Got a error reading hidraw device: %s", err)
			continue
		}

		report := transmute(InputReport)buf

		// convert → m/s²
		ax: f32 = f32(report.deck_state.accel_x) / 4096.0 * 9.80665
		ay: f32 = f32(report.deck_state.accel_y) / 4096.0 * 9.80665
		az: f32 = f32(report.deck_state.accel_z) / 4096.0 * 9.80665

		ax_f: f32
		ay_f: f32
		az_f: f32
		if (first_sample) {
			ax_f = ax
			ay_f = ay
			az_f = az
			first_sample = false
		} else {
			alpha: f32 = 0.15 // smoothing factor (0=slow, 1=fast)
			ax_f = ax_f + alpha * (ax - ax_f)
			ay_f = ay_f + alpha * (ay - ay_f)
			az_f = az_f + alpha * (az - az_f)
		}

		o: Orientation

		// If the deck is flat, do not allow new orientation
		if (is_flat(ax_f, ay_f, az_f)) {
			o = last_orientation // force hold
		} else {
			o = get_orientation_hysteresis(ax_f, ay_f, last_orientation)
		}

		// If this is a new pending orientation, start timer
		if (!pending_active || o != pending_orientation) {
			pending_orientation = o
			time.stopwatch_reset(&pending_since)
			time.stopwatch_start(&pending_since)
			pending_active = true
		}
		pending_ms := time.duration_milliseconds(time.stopwatch_duration(pending_since))

		if (pending_active && pending_ms >= 500) {
			time.stopwatch_stop(&pending_since)
			time.stopwatch_reset(&pending_since)
			// Only apply rotation if this is different from current orientation
			if (pending_orientation != last_orientation) {
				last_orientation = pending_orientation
				rotate_x11(last_orientation, on)
				run_cmd(touch_cmd[:])
			}

			pending_active = false // done
		}

		time.sleep(time.Millisecond * 9)

	}


}
