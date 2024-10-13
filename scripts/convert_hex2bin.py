from intelhex import IntelHex

# Load HEX file
bootloader = IntelHex()
bootloader.fromfile("build/bootloader.hex", format="hex")
bootloader[0] = 0x8a

# Validate start of bootloader != 0x8a
if bootloader[0] == 0x8a:
    print("Error: Bootloader may not start with byte value 0x8a")
    exit(1)

# Create bin file
bootloader.tofile("build/bootloader.bin", format="bin")
