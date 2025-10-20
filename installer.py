#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import tkinter as tk
from tkinter import ttk, messagebox
import subprocess
import threading
import queue
import os
import sys
import shlex
from pathlib import Path

APP_TITLE = "Arch Linux Installer Wizard"

# ----------------------------- Utils ---------------------------------

def bin_exists(name: str) -> bool:
    return subprocess.call(["/usr/bin/env", "bash", "-lc", f"command -v {shlex.quote(name)} >/dev/null 2>&1"]) == 0

def ensure_root_or_exit():
    if os.geteuid() != 0:
        print("⚠️ Kør programmet som root for at kunne installere Arch.")
        sys.exit(1)

def run_streaming(cmd: str):
    """
    Kør en shell-kommando og stream stdout/stderr linje for linje.
    Returner (exitcode, collected_output).
    """
    # Brug bash -lc for at få PATH osv. som i live-miljøet
    p = subprocess.Popen(
        ["/usr/bin/env", "bash", "-lc", cmd],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
        universal_newlines=True,
    )
    collected = []
    for line in p.stdout:
        collected.append(line)
        yield ("line", line)
    rc = p.wait()
    yield ("returncode", rc, "".join(collected))

# ----------------------------- GUI -----------------------------------

class ArchInstaller(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_TITLE)
        self.geometry("720x520")
        self.resizable(False, False)

        self.data = {}
        self.frames = [WelcomeFrame, DiskFrame, UserFrame, SummaryFrame, InstallFrame]
        self.current = 0

        self.show_frame()

    def show_frame(self):
        for w in self.winfo_children():
            w.destroy()
        frame = self.frames[self.current](self)
        frame.pack(fill="both", expand=True)

    def next(self):
        if self.current < len(self.frames) - 1:
            self.current += 1
            self.show_frame()

    def back(self):
        if self.current > 0:
            self.current -= 1
            self.show_frame()

# ----------------------------- Steps ---------------------------------

class WelcomeFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app)
        ttk.Label(self, text="👋 Velkommen til Arch Linux Installer", font=("Helvetica", 18)).pack(pady=24)
        ttk.Label(
            self,
            text="Denne guide hjælper dig gennem en basal Arch-installation.\n"
                 "Kør i en VM eller på en disk du må slette.",
            justify="center"
        ).pack(pady=8)

        reqs = (
            "- Kræver: parted, mkfs.ext4, pacstrap, genfstab, arch-chroot\n"
            "- Kør som root i Arch ISO/live eller en Arch VM"
        )
        ttk.Label(self, text=reqs, justify="left").pack(pady=8)

        ttk.Button(self, text="Næste ➜", command=app.next).pack(side="bottom", pady=20)


class DiskFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app)
        ttk.Label(self, text="💾 Diskvalg", font=("Helvetica", 16)).pack(pady=10)
        ttk.Label(self, text="Angiv måldisk (⚠️ ALT slettes): fx /dev/sda, /dev/vda, /dev/nvme0n1").pack(pady=5)

        self.disk = ttk.Entry(self, width=40)
        self.disk.insert(0, "/dev/vda")
        self.disk.pack(pady=6)

        self.format_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(self, text="Ja, slet og formater hele disken (GPT + 1 ext4 partition)", variable=self.format_var)\
            .pack(pady=6)

        ttk.Button(self, text="Næste ➜", command=lambda: self.save(app)).pack(side="bottom", pady=20)
        ttk.Button(self, text="⬅ Tilbage", command=app.back).pack(side="bottom")

    def save(self, app):
        disk = self.disk.get().strip()
        if not disk or not disk.startswith("/dev/"):
            messagebox.showerror("Fejl", "Angiv et gyldigt /dev/* diskdevice.")
            return
        app.data["disk"] = disk
        app.data["format"] = bool(self.format_var.get())
        app.next()


class UserFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app)
        ttk.Label(self, text="👤 Bruger & System", font=("Helvetica", 16)).pack(pady=10)

        grid = ttk.Frame(self)
        grid.pack(pady=8)

        ttk.Label(grid, text="Brugernavn:").grid(row=0, column=0, sticky="e", padx=6, pady=4)
        self.user = ttk.Entry(grid, width=28)
        self.user.insert(0, "frank")
        self.user.grid(row=0, column=1, sticky="w", padx=6, pady=4)

        ttk.Label(grid, text="Hostname:").grid(row=1, column=0, sticky="e", padx=6, pady=4)
        self.hostname = ttk.Entry(grid, width=28)
        self.hostname.insert(0, "archlinux")
        self.hostname.grid(row=1, column=1, sticky="w", padx=6, pady=4)

        ttk.Label(grid, text="Timezone:").grid(row=2, column=0, sticky="e", padx=6, pady=4)
        self.tz = ttk.Entry(grid, width=28)
        self.tz.insert(0, "Europe/Copenhagen")
        self.tz.grid(row=2, column=1, sticky="w", padx=6, pady=4)

        # ---- Locale dropdown ----
        ttk.Label(grid, text="Locale:").grid(row=3, column=0, sticky="e", padx=6, pady=4)

        locale_list = [
            "en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8", "da_DK.UTF-8",
            "sv_SE.UTF-8", "no_NO.UTF-8", "fi_FI.UTF-8", "fr_FR.UTF-8",
            "es_ES.UTF-8", "it_IT.UTF-8", "pl_PL.UTF-8"
        ]
        self.locale = ttk.Combobox(grid, values=locale_list, width=25, state="readonly")
        self.locale.set("en_US.UTF-8")
        self.locale.grid(row=3, column=1, sticky="w", padx=6, pady=4)

        ttk.Label(grid, text="Bootloader:").grid(row=4, column=0, sticky="e", padx=6, pady=4)
        self.bootloader = ttk.Combobox(grid, values=["grub-bios", "grub-efi", "none"], width=25, state="readonly")
        self.bootloader.set("grub-efi")
        self.bootloader.grid(row=4, column=1, sticky="w", padx=6, pady=4)

        ttk.Label(self, text="Root/password håndteres som placeholders i denne prototype.").pack(pady=6)

        ttk.Button(self, text="Næste ➜", command=lambda: self.save(app)).pack(side="bottom", pady=20)
        ttk.Button(self, text="⬅ Tilbage", command=app.back).pack(side="bottom")

    def save(self, app):
        app.data["user"] = self.user.get().strip()
        app.data["hostname"] = self.hostname.get().strip()
        app.data["timezone"] = self.tz.get().strip()
        app.data["locale"] = self.locale.get().strip()
        app.data["bootloader"] = self.bootloader.get().strip()
        if not app.data["user"] or not app.data["hostname"]:
            messagebox.showerror("Fejl", "Brugernavn og hostname må ikke være tomme.")
            return
        app.next()


class SummaryFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app)
        ttk.Label(self, text="📋 Opsummering", font=("Helvetica", 16)).pack(pady=10)
        t = tk.Text(self, width=84, height=14)
        t.pack(pady=8)

        d = app.data
        summary = f"""Disk:        {d.get('disk')}
Formater:    {d.get('format')}
Bruger:      {d.get('user')}
Hostname:    {d.get('hostname')}
Timezone:    {d.get('timezone')}
Locale:      {d.get('locale')}
Bootloader:  {d.get('bootloader')}
"""
        t.insert("1.0", summary)
        t.config(state="disabled")

        ttk.Label(self, text="Tryk 'Installer' for at starte. GUI forbliver responsiv.").pack(pady=6)
        ttk.Button(self, text="🚀 Installer", command=app.next).pack(side="bottom", pady=16)
        ttk.Button(self, text="⬅ Tilbage", command=app.back).pack(side="bottom")


