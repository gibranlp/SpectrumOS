hl.config({ animations = { enabled = true } })

hl.curve("spectrumEase", { type = "bezier", points = { { 0.22, 1 }, { 0.36, 1 } } })
hl.curve("spectrumExit", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "windows", enabled = true, speed = 2.5, bezier = "spectrumEase" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "spectrumEase", style = "popin 94%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "spectrumExit", style = "popin 94%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "spectrumEase" })
hl.animation({ leaf = "layers", enabled = true, speed = 2, bezier = "spectrumEase" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2, bezier = "spectrumEase", style = "slidefade 20%" })
