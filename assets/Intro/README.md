# Plymouth intro source

The supplied transparent PNG sequence is `SIntro0001.png` through `SIntro0240.png`, at 445×471 pixels. Originals remain in this folder.

Plymouth uses byte-identical copies named `progress-0.png` through `progress-239.png` under `configs/plymouth/themes/spectrumos/`; the ISO profile contains the same theme. `spectrum-plymouth` packages this canonical configuration, and future ISO builds embed its signed Edge package.

The script advances at 50 frames per second, then holds the final logo until Plymouth exits. The upstream quit path and bounded two-second quit delay remain in use. A fast boot may finish before the complete sequence plays.

After updating the installed theme, rebuild the normal boot images with `mkinitcpio -P`. Updating these sources does not modify an existing ISO image or authorize a new ISO build.