class InstallFrame(ttk.Frame):
    def __init__(self, app):
        super().__init__(app)
        self.app = app
        ttk.Label(self, text="⚙️ Installation i gang", font=("Helvetica", 16)).pack(pady=10)

        self.progress = ttk.Progressbar(self, orient="horizontal", length=560, mode="determinate", maximum=100)
        self.progress.pack(pady=8)

        self.output = tk.Text(self, width=96, height=18)
        self.output.pack(pady=6)
        self.output_insert("Starter…\n")

        self.btns = ttk.Frame(self)
        self.btns.pack(fill="x")
        self.close_btn = ttk.Button(self.btns, text="Luk", command=self.master.destroy, state="disabled")
        self.close_btn.pack(side="right", padx=8, pady=8)

        # Queue til tråd-output
        self.q = queue.Queue()
        self.worker_done = False

        # Start baggrundstråd
        self.thread = threading.Thread(target=self.worker, daemon=True)
        self.thread.start()

        # Poll queue for output
        self.after(100, self.drain_queue)

    def output_insert(self, s: str):
        self.output.insert("end", s)
        self.output.see("end")
        self.update_idletasks()

    def drain_queue(self):
        try:
            while True:
                kind, payload = self.q.get_nowait()
                if kind == "log":
                    self.output_insert(payload)
                elif kind == "progress":
                    self.progress["value"] = float(payload)
                elif kind == "done":
                    self.worker_done = True
                    self.output_insert("\n✅ Færdig.\n")
                    self.close_btn.config(state="normal")
        except queue.Empty:
            pass
        if not self.worker_done:
            self.after(100, self.drain_queue)

    def emit(self, kind, payload):
        self.q.put((kind, payload))

    # ---------------- background worker ----------------

    def worker(self):
        d = self.app.data
        disk = d["disk"]
        part1 = f"{disk}1" if not disk.startswith("/dev/nvme") else f"{disk}p1"

        # Preflight checks
        needed_bins = ["parted", "mkfs.ext4", "pacstrap", "genfstab", "arch-chroot"]
        missing = [b for b in needed_bins if not bin_exists(b)]
        if missing:
            self.emit("log", f"❌ Mangler følgende binære: {', '.join(missing)}\n")
            self.emit("done", True)
            return

        steps = []

        if d.get("format", True):
            steps += [
                ("Partitioner GPT", f"parted -s {shlex.quote(disk)} mklabel gpt"),
                ("Lav primary-partition", f"parted -s {shlex.quote(disk)} mkpart primary ext4 1MiB 100%"),
                ("Formater ext4", f"mkfs.ext4 -F {shlex.quote(part1)}"),
            ]
        steps += [
            ("Mount /mnt", f"mount {shlex.quote(part1)} /mnt"),
            ("pacstrap base", "pacstrap /mnt base linux linux-firmware"),
            ("genfstab", "genfstab -U /mnt >> /mnt/etc/fstab"),
            ("timezone", f"arch-chroot /mnt ln -sf /usr/share/zoneinfo/{shlex.quote(d['timezone'])} /etc/localtime"),
            ("hwclock", "arch-chroot /mnt hwclock --systohc"),
            ("locale.gen", f"arch-chroot /mnt bash -lc \"sed -i 's/^#\\s*{shlex.quote(d['locale'])}/{d['locale']}/' /etc/locale.gen && locale-gen\""),
            ("locale.conf", f"bash -lc \"echo 'LANG={shlex.quote(d['locale'])}' > /mnt/etc/locale.conf\""),
            ("hostname", f"bash -lc \"echo {shlex.quote(d['hostname'])} > /mnt/etc/hostname\""),
            ("/etc/hosts", "bash -lc \"cat >> /mnt/etc/hosts <<EOF\n127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\thost.localdomain host\nEOF\"".replace("host", d['hostname'])),
            ("net tools", "arch-chroot /mnt pacman --noconfirm -Syu networkmanager sudo"),
            ("enable NetworkManager", "arch-chroot /mnt systemctl enable NetworkManager"),
            ("useradd", f"arch-chroot /mnt useradd -m -G wheel {shlex.quote(d['user'])}"),
            ("sudoers wheel", "arch-chroot /mnt bash -lc \"sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers\""),
            # NOTE: Passwords: i en rigtig installer vil du spørge bruger og køre 'passwd' interaktivt.
            ("set root password (placeholder)", "arch-chroot /mnt bash -lc \"echo root:arch | chpasswd\""),
            ("set user password (placeholder)", f"arch-chroot /mnt bash -lc \"echo {shlex.quote(d['user'])}:arch | chpasswd\""),
        ]

        # Bootloader hint – implementér selv efter behov
        if d.get("bootloader") == "grub-bios":
            steps += [
                ("install grub (BIOS)", "arch-chroot /mnt pacman --noconfirm -S grub"),
                ("grub-install", f"arch-chroot /mnt grub-install --target=i386-pc {shlex.quote(disk)}"),
                ("grub-mkconfig", "arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg"),
            ]
        elif d.get("bootloader") == "grub-efi":
            steps += [
                ("install grub+efibootmgr", "arch-chroot /mnt pacman --noconfirm -S grub efibootmgr"),
                # For en ren EFI-opsætning skulle vi også have lavet en EFI-partition (FAT32) – denne prototype laver 1 ext4.
                # Tilpas efter dit layout.
            ]

        total = len(steps)
        for i, (desc, cmd) in enumerate(steps, 1):
            self.emit("log", f"[{i}/{total}] {desc}\n$ {cmd}\n")
            for kind, *payload in run_streaming(cmd):
                if kind == "line":
                    self.emit("log", payload[0])
                elif kind == "returncode":
                    rc, collected = payload
                    if rc != 0:
                        self.emit("log", f"\n❌ Fejl ({rc}) i trin: {desc}\n")
                        self.emit("done", True)
                        return
            self.emit("log", "✔️ OK\n\n")
            self.emit("progress", 100.0 * i / total)

        self.emit("log", "🎉 Basisinstallation gennemført. Du kan nu reboot'e til dit nye system.\n")
        self.emit("done", True)

# ----------------------------- main ----------------------------------

if __name__ == "__main__":
    ensure_root_or_exit()
    ArchInstaller().mainloop()
