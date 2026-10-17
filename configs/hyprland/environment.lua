hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
-- qt6ct's platform-theme plugin also registers as "qt5ct" (confirmed via its embedded Qt
-- plugin metadata), so Qt5 and Qt6 apps alike read their font/palette from qt5ct.conf and
-- qt6ct.conf respectively through this one value; appearance-sync keeps both files' fonts
-- in sync with the global font-size control.
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
