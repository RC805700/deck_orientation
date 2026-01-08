# deck_orientation

An Odin program that provides automatic screen rotation for the Steam Deck based on accelerometer data. It monitors the device's orientation and rotates the display and touch screen accordingly

## Requirements

- Odin compiler
- Steam Deck Lcd
- X11 development libraries
- Xi extension (X Input Extension)
- xrandr
- xinput

## Building

```bash
# Build the executable
odin build . -out:bin/deck_orientation

# Build with debug information
odin build . -debug -out:bin/deck_orientation

# Build optimized for speed
odin build . -o:speed -out:bin/deck_orientation
```

## Running

```bash
# Run directly with Odin
odin run .

# Or run the built executable
./bin/deck_orientation
```
