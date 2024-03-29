# make is good，ninja??？
MODE := release
TARGET := riscv64gc-unknown-none-elf
KERNEL_ELF := kernel/target/$(TARGET)/$(MODE)/kernel
KERNEL_BIN := kernel/kernel.bin
KERNEL_ENTRY := 0x80200000
BOOTLOADER = bootloader/fw_payload.bin
FS_IMG = fefs-tool/fs.img
NUM_HART = 8

clean:
	@rm -rf kernel/target
	@rm -rf $(KERNEL_BIN)
	@rm -rf user/target
	@rm -rf fefs-tool/target
	@rm -rf fefs/target
	@rm -rf $(FS_IMG)

build: 
ifeq ($(MODE), debug)
	@cd kernel && cargo build --no-default-features --features $(NUM_HART)t
	@cd user && cargo build
	@cd fefs-tool && cargo run
else
	@cd kernel && cargo build --release --no-default-features --features $(NUM_HART)t
	@cd user && cargo build --release
	@cd fefs-tool && cargo run --release
endif

to_bin: build
	@llvm-objcopy $(KERNEL_ELF) $(KERNEL_BIN)

run: to_bin
	@qemu-system-riscv64 \
		-machine virt \
		-smp $(NUM_HART) \
		-nographic \
		-bios $(BOOTLOADER) \
		-device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY) \
		-drive file=$(FS_IMG),if=none,format=raw,id=x0 \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu_server: to_bin
	@qemu-system-riscv64 \
		-machine virt \
		-smp $(NUM_HART) \
		-nographic \
		-bios $(BOOTLOADER) \
		-device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY) \
		-drive file=$(FS_IMG),if=none,format=raw,id=x0 \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 -s -S

debug: to_bin
	@tmux new-session -d \
		"qemu-system-riscv64 \
		-machine virt \
		-smp $(NUM_HART) \
		-nographic \
		-bios $(BOOTLOADER) \
		-device loader,file=$(KERNEL_BIN),addr=$(KERNEL_ENTRY) \
		-drive file=$(FS_IMG),if=none,format=raw,id=x0 \
        -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0 -s -S"
	@tmux split-window -h "riscv64-unknown-elf-gdb -ex 'file $(KERNEL_ELF)' -ex 'set arch riscv:rv64' -ex 'target remote localhost:1234'" && \
		tmux -2 attach-session -d
